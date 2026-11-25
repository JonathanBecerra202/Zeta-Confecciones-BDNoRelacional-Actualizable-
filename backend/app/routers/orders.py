from datetime import date, datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pymongo.database import Database

from ..database import get_db, get_next_sequence, write_audit_log
from ..schemas import (
    GarmentOrderCreate,
    GarmentOrderOut,
    GarmentOrderUpdate,
    PaymentCreate,
    PaymentOut,
)
from ..security import CurrentUser, get_current_user

router = APIRouter(tags=["orders"])

BOGOTA_TZ = timezone(timedelta(hours=-5))


def _format_delivery_date(val: Any) -> str | None:
    if val is None:
        return None
    if isinstance(val, datetime):
        dt = val if val.tzinfo else val.replace(tzinfo=timezone.utc)
        return dt.astimezone(BOGOTA_TZ).strftime("%Y-%m-%d")
    if isinstance(val, date):
        return val.strftime("%Y-%m-%d")
    return str(val)[:10]


def _parse_delivery_date(val: date | str | None, *, check_not_past: bool = False) -> datetime | None:
    if val is None or val == "":
        return None
    if isinstance(val, str):
        try:
            parsed_date = date.fromisoformat(val[:10])
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Formato de fecha de entrega inválido. Usa YYYY-MM-DD.",
            ) from exc
    else:
        parsed_date = val

    if check_not_past:
        today_bogota = datetime.now(BOGOTA_TZ).date()
        if parsed_date < today_bogota:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La fecha de entrega no puede estar en el pasado.",
            )

    return datetime(
        parsed_date.year,
        parsed_date.month,
        parsed_date.day,
        0,
        0,
        0,
        tzinfo=BOGOTA_TZ,
    )


def _serialize_order(doc: dict[str, Any]) -> GarmentOrderOut:
    return GarmentOrderOut(
        garment_order_id=int(doc["garment_order_id"]),
        description=doc["description"],
        total_price=float(doc["total_price"]),
        amount_paid=float(doc.get("amount_paid") or 0),
        balance_due=float(doc["balance_due"]) if doc.get("balance_due") is not None else None,
        status=doc.get("status") or "Pending",
        paid=doc.get("payment_status") == "Paid",
        created_at=doc["created_at"],
        delivery_date=_format_delivery_date(doc.get("delivery_date")),
        notes=doc.get("notes"),
        quantity=int(doc.get("quantity") or 1),
        unit_price=float(doc["unit_price"]),
        embroidery=bool(doc.get("embroidery", False)),
        client_id=int(doc["client_id"]),
        measurement_id=int(doc["measurement_id"]) if doc.get("measurement_id") is not None else None,
    )


def _recalculate_order_payments(db: Database, order_id: int) -> dict[str, Any]:
    order = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pedido no encontrado.")

    total_paid = sum(
        float(p["amount"])
        for p in db.payment.find({"garment_order_id": order_id}, {"_id": 0, "amount": 1})
    )
    total_price = float(order["total_price"])
    balance_due = max(0.0, round(total_price - total_paid, 2))
    payment_status = "Paid" if balance_due <= 0 else "Pending"

    db.garment_order.update_one(
        {"garment_order_id": order_id},
        {
            "$set": {
                "amount_paid": round(total_paid, 2),
                "balance_due": balance_due,
                "payment_status": payment_status,
            }
        },
    )
    updated = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})
    assert updated is not None
    return updated


@router.get("/orders", response_model=list[GarmentOrderOut])
def list_orders(
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[GarmentOrderOut]:
    docs = db.garment_order.find({}, {"_id": 0}).sort("created_at", -1)
    return [_serialize_order(doc) for doc in docs]


@router.post("/orders", response_model=GarmentOrderOut, status_code=status.HTTP_201_CREATED)
def create_order(
    body: GarmentOrderCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> GarmentOrderOut:
    if not db["client"].find_one({"client_id": body.client_id}, {"_id": 1}):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado.")

    if body.measurement_id is not None:
        if not db.measurement.find_one({"measurement_id": body.measurement_id}, {"_id": 1}):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Medida no encontrada."
            )

    total_price = (
        float(body.total_price)
        if body.total_price is not None
        else round(body.quantity * body.unit_price, 2)
    )
    delivery_dt = _parse_delivery_date(body.delivery_date, check_not_past=True)

    order_id = get_next_sequence(db, "garment_order")
    doc = {
        "garment_order_id": int(order_id),
        "description": body.description.strip(),
        "total_price": total_price,
        "amount_paid": 0.0,
        "balance_due": total_price,
        "status": body.status,
        "payment_status": "Pending",
        "created_at": datetime.now(timezone.utc),
        "delivery_date": delivery_dt,
        "notes": body.notes,
        "quantity": int(body.quantity),
        "unit_price": float(body.unit_price),
        "client_id": int(body.client_id),
        "measurement_id": int(body.measurement_id) if body.measurement_id is not None else None,
        "embroidery": bool(body.embroidery),
    }
    db.garment_order.insert_one(doc)
    write_audit_log(
        db,
        table_name="garment_order",
        operation="INSERT",
        record_id=order_id,
        data_before=None,
        data_after=doc,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    return _serialize_order(doc)


@router.patch("/orders/{order_id}", response_model=GarmentOrderOut)
def update_order(
    order_id: int,
    body: GarmentOrderUpdate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> GarmentOrderOut:
    existing = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pedido no encontrado.")

    updates = body.model_dump(exclude_unset=True)
    if "description" in updates and updates["description"] is not None:
        updates["description"] = updates["description"].strip()
    if "delivery_date" in updates:
        updates["delivery_date"] = _parse_delivery_date(
            updates["delivery_date"], check_not_past=False
        )
    if "measurement_id" in updates and updates["measurement_id"] is not None:
        if not db.measurement.find_one({"measurement_id": updates["measurement_id"]}, {"_id": 1}):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Medida no encontrada."
            )
        updates["measurement_id"] = int(updates["measurement_id"])

    qty = int(updates.get("quantity", existing["quantity"]))
    unit_price = float(updates.get("unit_price", existing["unit_price"]))
    if "total_price" not in updates and ("quantity" in updates or "unit_price" in updates):
        updates["total_price"] = round(qty * unit_price, 2)

    if "total_price" in updates:
        new_total = float(updates["total_price"])
        amount_paid = float(existing.get("amount_paid") or 0)
        if amount_paid > new_total:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El precio total no puede ser menor al monto ya abonado.",
            )
        balance_due = max(0.0, round(new_total - amount_paid, 2))
        updates["balance_due"] = balance_due
        updates["payment_status"] = "Paid" if balance_due <= 0 else "Pending"

    if updates:
        db.garment_order.update_one({"garment_order_id": order_id}, {"$set": updates})
        updated = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})
        write_audit_log(
            db,
            table_name="garment_order",
            operation="UPDATE",
            record_id=order_id,
            data_before=existing,
            data_after=updated,
            user_id=user.user_id,
            db_user=user.db_user_label,
        )
    else:
        updated = existing

    assert updated is not None
    return _serialize_order(updated)


@router.delete("/orders/{order_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_order(
    order_id: int,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> None:
    existing = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pedido no encontrado.")

    payments = list(db.payment.find({"garment_order_id": order_id}, {"_id": 0}))
    if payments:
        db.payment.delete_many({"garment_order_id": order_id})
        for p in payments:
            write_audit_log(
                db,
                table_name="payment",
                operation="DELETE",
                record_id=p["payment_id"],
                data_before=p,
                data_after=None,
                user_id=user.user_id,
                db_user=user.db_user_label,
            )

    db.garment_order.delete_one({"garment_order_id": order_id})
    write_audit_log(
        db,
        table_name="garment_order",
        operation="DELETE",
        record_id=order_id,
        data_before=existing,
        data_after=None,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )


# ---------------------------------------------------------------------------
# Payments
# ---------------------------------------------------------------------------

@router.get("/orders/{order_id}/payments", response_model=list[PaymentOut])
def list_payments(
    order_id: int,
    _: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> list[PaymentOut]:
    if not db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 1}):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pedido no encontrado.")
    docs = db.payment.find({"garment_order_id": order_id}, {"_id": 0}).sort("paid_at", -1)
    return [PaymentOut(**doc) for doc in docs]


@router.post(
    "/orders/{order_id}/payments",
    response_model=PaymentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_payment(
    order_id: int,
    body: PaymentCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> PaymentOut:
    order_before = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})
    if not order_before:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pedido no encontrado.")

    current_paid = float(order_before.get("amount_paid") or 0)
    total_price = float(order_before["total_price"])
    if round(current_paid + body.amount, 2) > round(total_price, 2):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El abono supera el saldo pendiente del pedido.",
        )

    payment_id = get_next_sequence(db, "payment")
    payment_doc = {
        "payment_id": int(payment_id),
        "amount": float(body.amount),
        "note": body.note,
        "paid_at": datetime.now(timezone.utc),
        "garment_order_id": int(order_id),
    }
    db.payment.insert_one(payment_doc)
    write_audit_log(
        db,
        table_name="payment",
        operation="INSERT",
        record_id=payment_id,
        data_before=None,
        data_after=payment_doc,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )

    order_after = _recalculate_order_payments(db, order_id)
    write_audit_log(
        db,
        table_name="garment_order",
        operation="UPDATE",
        record_id=order_id,
        data_before=order_before,
        data_after=order_after,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )
    return PaymentOut(**payment_doc)


def _delete_payment_impl(
    db: Database,
    user: CurrentUser,
    payment_id: int,
    expected_order_id: int | None = None,
) -> None:
    query: dict[str, Any] = {"payment_id": payment_id}
    if expected_order_id is not None:
        query["garment_order_id"] = expected_order_id

    payment = db.payment.find_one(query, {"_id": 0})
    if not payment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Abono no encontrado.")

    order_id = int(payment["garment_order_id"])
    order_before = db.garment_order.find_one({"garment_order_id": order_id}, {"_id": 0})

    db.payment.delete_one({"payment_id": payment_id})
    write_audit_log(
        db,
        table_name="payment",
        operation="DELETE",
        record_id=payment_id,
        data_before=payment,
        data_after=None,
        user_id=user.user_id,
        db_user=user.db_user_label,
    )

    if order_before:
        order_after = _recalculate_order_payments(db, order_id)
        write_audit_log(
            db,
            table_name="garment_order",
            operation="UPDATE",
            record_id=order_id,
            data_before=order_before,
            data_after=order_after,
            user_id=user.user_id,
            db_user=user.db_user_label,
        )


@router.delete("/orders/{order_id}/payments/{payment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_order_payment(
    order_id: int,
    payment_id: int,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> None:
    _delete_payment_impl(db, user, payment_id, expected_order_id=order_id)


@router.delete("/payments/{payment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_payment(
    payment_id: int,
    user: CurrentUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> None:
    _delete_payment_impl(db, user, payment_id)
