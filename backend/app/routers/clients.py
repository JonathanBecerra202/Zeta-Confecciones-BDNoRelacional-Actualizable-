from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pymongo.database import Database

from ..database import get_db, get_next_sequence, write_audit_log
from ..schemas import ClientCreate, ClientOut, ClientUpdate, MeasurementCreate, MeasurementOut
from ..security import CurrentUser, get_current_user

router = APIRouter(prefix="/clients", tags=["clients"])


@router.get("", response_model=list[ClientOut])
def list_clients(
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[ClientOut]:
    docs = db["client"].find({}, {"_id": 0}).sort("first_name", 1)
    return [ClientOut(**doc) for doc in docs]


@router.post("", response_model=ClientOut, status_code=status.HTTP_201_CREATED)
def create_client(
    body: ClientCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> ClientOut:
    if body.department_id is not None:
        if not db.department.find_one({"department_id": body.department_id}, {"_id": 1}):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Dependencia no encontrada."
            )

    now = datetime.now(timezone.utc)
    client_id = get_next_sequence(db, "client")
    doc = {
        "client_id": int(client_id),
        "first_name": body.first_name,
        "middle_name": body.middle_name,
        "last_name": body.last_name,
        "second_last_name": body.second_last_name,
        "phone": body.phone,
        "active": body.active,
        "registered_at": now,
        "updated_at": now,
        "department_id": int(body.department_id) if body.department_id is not None else None,
    }
    db["client"].insert_one(doc)
    write_audit_log(
        db,
        table_name="client",
        operation="INSERT",
        record_id=client_id,
        data_before=None,
        data_after=doc,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    return ClientOut(**doc)


@router.patch("/{client_id}", response_model=ClientOut)
def update_client(
    client_id: int,
    body: ClientUpdate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> ClientOut:
    existing = db["client"].find_one({"client_id": client_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado.")

    updates = body.model_dump(exclude_unset=True)
    if "department_id" in updates and updates["department_id"] is not None:
        if not db.department.find_one({"department_id": updates["department_id"]}, {"_id": 1}):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Dependencia no encontrada."
            )
        updates["department_id"] = int(updates["department_id"])

    if updates:
        updates["updated_at"] = datetime.now(timezone.utc)
        db["client"].update_one({"client_id": client_id}, {"$set": updates})
        updated = db["client"].find_one({"client_id": client_id}, {"_id": 0})
        write_audit_log(
            db,
            table_name="client",
            operation="UPDATE",
            record_id=client_id,
            data_before=existing,
            data_after=updated,
            user_id=user.user_id,
            db_user=user.db_user_label,
        )
    else:
        updated = existing

    assert updated is not None
    return ClientOut(**updated)


@router.get("/{client_id}/measurements", response_model=list[MeasurementOut])
def list_measurements(
    client_id: int,
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[MeasurementOut]:
    if not db["client"].find_one({"client_id": client_id}, {"_id": 1}):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado.")

    docs = db.measurement.find({"client_id": client_id}, {"_id": 0}).sort("taken_at", -1)
    return [MeasurementOut(**doc) for doc in docs]


@router.post(
    "/{client_id}/measurements",
    response_model=MeasurementOut,
    status_code=status.HTTP_201_CREATED,
)
def create_measurement(
    client_id: int,
    body: MeasurementCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> MeasurementOut:
    if not db["client"].find_one({"client_id": client_id}, {"_id": 1}):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado.")

    measurement_id = get_next_sequence(db, "measurement")
    doc = {
        "measurement_id": int(measurement_id),
        **body.model_dump(),
        "taken_at": datetime.now(timezone.utc),
        "client_id": int(client_id),
    }
    db.measurement.insert_one(doc)
    write_audit_log(
        db,
        table_name="measurement",
        operation="INSERT",
        record_id=measurement_id,
        data_before=None,
        data_after=doc,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    return MeasurementOut(**doc)
