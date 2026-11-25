from datetime import datetime, timezone
import logging
from typing import Any

from pymongo import MongoClient, ReturnDocument
from pymongo.database import Database
from pymongo.errors import OperationFailure

from .config import get_settings

logger = logging.getLogger(__name__)

_client: MongoClient | None = None

# Mapping from collection name to its integer primary key field.
PK_FIELDS: dict[str, str] = {
    "role": "role_id",
    "organization": "organization_id",
    "department": "department_id",
    "client": "client_id",
    "measurement": "measurement_id",
    "garment_order": "garment_order_id",
    "payment": "payment_id",
    "audit_log": "audit_log_id",
}


def get_client() -> MongoClient:
    global _client
    if _client is None:
        settings = get_settings()
        _client = MongoClient(settings.mongodb_uri)
    return _client


def close_client() -> None:
    global _client
    if _client is not None:
        _client.close()
        _client = None


def get_db() -> Database:
    settings = get_settings()
    return get_client()[settings.mongodb_db_name]


def _seed_counter_if_missing(db: Database, name: str) -> None:
    """Initialize counter from the current max ID in the collection if absent."""
    if db.counters.find_one({"_id": name}) is not None:
        return
    pk_field = PK_FIELDS.get(name)
    max_seq = 0
    if pk_field and name in db.list_collection_names():
        top = db[name].find_one(sort=[(pk_field, -1)], projection={pk_field: 1, "_id": 0})
        if top and isinstance(top.get(pk_field), int):
            max_seq = top[pk_field]
    try:
        db.counters.insert_one({"_id": name, "seq": int(max_seq)})
    except Exception:
        # Another worker may have initialized it concurrently.
        pass


def get_next_sequence(db: Database, name: str) -> int:
    """Atomically increment and return the next integer sequence ID."""
    _seed_counter_if_missing(db, name)
    doc = db.counters.find_one_and_update(
        {"_id": name},
        {"$inc": {"seq": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    return int(doc["seq"])


def ensure_profile_schema_and_indexes(db: Database) -> None:
    """Ensure `profile` $jsonSchema supports auth fields and unique email index."""
    existing = set(db.list_collection_names())

    for coll_name in PK_FIELDS:
        if coll_name in existing:
            _seed_counter_if_missing(db, coll_name)

    profile_validator = {
        "$jsonSchema": {
            "bsonType": "object",
            "required": ["user_id", "full_name", "role_id"],
            "properties": {
                "user_id": {
                    "bsonType": "string",
                    "pattern": "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
                    "description": "PK. UUID del usuario (texto con formato UUID)",
                },
                "full_name": {
                    "bsonType": "string",
                    "description": "Nombre completo (obligatorio)",
                },
                "email": {
                    "bsonType": ["string", "null"],
                    "description": "Correo electrónico único para autenticación",
                },
                "password_hash": {
                    "bsonType": ["string", "null"],
                    "description": "Hash bcrypt de la contraseña",
                },
                "must_change_password": {
                    "bsonType": ["bool", "null"],
                    "description": "Indica si el usuario debe cambiar su contraseña temporal",
                },
                "active": {
                    "bsonType": ["bool", "null"],
                    "description": "Indica si el usuario está activo",
                },
                "created_at": {
                    "bsonType": ["date", "null"],
                    "description": "Fecha de creación",
                },
                "role_id": {
                    "bsonType": "int",
                    "description": "FK -> role.role_id",
                },
                "avatar_path": {
                    "bsonType": ["string", "null"],
                    "description": "Ruta de la foto de perfil",
                },
            },
        }
    }

    if "profile" in existing:
        try:
            db.command(
                {
                    "collMod": "profile",
                    "validator": profile_validator,
                    "validationLevel": "strict",
                    "validationAction": "error",
                }
            )
        except OperationFailure as exc:
            logger.warning("Could not collMod profile validator: %s", exc)
    else:
        db.create_collection(
            "profile",
            validator=profile_validator,
            validationLevel="strict",
            validationAction="error",
        )
        db.profile.create_index([("user_id", 1)], unique=True)

    db.profile.create_index(
        [("email", 1)],
        unique=True,
        partialFilterExpression={"email": {"$type": "string"}},
    )


def sanitize_for_audit(doc: dict[str, Any] | None) -> dict[str, Any] | None:
    """Remove MongoDB _id and sensitive fields before storing in audit_log."""
    if doc is None:
        return None
    cleaned = {k: v for k, v in doc.items() if k not in ("_id", "password_hash")}
    return cleaned


def write_audit_log(
    db: Database,
    *,
    table_name: str,
    operation: str,
    record_id: str | int | None,
    data_before: dict[str, Any] | None,
    data_after: dict[str, Any] | None,
    user_id: str | None,
    db_user: str,
) -> None:
    """Insert an audit_log record matching the strict MongoDB $jsonSchema."""
    audit_id = get_next_sequence(db, "audit_log")
    db.audit_log.insert_one(
        {
            "audit_log_id": int(audit_id),
            "table_name": table_name,
            "operation": operation,
            "record_id": str(record_id) if record_id is not None else None,
            "data_before": sanitize_for_audit(data_before),
            "data_after": sanitize_for_audit(data_after),
            "logged_at": datetime.now(timezone.utc),
            "user_id": user_id,
            "db_user": db_user,
        }
    )
