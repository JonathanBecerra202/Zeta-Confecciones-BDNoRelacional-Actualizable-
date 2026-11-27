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
