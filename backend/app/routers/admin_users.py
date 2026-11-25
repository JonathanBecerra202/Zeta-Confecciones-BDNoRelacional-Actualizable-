from datetime import datetime, timezone
import re
from typing import Any
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pymongo.database import Database

from ..database import get_db, write_audit_log
from ..schemas import (
    CreateUserRequest,
    ManagedUserOut,
    ManagedUsersPageOut,
    SetPasswordRequest,
    UpdateUserRequest,
    UserNameOut,
)
from ..security import CurrentUser, get_current_user, hash_password, require_admin

router = APIRouter(tags=["admin-users"])


def _role_map(db: Database) -> tuple[dict[int, str], dict[str, int]]:
    roles = list(db.role.find({}, {"_id": 0, "role_id": 1, "name": 1}))
    id_to_name = {int(r["role_id"]): str(r["name"]) for r in roles}
    name_to_id = {str(r["name"]): int(r["role_id"]) for r in roles}
    return id_to_name, name_to_id


def _to_managed_user(doc: dict[str, Any], id_to_name: dict[int, str]) -> ManagedUserOut:
    role_name = id_to_name.get(int(doc["role_id"]), "Employee")
    avatar_path = doc.get("avatar_path")
    return ManagedUserOut(
        user_id=doc["user_id"],
        email=doc.get("email") or "",
        full_name=doc["full_name"],
        role=role_name,  # type: ignore[arg-type]
        active=doc.get("active", True) is not False,
        must_change_password=bool(doc.get("must_change_password", False)),
        created_at=doc.get("created_at"),
        avatar_path=avatar_path,
        avatar_url=avatar_path,
    )


@router.get("/admin/users", response_model=ManagedUsersPageOut)
def list_users(
    search: str = Query(default=""),
    role: str | None = Query(default=None),
    include_inactive: bool = Query(default=False),
    page: int = Query(default=0, ge=0),
    page_size: int = Query(default=10, ge=1, le=100),
    _: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> ManagedUsersPageOut:
    id_to_name, name_to_id = _role_map(db)

    query: dict[str, Any] = {}
    if not include_inactive:
        query["active"] = {"$ne": False}

    if role:
        role_id = name_to_id.get(role)
        if role_id is None:
            return ManagedUsersPageOut(users=[], total=0)
        query["role_id"] = int(role_id)

    term = search.strip()
    if term:
        escaped = re.escape(term)
        query["$or"] = [
            {"full_name": {"$regex": escaped, "$options": "i"}},
            {"email": {"$regex": escaped, "$options": "i"}},
        ]

    total = db.profile.count_documents(query)
    cursor = (
        db.profile.find(query, {"_id": 0, "password_hash": 0})
        .sort([("created_at", -1), ("full_name", 1)])
        .skip(page * page_size)
        .limit(page_size)
    )
    users = [_to_managed_user(doc, id_to_name) for doc in cursor]
    return ManagedUsersPageOut(users=users, total=total)


@router.post("/admin/users", response_model=ManagedUserOut, status_code=status.HTTP_201_CREATED)
def create_user(
    body: CreateUserRequest,
    admin: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> ManagedUserOut:
    id_to_name, name_to_id = _role_map(db)
    role_id = name_to_id.get(body.role)
    if role_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Rol inválido: {body.role}",
        )

    email_normalized = body.email.strip().lower()
    if db.profile.find_one({"email": email_normalized}, {"_id": 1}):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un usuario registrado con ese correo.",
        )

    new_doc = {
        "user_id": str(uuid.uuid4()),
        "email": email_normalized,
        "password_hash": hash_password(body.password),
        "must_change_password": True,
        "full_name": body.full_name.strip(),
        "active": True,
        "created_at": datetime.now(timezone.utc),
        "role_id": int(role_id),
        "avatar_path": None,
    }
    db.profile.insert_one(new_doc)
    write_audit_log(
        db,
        table_name="profile",
        operation="INSERT",
        record_id=new_doc["user_id"],
        data_before=None,
        data_after=new_doc,
        user_id=admin.user_id,
        db_user=admin.db_user_label,
    )
    return _to_managed_user(new_doc, id_to_name)


@router.patch("/admin/users/{user_id}", response_model=ManagedUserOut)
def update_user(
    user_id: str,
    body: UpdateUserRequest,
    admin: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> ManagedUserOut:
    existing = db.profile.find_one({"user_id": user_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")

    id_to_name, name_to_id = _role_map(db)
    updates: dict[str, Any] = {}

    if body.full_name is not None:
        updates["full_name"] = body.full_name.strip()
    if body.role is not None:
        role_id = name_to_id.get(body.role)
        if role_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Rol inválido: {body.role}",
            )
        updates["role_id"] = int(role_id)
    if body.active is not None:
        if user_id == admin.user_id and body.active is False:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puedes desactivar tu propia cuenta.",
            )
        updates["active"] = body.active

    if updates:
        db.profile.update_one({"user_id": user_id}, {"$set": updates})
        updated = db.profile.find_one({"user_id": user_id}, {"_id": 0})
        write_audit_log(
            db,
            table_name="profile",
            operation="UPDATE",
            record_id=user_id,
            data_before=existing,
            data_after=updated,
            user_id=admin.user_id,
            db_user=admin.db_user_label,
        )
    else:
        updated = existing

    assert updated is not None
    return _to_managed_user(updated, id_to_name)


@router.post("/admin/users/{user_id}/password", status_code=status.HTTP_204_NO_CONTENT)
def set_user_password(
    user_id: str,
    body: SetPasswordRequest,
    admin: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> None:
    existing = db.profile.find_one({"user_id": user_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")

    db.profile.update_one(
        {"user_id": user_id},
        {
            "$set": {
                "password_hash": hash_password(body.password),
                "must_change_password": True,
            }
        },
    )
    updated = db.profile.find_one({"user_id": user_id}, {"_id": 0})
    write_audit_log(
        db,
        table_name="profile",
        operation="UPDATE",
        record_id=user_id,
        data_before=existing,
        data_after=updated,
        user_id=admin.user_id,
        db_user=admin.db_user_label,
    )


@router.get("/users/names", response_model=list[UserNameOut])
def list_user_names(
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[UserNameOut]:
    cursor = db.profile.find({}, {"_id": 0, "user_id": 1, "full_name": 1}).sort("full_name", 1)
    return [UserNameOut(user_id=doc["user_id"], full_name=doc["full_name"]) for doc in cursor]
