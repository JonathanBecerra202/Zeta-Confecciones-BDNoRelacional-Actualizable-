from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pymongo.database import Database

from ..database import get_db, get_next_sequence, write_audit_log
from ..schemas import OrganizationCreate, OrganizationOut, OrganizationUpdate
from ..security import CurrentUser, get_current_user

router = APIRouter(prefix="/organizations", tags=["organizations"])


@router.get("", response_model=list[OrganizationOut])
def list_organizations(
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[OrganizationOut]:
    docs = db.organization.find({}, {"_id": 0}).sort("name", 1)
    return [OrganizationOut(**doc) for doc in docs]


@router.post("", response_model=OrganizationOut, status_code=status.HTTP_201_CREATED)
def create_organization(
    body: OrganizationCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> OrganizationOut:
    org_id = get_next_sequence(db, "organization")
    doc = {
        "organization_id": int(org_id),
        "name": body.name,
        "created_at": datetime.now(timezone.utc),
    }
    db.organization.insert_one(doc)
    write_audit_log(
        db,
        table_name="organization",
        operation="INSERT",
        record_id=org_id,
        data_before=None,
        data_after=doc,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    return OrganizationOut(**doc)


@router.patch("/{organization_id}", response_model=OrganizationOut)
def update_organization(
    organization_id: int,
    body: OrganizationUpdate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> OrganizationOut:
    existing = db.organization.find_one({"organization_id": organization_id}, {"_id": 0})
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Organización no encontrada."
        )

    db.organization.update_one(
        {"organization_id": organization_id},
        {"$set": {"name": body.name}},
    )
    updated = db.organization.find_one({"organization_id": organization_id}, {"_id": 0})
    write_audit_log(
        db,
        table_name="organization",
        operation="UPDATE",
        record_id=organization_id,
        data_before=existing,
        data_after=updated,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    assert updated is not None
    return OrganizationOut(**updated)


@router.delete("/{organization_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_organization(
    organization_id: int,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> None:
    existing = db.organization.find_one({"organization_id": organization_id}, {"_id": 0})
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Organización no encontrada."
        )

    if db.department.find_one({"organization_id": organization_id}, {"_id": 1}):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No se puede eliminar la organización porque tiene dependencias asociadas.",
        )

    db.organization.delete_one({"organization_id": organization_id})
    write_audit_log(
        db,
        table_name="organization",
        operation="DELETE",
        record_id=organization_id,
        data_before=existing,
        data_after=None,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
