from pathlib import Path
import shutil

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pymongo.database import Database

from ..config import get_settings
from ..database import get_db, write_audit_log
from ..schemas import AvatarUploadOut
from ..security import CurrentUser, require_admin

router = APIRouter(prefix="/users", tags=["avatars"])

ALLOWED_MIME_TO_EXT = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


def _user_avatar_dir(user_id: str) -> Path:
    settings = get_settings()
    base = Path(settings.avatars_dir).resolve()
    target = (base / user_id).resolve()
    if base not in target.parents and target != base:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="ID de usuario inválido.")
    return target


@router.post("/{user_id}/avatar", response_model=AvatarUploadOut)
async def upload_avatar(
    user_id: str,
    file: UploadFile = File(...),
    admin: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> AvatarUploadOut:
    existing = db.profile.find_one({"user_id": user_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")

    content_type = (file.content_type or "").lower()
    ext = ALLOWED_MIME_TO_EXT.get(content_type)
    if ext is None and file.filename:
        suffix = Path(file.filename).suffix.lower().lstrip(".")
        if suffix in ("jpg", "jpeg"):
            ext = "jpg"
        elif suffix in ("png", "webp"):
            ext = suffix
    if ext is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Formato de imagen no soportado. Usa JPG, PNG o WebP.",
        )

    settings = get_settings()
    data = await file.read()
    if len(data) > settings.max_avatar_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La imagen supera los 2 MB.",
        )

    user_dir = _user_avatar_dir(user_id)
    if user_dir.exists():
        shutil.rmtree(user_dir, ignore_errors=True)
    user_dir.mkdir(parents=True, exist_ok=True)

    filename = f"avatar.{ext}"
    file_path = user_dir / filename
    file_path.write_bytes(data)

    avatar_url = f"/static/avatars/{user_id}/{filename}"
    db.profile.update_one({"user_id": user_id}, {"$set": {"avatar_path": avatar_url}})
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
    return AvatarUploadOut(avatar_path=avatar_url, avatar_url=avatar_url)


@router.delete("/{user_id}/avatar", status_code=status.HTTP_204_NO_CONTENT)
def delete_avatar(
    user_id: str,
    admin: CurrentUser = Depends(require_admin),
    db: Database = Depends(get_db),
) -> None:
    existing = db.profile.find_one({"user_id": user_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado.")

    user_dir = _user_avatar_dir(user_id)
    if user_dir.exists():
        shutil.rmtree(user_dir, ignore_errors=True)

    db.profile.update_one({"user_id": user_id}, {"$set": {"avatar_path": None}})
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
