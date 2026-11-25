"""Seed the initial Admin user into the `profile` collection."""

import argparse
from datetime import datetime, timezone
import uuid

from app.database import ensure_profile_schema_and_indexes, get_db, write_audit_log
from app.security import hash_password


def main() -> None:
    parser = argparse.ArgumentParser(description="Create initial Admin user in MongoDB.")
    parser.add_argument("--email", default="admin@zetaconfecciones.com")
    parser.add_argument("--password", default="Admin1234!")
    parser.add_argument("--name", default="Administrador Zeta")
    parser.add_argument(
        "--must-change-password",
        action="store_true",
        help="Require password change on first login.",
    )
    args = parser.parse_args()

    db = get_db()
    ensure_profile_schema_and_indexes(db)

    admin_role = db.role.find_one({"name": "Admin"}, {"_id": 0, "role_id": 1})
    if not admin_role:
        raise RuntimeError("No se encontró el rol 'Admin' en la colección `role`.")

    email_normalized = args.email.strip().lower()
    existing = db.profile.find_one({"email": email_normalized}, {"_id": 0})
    if existing:
        print(f"El usuario {email_normalized} ya existe (user_id={existing['user_id']}).")
        return

    user_id = str(uuid.uuid4())
    doc = {
        "user_id": user_id,
        "email": email_normalized,
        "password_hash": hash_password(args.password),
        "must_change_password": bool(args.must_change_password),
        "full_name": args.name.strip(),
        "active": True,
        "created_at": datetime.now(timezone.utc),
        "role_id": int(admin_role["role_id"]),
        "avatar_path": None,
    }
    db.profile.insert_one(doc)
    write_audit_log(
        db,
        table_name="profile",
        operation="INSERT",
        record_id=user_id,
        data_before=None,
        data_after=doc,
        user_id=None,
        db_user="seed_admin",
    )
    print(f"Admin creado exitosamente: {email_normalized} (user_id={user_id})")


if __name__ == "__main__":
    main()
