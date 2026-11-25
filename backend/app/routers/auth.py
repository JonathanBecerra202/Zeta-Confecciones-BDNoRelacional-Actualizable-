from fastapi import APIRouter, Depends, HTTPException, status
from pymongo.database import Database

from ..database import get_db, write_audit_log
from ..schemas import ChangePasswordRequest, LoginRequest, TokenOut, UserMeOut
from ..security import (
    CurrentUser,
    create_access_token,
    get_current_user,
    hash_password,
    resolve_role_name,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _to_user_me(user: CurrentUser) -> UserMeOut:
    return UserMeOut(
        user_id=user.user_id,
        email=user.email,
        full_name=user.full_name,
        role=user.role,  # type: ignore[arg-type]
        active=user.active,
        must_change_password=user.must_change_password,
        avatar_path=user.avatar_path,
        avatar_url=user.avatar_path,
    )


@router.post("/login", response_model=TokenOut)
def login(body: LoginRequest, db: Database = Depends(get_db)) -> TokenOut:
    email_normalized = body.email.strip().lower()
    profile = db.profile.find_one({"email": email_normalized}, {"_id": 0})
    if not profile or not profile.get("password_hash"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos.",
        )

    if not verify_password(body.password, profile["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos.",
        )

    if profile.get("active") is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta está desactivada. Contacta al administrador.",
        )

    role_name = resolve_role_name(db, int(profile["role_id"]))
    token = create_access_token(
        user_id=profile["user_id"],
        role=role_name,
        email=email_normalized,
    )
    user_out = UserMeOut(
        user_id=profile["user_id"],
        email=email_normalized,
        full_name=profile["full_name"],
        role=role_name,  # type: ignore[arg-type]
        active=profile.get("active", True) is not False,
        must_change_password=bool(profile.get("must_change_password", False)),
        avatar_path=profile.get("avatar_path"),
        avatar_url=profile.get("avatar_path"),
    )
    return TokenOut(access_token=token, user=user_out)


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(
    body: ChangePasswordRequest,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> None:
    profile = db.profile.find_one({"user_id": user.user_id}, {"_id": 0})
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Perfil no encontrado.")

    if not user.must_change_password:
        if not body.current_password or not verify_password(
            body.current_password, profile.get("password_hash") or ""
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La contraseña actual no es correcta.",
            )

    new_hash = hash_password(body.new_password)
    db.profile.update_one(
        {"user_id": user.user_id},
        {"$set": {"password_hash": new_hash, "must_change_password": False}},
    )
    updated = db.profile.find_one({"user_id": user.user_id}, {"_id": 0})
    write_audit_log(
        db,
        table_name="profile",
        operation="UPDATE",
        record_id=user.user_id,
        data_before=profile,
        data_after=updated,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )


@router.get("/me", response_model=UserMeOut)
def get_me(user: CurrentUser = Depends(get_current_user)) -> UserMeOut:
    return _to_user_me(user)
