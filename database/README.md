# Reconstrucción de la base de datos (`Z-Confecciones`)

Guía para limpiar la base de datos en MongoDB Atlas y volver a crear las colecciones, validaciones, índices y datos iniciales desde cero.

## Archivos en esta carpeta

1. [`00_reset_database.js`](./00_reset_database.js): elimina todas las colecciones existentes (`drop()`).
2. [`01_schema_and_indexes.js`](./01_schema_and_indexes.js): crea las 9 colecciones con sus validaciones `$jsonSchema` (`validationLevel: "strict"`) y sus índices únicos.
3. [`02_seed_data.js`](./02_seed_data.js): inserta los datos iniciales (`role`, `organization`, `department`, `client`, `measurement`, `garment_order`, `payment` y usuarios iniciales en `profile`).
4. [`03_queries_and_validation_tests.js`](./03_queries_and_validation_tests.js): archivo de referencia con ejemplos de `collMod`, pruebas de validación que deben fallar y consultas de agregación con `$lookup`.

---

## Orden de ejecución (en `mongosh`)

Conéctate a tu clúster de MongoDB Atlas y selecciona la base de datos:

```javascript
use Z-Confecciones
```

### Paso 1: Limpiar las colecciones actuales
Ejecuta el contenido de `00_reset_database.js` (o cárgalo desde `mongosh`):

```javascript
load("database/00_reset_database.js")
```

### Paso 2: Crear colecciones, validaciones e índices
Ejecuta `01_schema_and_indexes.js`:

```javascript
load("database/01_schema_and_indexes.js")
```

### Paso 3: Insertar datos iniciales
Ejecuta `02_seed_data.js`:

```javascript
load("database/02_seed_data.js")
```

### Paso 4: Recrear contadores
1. Reinicia el servicio del backend (en Render con **Manual Deploy** o en local con `uvicorn`): al arrancar, `ensure_profile_schema_and_indexes` crea automáticamente la colección `counters` sincronizada con los IDs existentes (`1..10`) y el índice único parcial de `profile.email`.
2. Los usuarios iniciales ya quedan sembrados automáticamente por `02_seed_data.js`:
   - **Admin:** `admin@zetaconfecciones.com` / `Admin1234!`
   - **Empleado:** `empleado@zetaconfecciones.com` / `Empleado1234!`
   *(Opcional: si necesitas crear otro Admin distinto, puedes usar `.\venv\Scripts\python.exe seed_admin.py --email ... --password ...`).*
