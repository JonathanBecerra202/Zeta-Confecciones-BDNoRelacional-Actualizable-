/*
----------------Transformacion de SQL a NoSQL: Z_CONFECCIONES - Colecciones con Validaciones

-->Herramientas: MongoDB Compass / Shell (mongosh)

--Orden de ejecución:
--1. CREACIÓN DE BASE DE DATOS
--2. CREACIÓN DE COLECCIONES CON VALIDACIÓN (primero las "padre", luego las "hijas")
--3. ÍNDICES ÚNICOS (equivalen a PRIMARY KEY y UNIQUE)
--4. CONSULTAS DE VALIDACIÓN
--5. INSERCIÓN DE DATOS
--6. CONSULTA DE DATOS (JOIN con $lookup)

--Equivalencias que se usan en todo el script:
--  SERIAL / INT / INTEGER ........ bsonType: "int"
--  NUMERIC ....................... bsonType: "number" (acepta int, double, decimal)
--  TEXT / VARCHAR(n) ............. bsonType: "string" (+ maxLength si tiene tamaño)
--  BOOLEAN ....................... bsonType: "bool"
--  TIMESTAMPTZ / DATE ............ bsonType: "date"
--  UUID .......................... bsonType: "string" (+ pattern de UUID)
--  JSONB ......................... bsonType: "object"
--  ENUM / CHECK (IN ...) ......... enum: [ ... ]
--  CHECK (x >= 0) ................ minimum: 0
--  CHECK (length(trim(x)) > 0) ... minLength: 1 + pattern: "\\S"
--  CHECK (phone ~ '^[0-9]+$') .... pattern
--  CHECK (a <= b) entre columnas . $expr dentro del validator
--  NOT NULL ...................... required: [ ... ]
--  Columna que acepta NULL ....... bsonType: [ "tipo", "null" ]
--  PRIMARY KEY / UNIQUE .......... createIndex({ campo: 1 }, { unique: true })
--  FOREIGN KEY ................... NO se valida en MongoDB. Se deja el campo (int)
--                                  con su descripción y se une con $lookup.
--  DEFAULT ....................... MongoDB no tiene DEFAULT: el valor se envía al insertar.
--  TRIGGERS ...................... no se incluyen (según lo acordado).


---------------------------------------------------------------------------
-----------1. CREACION DE BASE DE DATOS
---------------------------------------------------------------------------

*/
db = db.getSiblingDB("Z-Confecciones");
/*


---------------------------------------------------------------------------
-----------2. CREACIÓN DE COLECCIONES CON VALIDACIÓN
---------------------------------------------------------------------------

---------------------------------------------------------------------------ROLE

CREATE TYPE z_conf.role_type AS ENUM ('Admin', 'Employee');

CREATE TABLE z_conf.role (
    role_id     SERIAL PRIMARY KEY,
    name        z_conf.role_type UNIQUE NOT NULL,
    description TEXT
);

--> creación con validación de esquema en MongoDB: JavaScript


*/
db.createCollection("role", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "role_id", "name" ],
         properties: {
            role_id: {
               bsonType: "int",
               description: "PK. Identificador único del rol (entero obligatorio)"
            },
            name: {
               bsonType: "string",
               enum: [ "Admin", "Employee" ], // Transformación del ENUM role_type
               description: "Nombre del rol: solo Admin o Employee"
            },
            description: {
               bsonType: [ "string", "null" ],
               description: "Descripción del rol (opcional)"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.role.createIndex({ role_id: 1 }, { unique: true });   // PRIMARY KEY
db.role.createIndex({ name: 1 }, { unique: true });      // UNIQUE
/*


----------------------------------------------------------------ORGANIZATION

CREATE TABLE z_conf.organization (
    organization_id SERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE z_conf.organization
ADD CONSTRAINT check_organization_name_not_empty
CHECK (length(trim(name)) > 0);

---- Con validaciones:


*/
db.createCollection("organization", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "organization_id", "name" ],
         properties: {
            organization_id: {
               bsonType: "int",
               description: "PK. Identificador único de la organización (entero obligatorio)"
            },
            name: {
               bsonType: "string",
               minLength: 1,
               pattern: "\\S", // Replica check_organization_name_not_empty: no solo espacios
               description: "Nombre de la organización (obligatorio, no vacío, único)"
            },
            created_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de creación"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.organization.createIndex({ organization_id: 1 }, { unique: true });   // PRIMARY KEY
db.organization.createIndex({ name: 1 }, { unique: true });              // UNIQUE
/*


-------------------------------------------------------------------DEPARTMENT

CREATE TABLE z_conf.department (
    department_id   SERIAL PRIMARY KEY,
    name            TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    organization_id INT NOT NULL
);

ALTER TABLE z_conf.department
ADD CONSTRAINT check_department_name_not_empty CHECK (length(trim(name)) > 0);

ALTER TABLE z_conf.department
ADD CONSTRAINT unique_department_name_per_organization UNIQUE (organization_id, name);

ALTER TABLE z_conf.department
ADD CONSTRAINT department_organization_fk
FOREIGN KEY (organization_id) REFERENCES z_conf.organization (organization_id);

---- Con validaciones:


*/
db.createCollection("department", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "department_id", "name", "organization_id" ],
         properties: {
            department_id: {
               bsonType: "int",
               description: "PK. Identificador único de la dependencia (entero obligatorio)"
            },
            name: {
               bsonType: "string",
               minLength: 1,
               pattern: "\\S",
               description: "Nombre de la dependencia (obligatorio, no vacío)"
            },
            created_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de creación"
            },
            organization_id: {
               bsonType: "int",
               description: "FK -> organization.organization_id"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.department.createIndex({ department_id: 1 }, { unique: true });                  // PRIMARY KEY
db.department.createIndex({ organization_id: 1, name: 1 }, { unique: true });        // UNIQUE (organization_id, name)
/*


----------------------------------------------------------------------CLIENT

CREATE TABLE z_conf.client (
    client_id        SERIAL PRIMARY KEY,
    first_name       TEXT NOT NULL,
    middle_name      TEXT,
    last_name        TEXT NOT NULL,
    second_last_name TEXT,
    phone            VARCHAR(30) UNIQUE,
    active           BOOLEAN DEFAULT TRUE,
    registered_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    department_id    INT
);

---- Con validaciones:


*/
db.createCollection("client", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "client_id", "first_name", "last_name" ],
         properties: {
            client_id: {
               bsonType: "int",
               description: "PK. Identificador único del cliente (entero obligatorio)"
            },
            first_name: {
               bsonType: "string",
               minLength: 1,
               pattern: "\\S",
               description: "Primer nombre (obligatorio, no vacío)"
            },
            middle_name: {
               bsonType: [ "string", "null" ],
               description: "Segundo nombre (opcional)"
            },
            last_name: {
               bsonType: "string",
               minLength: 1,
               pattern: "\\S",
               description: "Primer apellido (obligatorio, no vacío)"
            },
            second_last_name: {
               bsonType: [ "string", "null" ],
               description: "Segundo apellido (opcional)"
            },
            phone: {
               bsonType: [ "string", "null" ],
               pattern: "^[0-9]{7,15}$", // Replica check_phone_format: solo números, entre 7 y 15
               description: "Teléfono: solo dígitos, entre 7 y 15 caracteres (opcional, único)"
            },
            active: {
               bsonType: [ "bool", "null" ],
               description: "Indica si el cliente está activo"
            },
            registered_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de registro"
            },
            updated_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de actualización"
            },
            department_id: {
               bsonType: [ "int", "null" ],
               description: "FK -> department.department_id (opcional)"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.client.createIndex({ client_id: 1 }, { unique: true });   // PRIMARY KEY

// UNIQUE en phone: parcial, para permitir varios clientes sin teléfono (en SQL los NULL no chocan)
db.client.createIndex(
   { phone: 1 },
   { unique: true, partialFilterExpression: { phone: { $type: "string" } } }
);
/*


------------------------------------------------------------------MEASUREMENT

CREATE TABLE z_conf.measurement (
    measurement_id          SERIAL PRIMARY KEY,
    back_width_ae           NUMERIC,
    bust_circumference_cb   NUMERIC,
    waist_circumference_cc  NUMERIC,
    hip_circumference_ck    NUMERIC,
    torso_length_lt         NUMERIC,
    pants_length_lp         NUMERIC,
    sleeve_length_lm        NUMERIC,
    sleeve_circumference_cm NUMERIC,
    leg_circumference_cp    NUMERIC,
    notes                   TEXT,
    taken_at                TIMESTAMPTZ DEFAULT NOW(),
    client_id               INT NOT NULL
);

---- Con validaciones:


*/
db.createCollection("measurement", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "measurement_id", "client_id" ],
         properties: {
            measurement_id: {
               bsonType: "int",
               description: "PK. Identificador único de la medida (entero obligatorio)"
            },
            back_width_ae: {
               bsonType: [ "number", "null" ],
               minimum: 0, // Replica check_measurement_values: no negativas
               description: "Ancho de espalda"
            },
            bust_circumference_cb: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Contorno de busto"
            },
            waist_circumference_cc: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Contorno de cintura"
            },
            hip_circumference_ck: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Contorno de cadera"
            },
            torso_length_lt: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Largo de talle"
            },
            pants_length_lp: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Largo de pantalón"
            },
            sleeve_length_lm: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Largo de manga"
            },
            sleeve_circumference_cm: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Contorno de manga"
            },
            leg_circumference_cp: {
               bsonType: [ "number", "null" ],
               minimum: 0,
               description: "Contorno de pierna"
            },
            notes: {
               bsonType: [ "string", "null" ],
               description: "Observaciones"
            },
            taken_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de toma de la medida"
            },
            client_id: {
               bsonType: "int",
               description: "FK -> client.client_id"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.measurement.createIndex({ measurement_id: 1 }, { unique: true });   // PRIMARY KEY
/*


----------------------------------------------------------------GARMENT_ORDER

CREATE TYPE z_conf.order_status   AS ENUM ('Pending', 'In_progress', 'Delivered', 'Cancelled');
CREATE TYPE z_conf.payment_status AS ENUM ('Pending', 'Paid');

CREATE TABLE z_conf.garment_order (
    garment_order_id SERIAL PRIMARY KEY,
    description      TEXT NOT NULL,
    total_price      NUMERIC NOT NULL,
    amount_paid      NUMERIC DEFAULT 0,
    balance_due      NUMERIC,
    status           z_conf.order_status DEFAULT 'Pending',
    payment_status   z_conf.payment_status DEFAULT 'Pending',
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    delivery_date    DATE,
    notes            TEXT,
    quantity         INT NOT NULL DEFAULT 1,
    unit_price       NUMERIC NOT NULL,
    client_id        INT NOT NULL,
    measurement_id   INT,
    embroidery       BOOLEAN DEFAULT FALSE
);

---- Con validaciones:


*/
db.createCollection("garment_order", {
   validator: {
      $and: [
         {
            $jsonSchema: {
               bsonType: "object",
               required: [ "garment_order_id", "description", "total_price", "quantity", "unit_price", "client_id" ],
               properties: {
                  garment_order_id: {
                     bsonType: "int",
                     description: "PK. Identificador único del pedido (entero obligatorio)"
                  },
                  description: {
                     bsonType: "string",
                     description: "Descripción del pedido (obligatorio)"
                  },
                  total_price: {
                     bsonType: "number",
                     minimum: 0, // check_total_price
                     description: "Precio total del pedido (no negativo)"
                  },
                  amount_paid: {
                     bsonType: [ "number", "null" ],
                     minimum: 0, // check_amount_paid
                     description: "Valor pagado del pedido (no negativo)"
                  },
                  balance_due: {
                     bsonType: [ "number", "null" ],
                     description: "Saldo pendiente (en SQL lo calculaba un trigger; aquí lo envía la aplicación)"
                  },
                  status: {
                     bsonType: [ "string", "null" ],
                     enum: [ "Pending", "In_progress", "Delivered", "Cancelled", null ], // ENUM order_status
                     description: "Estado del pedido"
                  },
                  payment_status: {
                     bsonType: [ "string", "null" ],
                     enum: [ "Pending", "Paid", null ], // ENUM payment_status
                     description: "Estado del pago"
                  },
                  created_at: {
                     bsonType: [ "date", "null" ],
                     description: "Fecha de creación"
                  },
                  delivery_date: {
                     bsonType: [ "date", "null" ],
                     description: "Fecha de entrega (opcional)"
                  },
                  notes: {
                     bsonType: [ "string", "null" ],
                     description: "Observaciones"
                  },
                  quantity: {
                     bsonType: "int",
                     minimum: 1, // chk_garment_order_quantity_positive: mayor a cero
                     description: "Cantidad (entero mayor a cero)"
                  },
                  unit_price: {
                     bsonType: "number",
                     minimum: 0, // chk_garment_order_unit_price_positive
                     description: "Precio unitario (no negativo)"
                  },
                  client_id: {
                     bsonType: "int",
                     description: "FK -> client.client_id"
                  },
                  measurement_id: {
                     bsonType: [ "int", "null" ],
                     description: "FK -> measurement.measurement_id (opcional)"
                  },
                  embroidery: {
                     bsonType: [ "bool", "null" ],
                     description: "Indica si el pedido lleva bordado"
                  }
               }
            }
         },
         {
            // check_amount_paid_total: amount_paid no puede ser mayor que total_price
            // (CHECK entre dos columnas: se hace con $expr)
            $expr: { $lte: [ { $ifNull: [ "$amount_paid", 0 ] }, "$total_price" ] }
         }
      ]
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.garment_order.createIndex({ garment_order_id: 1 }, { unique: true });   // PRIMARY KEY
/*


Nota: la restricción chk_delivery_date_not_past (la fecha de entrega no puede estar en el pasado,
hora de Bogotá) NO se puede replicar en el validator porque depende de la fecha actual.
Se valida en la aplicación (Flutter/Angular) antes de insertar, igual que los triggers.


---------------------------------------------------------------------PAYMENT

CREATE TABLE z_conf.payment (
    payment_id       SERIAL PRIMARY KEY,
    amount           NUMERIC NOT NULL,
    note             TEXT,
    paid_at          TIMESTAMPTZ DEFAULT NOW(),
    garment_order_id INT NOT NULL
);

---- Con validaciones:


*/
db.createCollection("payment", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "payment_id", "amount", "garment_order_id" ],
         properties: {
            payment_id: {
               bsonType: "int",
               description: "PK. Identificador único del abono (entero obligatorio)"
            },
            amount: {
               bsonType: "number",
               exclusiveMinimum: true,
               minimum: 0, // check_payment_amount: el abono debe ser mayor que 0
               description: "Valor del abono (mayor que 0)"
            },
            note: {
               bsonType: [ "string", "null" ],
               description: "Nota del abono"
            },
            paid_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha del abono"
            },
            garment_order_id: {
               bsonType: "int",
               description: "FK -> garment_order.garment_order_id"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.payment.createIndex({ payment_id: 1 }, { unique: true });   // PRIMARY KEY
/*

--> Nota: si tu versión de MongoDB no acepta exclusiveMinimum dentro de $jsonSchema,
--  quita esa línea y usa en su lugar:  minimum: 0.01


---------------------------------------------------------------------PROFILE

CREATE TABLE z_conf.profile (
    user_id    UUID PRIMARY KEY,
    full_name  TEXT NOT NULL,
    active     BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    role_id    INT NOT NULL
);

---- Con validaciones:


*/
db.createCollection("profile", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "user_id", "full_name", "role_id" ],
         properties: {
            user_id: {
               bsonType: "string",
               pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
               description: "PK. UUID del usuario (texto con formato UUID)"
            },
            full_name: {
               bsonType: "string",
               description: "Nombre completo (obligatorio)"
            },
            active: {
               bsonType: [ "bool", "null" ],
               description: "Indica si el usuario está activo"
            },
            created_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de creación"
            },
            role_id: {
               bsonType: "int",
               description: "FK -> role.role_id"
            },
            avatar_path: {
               bsonType: [ "string", "null" ],
               description: "Ruta de la foto de perfil (campo que existe en la versión de Supabase)"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.profile.createIndex({ user_id: 1 }, { unique: true });   // PRIMARY KEY
/*


---------------------------------------------------------------------AUDIT_LOG

CREATE TYPE z_conf.audit_operation AS ENUM ('INSERT', 'UPDATE', 'DELETE');

CREATE TABLE z_conf.audit_log (
    audit_log_id SERIAL PRIMARY KEY,
    table_name   TEXT NOT NULL,
    operation    z_conf.audit_operation NOT NULL,
    record_id    TEXT,
    data_before  JSONB,
    data_after   JSONB,
    logged_at    TIMESTAMPTZ DEFAULT NOW(),
    user_id      UUID,
    db_user      TEXT NOT NULL DEFAULT session_user
);

---- Con validaciones:


*/
db.createCollection("audit_log", {
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "audit_log_id", "table_name", "operation", "db_user" ],
         properties: {
            audit_log_id: {
               bsonType: "int",
               description: "PK. Identificador único del registro de auditoría (entero obligatorio)"
            },
            table_name: {
               bsonType: "string",
               description: "Nombre de la tabla/colección afectada"
            },
            operation: {
               bsonType: "string",
               enum: [ "INSERT", "UPDATE", "DELETE" ], // ENUM audit_operation
               description: "Tipo de operación realizada"
            },
            record_id: {
               bsonType: [ "string", "null" ],
               description: "ID del registro afectado"
            },
            data_before: {
               bsonType: [ "object", "null" ],
               description: "Datos antes del cambio (JSONB en SQL, documento embebido en MongoDB)"
            },
            data_after: {
               bsonType: [ "object", "null" ],
               description: "Datos después del cambio"
            },
            logged_at: {
               bsonType: [ "date", "null" ],
               description: "Fecha de la auditoría"
            },
            user_id: {
               bsonType: [ "string", "null" ],
               pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
               description: "UUID del usuario de la aplicación (opcional)"
            },
            db_user: {
               bsonType: "string",
               description: "Usuario de base de datos que realizó la acción (admin_zconf / empleado_zconf)"
            }
         }
      }
   },
   validationLevel: "strict",
   validationAction: "error"
});

db.audit_log.createIndex({ audit_log_id: 1 }, { unique: true });   // PRIMARY KEY
/*


---------------------------------------------------------------------------
-----------Nota: Si deseo implementar modificaciones a una colección
---------------------------------------------------------------------------

Ejemplo: agregar el campo avatar_path o cambiar un enum en una colección ya creada.
collMod REEMPLAZA el validator completo, por eso se debe enviar el esquema completo de nuevo:


db.runCommand({
   collMod: "role",
   validator: {
      $jsonSchema: {
         bsonType: "object",
         required: [ "role_id", "name" ],
         properties: {
            role_id: { bsonType: "int", description: "PK del rol" },
            name: {
               bsonType: "string",
               enum: [ "Admin", "Employee" ],
               description: "Solo Admin o Employee"
            },
            description: { bsonType: [ "string", "null" ], description: "Descripción del rol" }
         }
      }
   },
   validationLevel: "strict",   // Aplica a inserciones y actualizaciones
   validationAction: "error"    // Lanza un error y bloquea el guardado si falla
});


---------------------------------------------------CONSULTAS DE VALIDACION DESPUES DE CREARLAS

--consultar las colecciones creadas

show collections

db.getCollectionNames()

--consultar las reglas de validacion implementadas:

db.getCollectionInfos({ name: "garment_order" })[0].options.validator

db.getCollectionInfos({ name: "garment_order" })

--consultar los índices (PK / UNIQUE) de una colección:

db.client.getIndexes()

db.nombrecoleccion.drop()//eliminacion en caso de requerirse


--------------------------------------------------------INSERCCIONES DE DATOS

--Importante sobre fechas: MongoDB guarda las fechas en UTC. Bogotá es UTC-5, por eso:
--   8:00 a.m. hora de Bogotá  =  13:00 UTC  =  "2026-01-10T08:00:00-05:00"
--Se puede escribir la fecha con el desfase -05:00 y MongoDB la convierte sola a UTC.
--(En Compass JSON: { "$date": "2026-01-10T08:00:00-05:00" })

--------------------------------------------------------
Opcion 1: Cargue de datos mediante archivos csv
--------------------------------------------------------

Herramienta: Compass

Seleccionar la coleccion y buscar la opcion de Importar Documento.
Se cargan los .csv (UTF-8). Éstos previamente son generados desde PgAdmin / Supabase.
En Compass, al importar, se debe indicar el tipo de cada columna (int, number, date, boolean, string).
En caso de tener inconvenientes en el cargue de datos con las fechas de tipo Date, se desactiva la validacion y luego se activa nuevamente.


////En caso que la regla no permita la insercción:

db.runCommand({
   collMod: "client",
   validationLevel: "off"
});


db.runCommand({
   collMod: "client",
   validationLevel: "strict"
});


--------------------------------------------------------
Opcion 2: Cargue de datos : Insercciones individuales
--------------------------------------------------------

Herramienta: Compass


{
  "organization_id": 1,
  "name": "Universidad de Pamplona",
  "created_at": { "$date": "2026-01-10T08:00:00-05:00" }
}


Herramienta: Mongosh


db.organization.insertOne({
  organization_id: NumberInt(1),
  name: "Universidad de Pamplona",
  created_at: new Date("2026-01-10T08:00:00-05:00")
});

nota. NumberInt(...) asegura que el valor se guarde como int (y no como double),
que es lo que exige la validación bsonType: "int".


--------------------------------------------------------
Opcion 3: Cargue de datos usando el InsertMany
--------------------------------------------------------

Herramienta: Mongosh


db.role.insertMany([
  { role_id: NumberInt(1), name: "Admin",    description: "Administrador del sistema" },
  { role_id: NumberInt(2), name: "Employee", description: "Empleado: opera el día a día" }
]);


db.department.insertMany([
  { department_id: NumberInt(1), name: "Facultad de Ingenierías", created_at: new Date("2026-01-10T08:00:00-05:00"), organization_id: NumberInt(1) },
  { department_id: NumberInt(2), name: "Facultad de Salud",       created_at: new Date("2026-01-10T08:00:00-05:00"), organization_id: NumberInt(1) }
]);


db.client.insertMany([
  {
    client_id: NumberInt(1),
    first_name: "Maria",
    middle_name: null,
    last_name: "Garcia",
    second_last_name: null,
    phone: "3001234567",
    active: true,
    registered_at: new Date("2026-01-10T08:00:00-05:00"),
    updated_at: new Date("2026-01-10T08:00:00-05:00"),
    department_id: NumberInt(1)
  },
  {
    client_id: NumberInt(2),
    first_name: "Juan",
    last_name: "Perez",
    phone: "3109876543",
    active: true,
    registered_at: new Date("2026-01-12T10:30:00-05:00"),
    department_id: NumberInt(2)
  }
]);


db.measurement.insertOne({
  measurement_id: NumberInt(1),
  back_width_ae: 36.5,
  bust_circumference_cb: 90,
  waist_circumference_cc: 72,
  hip_circumference_ck: 98,
  torso_length_lt: 40,
  pants_length_lp: 100,
  sleeve_length_lm: 58,
  sleeve_circumference_cm: 28,
  leg_circumference_cp: 54,
  notes: "Primera toma de medidas",
  taken_at: new Date("2026-01-10T09:00:00-05:00"),
  client_id: NumberInt(1)
});


db.garment_order.insertOne({
  garment_order_id: NumberInt(1),
  description: "Bata de laboratorio",
  total_price: 120000,
  amount_paid: 50000,
  balance_due: 70000,
  status: "Pending",
  payment_status: "Pending",
  created_at: new Date("2026-01-10T10:00:00-05:00"),
  delivery_date: new Date("2026-02-10T00:00:00-05:00"),
  notes: null,
  quantity: NumberInt(2),
  unit_price: 60000,
  embroidery: true,
  client_id: NumberInt(1),
  measurement_id: NumberInt(1)
});


db.payment.insertOne({
  payment_id: NumberInt(1),
  amount: 50000,
  note: "Abono inicial",
  paid_at: new Date("2026-01-10T10:05:00-05:00"),
  garment_order_id: NumberInt(1)
});


db.profile.insertOne({
  user_id: "3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b",
  full_name: "Jonathan Becerra",
  active: true,
  created_at: new Date("2026-01-10T08:00:00-05:00"),
  role_id: NumberInt(1)
});


db.audit_log.insertOne({
  audit_log_id: NumberInt(1),
  table_name: "garment_order",
  operation: "INSERT",
  record_id: "1",
  data_before: null,
  data_after: { garment_order_id: 1, description: "Bata de laboratorio", total_price: 120000 },
  logged_at: new Date("2026-01-10T10:00:00-05:00"),
  user_id: "3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b",
  db_user: "empleado_zconf"
});


--------------------------------------------------------PRUEBAS DE QUE LAS VALIDACIONES FUNCIONAN
--(cada una de estas inserciones debe FALLAR con "Document failed validation")

// abono en 0 (check_payment_amount)
db.payment.insertOne({ payment_id: NumberInt(99), amount: 0, garment_order_id: NumberInt(1) });

// teléfono con letras (check_phone_format)
db.client.insertOne({ client_id: NumberInt(99), first_name: "Ana", last_name: "Lopez", phone: "abc123" });

// nombre solo con espacios (check_first_name_not_empty)
db.client.insertOne({ client_id: NumberInt(98), first_name: "   ", last_name: "Lopez" });

// rol que no existe en el ENUM
db.role.insertOne({ role_id: NumberInt(3), name: "Supervisor" });

// abonado mayor al total (check_amount_paid_total)
db.garment_order.insertOne({
  garment_order_id: NumberInt(99), description: "Prueba", total_price: 1000, amount_paid: 5000,
  quantity: NumberInt(1), unit_price: 1000, client_id: NumberInt(1)
});

// cantidad en 0 (chk_garment_order_quantity_positive)
db.garment_order.insertOne({
  garment_order_id: NumberInt(98), description: "Prueba", total_price: 1000,
  quantity: NumberInt(0), unit_price: 1000, client_id: NumberInt(1)
});


--------------------------------------------------------CONSULTA DE DATOS CARGADOS

show collections


db.role.findOne();
db.organization.findOne();
db.department.findOne();
db.client.findOne();
db.measurement.findOne();
db.garment_order.findOne();
db.payment.findOne();
db.profile.findOne();
db.audit_log.findOne();

db.client.find();---todos los documentos

db.client.findOne({ client_id: 1 });


Ejemplos:

Primer ejemplo: Consultar los pedidos junto con los datos del cliente (equivale a un JOIN).
Como las llaves foráneas no se validan en MongoDB, la unión se hace con el operador $lookup.

Operador:

$lookup actúa como el INNER JOIN o LEFT JOIN de SQL para unir colecciones.


JavaScript(Herramienta Mongosh)


db.garment_order.aggregate([
  {
    $lookup: {
      from: "client",                // 1. Colección con la que me quiero unir
      localField: "client_id",       // 2. Campo en la colección 'garment_order'
      foreignField: "client_id",     // 3. Campo correspondiente en la colección 'client'
      as: "datos_cliente"            // 4. Nombre del arreglo donde se guarda el resultado
    }
  },
  {
    // Convierte el arreglo en un objeto directo y mantiene el pedido visible
    // aunque no encuentre cliente (LEFT JOIN)
    $unwind: {
      path: "$datos_cliente",
      preserveNullAndEmptyArrays: true
    }
  },
  {
    $sort: { "garment_order_id": 1 }
  }
]);


---------------------------------------Segundo Ejemplo: JOIN de varias colecciones
--(cliente -> dependencia -> organización)


db.client.aggregate([
  {
    $lookup: {
      from: "department",
      localField: "department_id",
      foreignField: "department_id",
      as: "departamento"
    }
  },
  {
    $unwind: { path: "$departamento", preserveNullAndEmptyArrays: true }
  },

  // ─── SEGUNDO JOIN: de la dependencia a la organización ───
  {
    $lookup: {
      from: "organization",
      localField: "departamento.organization_id",
      foreignField: "organization_id",
      as: "departamento.organizacion"
    }
  },
  {
    $unwind: { path: "$departamento.organizacion", preserveNullAndEmptyArrays: true }
  },
  {
    $project: {
      _id: 0,
      client_id: 1,
      first_name: 1,
      last_name: 1,
      "departamento.name": 1,
      "departamento.organizacion.name": 1
    }
  },
  {
    $sort: { "client_id": 1 }
  }
]);


************************************EJEMPLO TRES (Avanzada)
--Pedidos con cliente, abonos acumulados y alerta de entrega


db.garment_order.aggregate([
  // Etapa 1: Unir con client
  {
    $lookup: {
      from: "client",
      localField: "client_id",
      foreignField: "client_id",
      as: "datos_cliente"
    }
  },
  { $unwind: { path: "$datos_cliente", preserveNullAndEmptyArrays: true } },

  // Etapa 2: Unir con payment (un pedido puede tener varios abonos)
  {
    $lookup: {
      from: "payment",
      localField: "garment_order_id",
      foreignField: "garment_order_id",
      as: "abonos"
    }
  },

  // Etapa 3: Campos calculados ($addFields)
  {
    $addFields: {
      // 3.1 Total abonado sumando la colección payment
      "total_abonado": { $sum: "$abonos.amount" },

      // 3.2 Días que faltan para la entrega (negativo = ya pasó la fecha)
      "dias_para_entrega": {
        $dateDiff: {
          startDate: "$$NOW",
          endDate: "$delivery_date",
          unit: "day"
        }
      }
    }
  },
  {
    $addFields: {
      // 3.3 Saldo pendiente calculado en tiempo real
      "saldo_calculado": { $subtract: [ "$total_price", "$total_abonado" ] },

      // 3.4 Semáforo de entrega
      "alerta_entrega": {
        $switch: {
          branches: [
            { case: { $eq: [ "$status", "Delivered" ] },        then: "🟢 Entregado" },
            { case: { $eq: [ "$status", "Cancelled" ] },        then: "⚪ Cancelado" },
            { case: { $lt: [ "$dias_para_entrega", 0 ] },       then: "🔴 Vencido" },
            { case: { $lte: [ "$dias_para_entrega", 3 ] },      then: "🟡 Próximo a vencer" }
          ],
          default: "🟢 En tiempo"
        }
      }
    }
  },

  // Etapa 4: Proyección y limpieza final
  {
    $project: {
      _id: 0,
      garment_order_id: 1,
      description: 1,
      status: 1,
      total_price: 1,
      total_abonado: 1,
      saldo_calculado: 1,
      dias_para_entrega: 1,
      alerta_entrega: 1,
      "cliente": {
        $ifNull: [
          { $concat: [ "$datos_cliente.first_name", " ", "$datos_cliente.last_name" ] },
          "⚠️ Sin cliente"
        ]
      }
    }
  },

  // Etapa 5: Ordenamiento
  { $sort: { "dias_para_entrega": 1 } }
]);


¿Qué hace a esta consulta "Avanzada"?

Doble $lookup: une pedidos con clientes y con abonos (1 pedido -> N abonos)
y suma los abonos con $sum sin guardar ese dato de forma estática.

Manejo del tiempo dinámico ($$NOW): calcula cuántos días faltan para la entrega
cada vez que se ejecuta el reporte.

Lógica condicional ($switch): arma un semáforo de entrega directamente en la base de datos.

Seguridad de datos ($ifNull): reemplaza valores nulos por mensajes listos para el usuario final.
*/
