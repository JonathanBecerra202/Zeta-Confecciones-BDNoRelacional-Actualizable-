from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pymongo.database import Database

from ..database import get_db, get_next_sequence, write_audit_log
from ..schemas import DepartmentCreate, DepartmentOut, DepartmentUpdate
from ..security import CurrentUser, get_current_user

router = APIRouter(prefix="/departments", tags=["departments"])


@router.get("", response_model=list[DepartmentOut])
def list_departments(
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[DepartmentOut]:
    docs = db.department.find({}, {"_id": 0}).sort("name", 1)
    return [DepartmentOut(**doc) for doc in docs]


@router.post("", response_model=DepartmentOut, status_code=status.HTTP_201_CREATED)
def create_department(
    body: DepartmentCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> DepartmentOut:
    if not db.organization.find_one({"organization_id": body.organization_id}, {"_id": 1}):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Organización no encontrada."
        )

    dept_id = get_next_sequence(db, "department")
    doc = {
        "department_id": int(dept_id),
        "name": body.name,
        "organization_id": int(body.organization_id),
        "created_at": datetime.now(timezone.utc),
    }
    db.department.insert_one(doc)
    write_audit_log(
        db,
        table_name="department",
        operation="INSERT",
        record_id=dept_id,
        data_before=None,
        data_after=doc,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    return DepartmentOut(**doc)


@router.patch("/{department_id}", response_model=DepartmentOut)
def update_department(
    department_id: int,
    body: DepartmentUpdate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> DepartmentOut:
    existing = db.department.find_one({"department_id": department_id}, {"_id": 0})
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Dependencia no encontrada."
        )

    db.department.update_one(
        {"department_id": department_id},
        {"$set": {"name": body.name}},
    )
    updated = db.department.find_one({"department_id": department_id}, {"_id": 0})
    write_audit_log(
        db,
        table_name="department",
        operation="UPDATE",
        record_id=department_id,
        data_before=existing,
        data_after=updated,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    assert updated is not None
    return DepartmentOut(**updated)


@router.delete("/{department_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_department(
    department_id: int,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> None:
    existing = db.department.find_one({"department_id": department_id}, {"_id": 0})
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Dependencia no encontrada."
        )

    if db.client.find_one({"department_id": department_id}, {"_id": 1}):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No se puede eliminar la dependencia porque tiene clientes asociados.",
        )

    db.department.delete_one({"department_id": department_id})
    write_audit_log(
        db,
        table_name="department",
        operation="DELETE",
        record_id=department_id,
        data_before=existing,
        data_after=None,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
