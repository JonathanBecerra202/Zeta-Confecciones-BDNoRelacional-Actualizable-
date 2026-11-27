// Limpia todas las colecciones de la base de datos Z-Confecciones en mongosh.
// Es más seguro que db.dropDatabase() cuando el usuario de Atlas tiene rol readWrite.

const collections = [
  "audit_log",
  "payment",
  "garment_order",
  "measurement",
  "client",
  "department",
  "organization",
  "profile",
  "role",
  "counters",
];

collections.forEach((name) => {
  const dropped = db.getCollection(name).drop();
  print(`${name}: ${dropped ? "eliminada" : "no existía"}`);
});
