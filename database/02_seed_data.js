const ahora = new Date();

// Fecha de entrega: hoy (hora Bogotá) + N días, a medianoche
function entrega(dias) {
  const d = new Date(Date.now() - 5 * 3600 * 1000);
  d.setUTCDate(d.getUTCDate() + dias);
  return new Date(d.toISOString().slice(0, 10) + "T00:00:00-05:00");
}

// ROLES
db.role.insertMany([
  { role_id: NumberInt(1), name: "Admin",    description: "Dueño/a del taller, control total del sistema" },
  { role_id: NumberInt(2), name: "Employee", description: "Opera el día a día: clientes, medidas, pedidos y abonos" }
]);

// ORGANIZACIONES (10)
const orgs = [
  "Universidad de Pamplona", "Universidad Industrial de Santander", "Colegio San José",
  "Colegio La Presentación", "Hospital San Rafael", "Alcaldía de Pamplona", "Clínica Norte",
  "Instituto Técnico Simón Bolívar", "Empresa Textiles del Norte", "Cooperativa Multiactiva COOTRASAN"
];
db.organization.insertMany(orgs.map((n, i) => ({
  organization_id: NumberInt(i + 1), name: n, created_at: ahora
})));

// DEPENDENCIAS (10): [nombre, organization_id]
const deps = [
  ["Recursos Humanos", 1], ["Facultad de Ingenierías", 1], ["Secretaría Académica", 2],
  ["Coordinación", 3], ["Primaria", 4], ["Enfermería", 5], ["Urgencias", 5],
  ["Despacho", 6], ["Administración", 7], ["Producción", 9]
];
db.department.insertMany(deps.map((d, i) => ({
  department_id: NumberInt(i + 1), name: d[0], created_at: ahora, organization_id: NumberInt(d[1])
})));

// CLIENTES (10): [nombre, apellido, teléfono]  (department_id = mismo número que client_id)
const clientes = [
  ["María Fernanda", "Ortiz", "3001112233"], ["Carlos Andrés", "Rueda", "3002223344"],
  ["Laura Sofía", "Delgado", "3003334455"],  ["Julián David", "Contreras", "3004445566"],
  ["Ana María", "Villamizar", "3005556677"], ["Pedro Antonio", "Gómez", "3006667788"],
  ["Diana Carolina", "Pabón", "3007778899"], ["Jorge Enrique", "Mendoza", "3008889900"],
  ["Natalia Andrea", "Serrano", "3009990011"], ["Luis Felipe", "Cáceres", "3010001122"]
];
db.client.insertMany(clientes.map((c, i) => ({
  client_id: NumberInt(i + 1), first_name: c[0], last_name: c[1], phone: c[2],
  active: true, registered_at: ahora, updated_at: ahora, department_id: NumberInt(i + 1)
})));

// MEDIDAS (10, una por cliente): [ae, cb, cc, ck, lt, lp, lm, cm, cp]
const medidas = [
  [37, 94, 76, 100, 40, 98, 58, 30, 60], [42, 100, 88, 98, 45, 102, 62, 34, 58],
  [36, 90, 72, 96, 38, 96, 56, 28, 56],  [44, 104, 92, 102, 47, 104, 64, 36, 62],
  [35, 88, 70, 94, 37, 94, 55, 27, 54],  [41, 98, 84, 99, 44, 100, 61, 33, 59],
  [38, 96, 78, 101, 41, 99, 59, 31, 61], [43, 102, 90, 100, 46, 103, 63, 35, 60],
  [39, 92, 74, 97, 39, 97, 57, 29, 57],  [45, 106, 94, 104, 48, 105, 65, 37, 63]
];
db.measurement.insertMany(medidas.map((m, i) => ({
  measurement_id: NumberInt(i + 1),
  back_width_ae: m[0], bust_circumference_cb: m[1], waist_circumference_cc: m[2],
  hip_circumference_ck: m[3], torso_length_lt: m[4], pants_length_lp: m[5],
  sleeve_length_lm: m[6], sleeve_circumference_cm: m[7], leg_circumference_cp: m[8],
  taken_at: ahora, client_id: NumberInt(i + 1)
})));

// PEDIDOS (10) y ABONOS (10, uno por pedido)
// [descripción, cantidad, precio unitario, días de entrega, bordado, abono]
const pedidos = [
  ["2 batas institucionales bordadas", 2, 45000, 0,  true,  40000],
  ["3 camisas manga larga",            3, 30000, 5,  false, 90000],
  ["Traje ejecutivo completo",         1, 150000, 17, true,  50000],
  ["4 pantalones de gabardina",        4, 25000, 10, false, 100000],
  ["2 chaquetas con logo",             2, 60000, 21, false, 60000],
  ["5 uniformes de práctica",          5, 20000, 3,  true,  100000],
  ["Bata quirúrgica premium",          1, 200000, 26, false, 100000],
  ["2 trajes formales",                2, 55000, 15, false, 110000],
  ["3 blusas ejecutivas",              3, 40000, 24, true,  40000],
  ["Uniforme industrial completo",     1, 180000, 7,  false, 180000]
];
const notas = [
  "Adelanto inicial", "Pago completo", "Primera cuota", "Pago completo", "Adelanto",
  "Pago completo", "Primera cuota", "Pago completo", "Adelanto", "Pago completo"
];

db.garment_order.insertMany(pedidos.map((p, i) => {
  const total = p[1] * p[2];          // lo que calculaba el trigger de total_price
  const saldo = total - p[5];         // balance_due
  return {
    garment_order_id: NumberInt(i + 1),
    description: p[0],
    total_price: total,
    amount_paid: p[5],
    balance_due: saldo,
    status: "Pending",
    payment_status: saldo === 0 ? "Paid" : "Pending",
    created_at: ahora,
    delivery_date: entrega(p[3]),
    quantity: NumberInt(p[1]),
    unit_price: p[2],
    embroidery: p[4],
    client_id: NumberInt(i + 1),
    measurement_id: NumberInt(i + 1)
  };
}));

db.payment.insertMany(pedidos.map((p, i) => ({
  payment_id: NumberInt(i + 1),
  amount: p[5],
  note: notas[i],
  paid_at: ahora,
  garment_order_id: NumberInt(i + 1)
})));