from datetime import datetime, timezone
from typing import Any, Literal

from fastapi import APIRouter, Depends, Query
from pymongo.database import Database

from ..database import get_db
from ..schemas import AuditLogOut, AuditPageOut
from ..security import CurrentUser, require_admin

router = APIRouter(prefix="/audit", tags=["audit"])


def _format_logged_at(val: Any) -> str:
    if isinstance(val, datetime):
        dt = val if val.tzinfo else val.replace(tzinfo=timezone.utc)
        return dt.isoformat()
    return str(val or "")


@router.get("", response_model=AuditPageOut)
def list_audit_logs(
    page: int = Query(default=0, ge=0),
    page_size: int = Query(default=10, ge=1, le=100),
    operation: Literal["INSERT", "UPDATE", "DELETE"] | None = Query(default=None),
    user_ids: list[str] | None = Query(default=None),
    include_system: bool = Query(default=False),
    _: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> AuditPageOut:
    query: dict[str, Any] = {}
    if operation is not None:
        query["operation"] = operation

    if user_ids is not None:
        # Support comma-separated values in addition to repeated query params
        flat_ids: list[str] = []
        for item in user_ids:
            for part in item.split(","):
                stripped = part.strip()
                if stripped:
                    flat_ids.append(stripped)

        if not flat_ids and not include_system:
            return AuditPageOut(rows=[], total=0)
        if not flat_ids:
            query["user_id"] = None
        elif not include_system:
            query["user_id"] = {"$in": flat_ids}
        else:
            query["$or"] = [{"user_id": {"$in": flat_ids}}, {"user_id": None}]

    total = db.audit_log.count_documents(query)
    cursor = (
        db.audit_log.find(query, {"_id": 0})
        .sort([("logged_at", -1), ("audit_log_id", -1)])
        .skip(page * page_size)
        .limit(page_size)
    )

    rows = [
        AuditLogOut(
            audit_log_id=int(doc["audit_log_id"]),
            table_name=doc["table_name"],
            operation=doc["operation"],
            record_id=doc.get("record_id"),
            before=doc.get("data_before"),
            after=doc.get("data_after"),
            logged_at=_format_logged_at(doc.get("logged_at")),
            user_id=doc.get("user_id"),
            db_user=doc.get("db_user"),
        )
        for doc in cursor
    ]
    return AuditPageOut(rows=rows, total=total)
