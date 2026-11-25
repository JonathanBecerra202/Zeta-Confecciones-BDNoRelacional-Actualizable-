from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


# ---------------------------------------------------------------------------
# Auth & Users
# ---------------------------------------------------------------------------

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class ChangePasswordRequest(BaseModel):
    current_password: str | None = None
    new_password: str = Field(min_length=6)


class UserMeOut(BaseModel):
    user_id: str
    email: str
    full_name: str
    role: Literal["Admin", "Employee"]
    active: bool
    must_change_password: bool
    avatar_path: str | None = None
    avatar_url: str | None = None


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserMeOut


class ManagedUserOut(BaseModel):
    user_id: str
    email: str
    full_name: str
    role: Literal["Admin", "Employee"]
    active: bool
    must_change_password: bool
    created_at: datetime | None = None
    avatar_path: str | None = None
    avatar_url: str | None = None


class ManagedUsersPageOut(BaseModel):
    users: list[ManagedUserOut]
    total: int


class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    full_name: str = Field(min_length=1)
    role: Literal["Admin", "Employee"] = "Employee"

    @field_validator("full_name")
    @classmethod
    def check_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El nombre completo no puede estar vacío.")
        return v.strip()


class UpdateUserRequest(BaseModel):
    full_name: str | None = None
    role: Literal["Admin", "Employee"] | None = None
    active: bool | None = None

    @field_validator("full_name")
    @classmethod
    def check_not_blank(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("El nombre completo no puede estar vacío.")
        return v.strip() if v is not None else None


class SetPasswordRequest(BaseModel):
    password: str = Field(min_length=6)


class UserNameOut(BaseModel):
    user_id: str
    full_name: str


class AvatarUploadOut(BaseModel):
    avatar_path: str
    avatar_url: str


# ---------------------------------------------------------------------------
# Organizations & Departments
# ---------------------------------------------------------------------------

class OrganizationCreate(BaseModel):
    name: str = Field(min_length=1)

    @field_validator("name")
    @classmethod
    def check_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El nombre de la organización no puede estar vacío.")
        return v.strip()


class OrganizationUpdate(OrganizationCreate):
    pass


class OrganizationOut(BaseModel):
    organization_id: int
    name: str
    created_at: datetime | None = None


class DepartmentCreate(BaseModel):
    name: str = Field(min_length=1)
    organization_id: int

    @field_validator("name")
    @classmethod
    def check_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El nombre de la dependencia no puede estar vacío.")
        return v.strip()


class DepartmentUpdate(BaseModel):
    name: str = Field(min_length=1)

    @field_validator("name")
    @classmethod
    def check_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El nombre de la dependencia no puede estar vacío.")
        return v.strip()


class DepartmentOut(BaseModel):
    department_id: int
    name: str
    organization_id: int
    created_at: datetime | None = None


# ---------------------------------------------------------------------------
# Clients
# ---------------------------------------------------------------------------

class ClientCreate(BaseModel):
    first_name: str = Field(min_length=1)
    middle_name: str | None = None
    last_name: str = Field(min_length=1)
    second_last_name: str | None = None
    phone: str | None = Field(default=None, pattern=r"^[0-9]{7,15}$")
    active: bool = True
    department_id: int | None = None

    @field_validator("first_name", "last_name")
    @classmethod
    def check_required_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El campo no puede estar vacío.")
        return v.strip()


class ClientUpdate(BaseModel):
    first_name: str | None = Field(default=None, min_length=1)
    middle_name: str | None = None
    last_name: str | None = Field(default=None, min_length=1)
    second_last_name: str | None = None
    phone: str | None = Field(default=None, pattern=r"^[0-9]{7,15}$")
    active: bool | None = None
    department_id: int | None = None


class ClientOut(BaseModel):
    client_id: int
    first_name: str
    middle_name: str | None = None
    last_name: str
    second_last_name: str | None = None
    phone: str | None = None
    active: bool = True
    department_id: int | None = None
    registered_at: datetime | None = None
    updated_at: datetime | None = None


# ---------------------------------------------------------------------------
# Measurements
# ---------------------------------------------------------------------------

class MeasurementCreate(BaseModel):
    back_width_ae: float | None = Field(default=None, ge=0)
    bust_circumference_cb: float | None = Field(default=None, ge=0)
    waist_circumference_cc: float | None = Field(default=None, ge=0)
    hip_circumference_ck: float | None = Field(default=None, ge=0)
    torso_length_lt: float | None = Field(default=None, ge=0)
    pants_length_lp: float | None = Field(default=None, ge=0)
    sleeve_length_lm: float | None = Field(default=None, ge=0)
    sleeve_circumference_cm: float | None = Field(default=None, ge=0)
    leg_circumference_cp: float | None = Field(default=None, ge=0)
    notes: str | None = None


class MeasurementOut(MeasurementCreate):
    measurement_id: int
    client_id: int
    taken_at: datetime


# ---------------------------------------------------------------------------
# Garment Orders & Payments
# ---------------------------------------------------------------------------

OrderStatusType = Literal["Pending", "In_progress", "Delivered", "Cancelled"]


class GarmentOrderCreate(BaseModel):
    description: str = Field(min_length=1)
    quantity: int = Field(default=1, ge=1)
    unit_price: float = Field(ge=0)
    total_price: float | None = Field(default=None, ge=0)
    delivery_date: date | str | None = None
    notes: str | None = None
    client_id: int
    measurement_id: int | None = None
    embroidery: bool = False
    status: OrderStatusType = "Pending"


class GarmentOrderUpdate(BaseModel):
    description: str | None = Field(default=None, min_length=1)
    quantity: int | None = Field(default=None, ge=1)
    unit_price: float | None = Field(default=None, ge=0)
    total_price: float | None = Field(default=None, ge=0)
    delivery_date: date | str | None = None
    notes: str | None = None
    measurement_id: int | None = None
    embroidery: bool | None = None
    status: OrderStatusType | None = None


class GarmentOrderOut(BaseModel):
    garment_order_id: int
    description: str
    total_price: float
    amount_paid: float
    balance_due: float | None = None
    status: OrderStatusType
    paid: bool
    created_at: datetime
    delivery_date: str | None = None
    notes: str | None = None
    quantity: int
    unit_price: float
    embroidery: bool
    client_id: int
    measurement_id: int | None = None


class PaymentCreate(BaseModel):
    amount: float = Field(gt=0)
    note: str | None = None


class PaymentOut(BaseModel):
    payment_id: int
    amount: float
    note: str | None = None
    paid_at: datetime
    garment_order_id: int


# ---------------------------------------------------------------------------
# Audit Log
# ---------------------------------------------------------------------------

class AuditLogOut(BaseModel):
    audit_log_id: int
    table_name: str
    operation: Literal["INSERT", "UPDATE", "DELETE"]
    record_id: str | None = None
    before: dict[str, Any] | None = None
    after: dict[str, Any] | None = None
    logged_at: str
    user_id: str | None = None
    db_user: str | None = None


class AuditPageOut(BaseModel):
    rows: list[AuditLogOut]
    total: int
