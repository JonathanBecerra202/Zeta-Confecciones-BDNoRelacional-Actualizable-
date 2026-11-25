from contextlib import asynccontextmanager
import logging
from pathlib import Path

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pymongo.errors import DuplicateKeyError, PyMongoError, WriteError

from .config import get_settings
from .database import close_client, ensure_profile_schema_and_indexes, get_db
from .routers import (
    admin_users,
    audit,
    auth,
    avatars,
    clients,
    departments,
    orders,
    organizations,
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    avatars_path = Path(settings.avatars_dir)
    avatars_path.mkdir(parents=True, exist_ok=True)

    try:
        db = get_db()
        ensure_profile_schema_and_indexes(db)
    except PyMongoError as exc:
        logger.warning("MongoDB startup initialization skipped: %s", exc)

    yield
    close_client()


app = FastAPI(
    title="Zeta Confecciones API",
    version="1.0.0",
    lifespan=lifespan,
)

settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

static_root = Path(settings.avatars_dir).parent
static_root.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_root)), name="static")


@app.exception_handler(DuplicateKeyError)
async def duplicate_key_handler(_: Request, exc: DuplicateKeyError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={"detail": "Ya existe un registro con ese valor único.", "error": str(exc)},
    )


@app.exception_handler(WriteError)
async def write_error_handler(_: Request, exc: WriteError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": "Los datos no cumplen las validaciones de MongoDB.", "error": str(exc)},
    )


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(auth.router)
app.include_router(admin_users.router)
app.include_router(avatars.router)
app.include_router(organizations.router)
app.include_router(departments.router)
app.include_router(clients.router)
app.include_router(orders.router)
app.include_router(audit.router)
