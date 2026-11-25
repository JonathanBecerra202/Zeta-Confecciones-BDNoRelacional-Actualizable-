# Zeta Confecciones — App Móvil + API FastAPI + MongoDB Atlas

Sistema de gestión para taller de confecciones (clientes, medidas, pedidos, abonos, auditoría y administración de usuarios), migrado de Supabase a **MongoDB Atlas** mediante una API REST en **FastAPI + PyMongo** y una app móvil en **Flutter (Riverpod)**.

---

## Arquitectura actual

```text
[App Flutter (mobile/)]  ──HTTP/JWT──▶  [API FastAPI (backend/ local :8000)]  ──PyMongo──▶  [MongoDB Atlas (Z-Confecciones)]
```

- **Base de datos:** Clúster en **MongoDB Atlas** (`Z-Confecciones`).
- **Backend (`backend/`):** Corre **localmente** en el PC (`http://0.0.0.0:8000`) y se conecta a MongoDB Atlas.
- **App móvil (`mobile/`):** Corre en teléfono Android físico, emulador o escritorio, y consume la API local.

---

## Requisitos previos

- **Python 3.11+** (probado con Python 3.14)
- **Flutter SDK**
- **Android SDK / `adb`** (si vas a probar en teléfono Android físico)
- **Cadena de conexión de MongoDB Atlas** (`MONGODB_URI`)

---

## 1. Levantar el Backend (`backend/`)

Abre una terminal en la raíz del proyecto:

```powershell
cd backend
```

### 1.1 Crear entorno virtual e instalar dependencias (solo la primera vez)

```powershell
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
```

### 1.2 Configurar variables de entorno (`.env`)

Copia el archivo de ejemplo y edita `backend/.env` con tu URI real de MongoDB Atlas y un `JWT_SECRET` de al menos 32 caracteres:

```powershell
Copy-Item .env.example .env
```

Ejemplo de `backend/.env`:

```env
MONGODB_URI=mongodb+srv://<usuario>:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority
MONGODB_DB_NAME=Z-Confecciones
JWT_SECRET=cambia-esta-clave-por-una-secreta-de-32-caracteres-o-mas
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=720
AVATARS_DIR=static/avatars
MAX_AVATAR_BYTES=2097152
CORS_ORIGINS=*
```

### 1.3 (Solo si la BD está nueva) Crear usuario Admin inicial

Si la colección `profile` está vacía, ejecuta:

```powershell
.\venv\Scripts\python.exe seed_admin.py
```

Credenciales por defecto que crea el script:
- **Correo:** `admin@zetaconfecciones.com`
- **Contraseña:** `Admin1234!`

### 1.4 Iniciar el servidor FastAPI

```powershell
.\venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload
```

- Salud de la API: `http://localhost:8000/health`
- Documentación interactiva (Swagger): `http://localhost:8000/docs`

> **Nota:** Deja esta terminal abierta mientras usas la app móvil.

---

## 2. Ejecutar la App Móvil (`mobile/`)

Abre una **segunda terminal** en la carpeta `mobile/`:

```powershell
cd mobile
flutter pub get
```

Elige cómo la vas a ejecutar:

### Opción A: Teléfono Android físico por USB (recomendada)

1. Activa **Depuración USB** en el teléfono y conéctalo en modo **Transferencia de archivos (MTP)**.
2. Si `adb` no está en tu `PATH` de Windows, agrégalo temporalmente en esa terminal:

   ```powershell
   $env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
   ```

3. Verifica que el teléfono aparezca y reenvía el puerto `8000` del teléfono hacia tu PC:

   ```powershell
   adb devices
   adb reverse tcp:8000 tcp:8000
   ```

4. Lanza la app apuntando a `localhost:8000`:

   ```powershell
   flutter run --dart-define=API_BASE_URL=http://localhost:8000
   ```

> **Importante:** Si desconectas y vuelves a conectar el cable USB, ejecuta de nuevo `adb reverse tcp:8000 tcp:8000`.

### Opción B: Teléfono Android físico por Wi-Fi (misma red)

1. Consulta la IP local de tu PC con `ipconfig` (por ejemplo `192.168.1.15`).
2. Asegúrate de que el Firewall de Windows permita el puerto `8000`.
3. Lanza la app:

   ```powershell
   flutter run --dart-define=API_BASE_URL=http://192.168.1.15:8000
   ```

### Opción C: Emulador Android

Por defecto `Env.apiBaseUrl` apunta a `http://10.0.2.2:8000` (el `localhost` del PC desde el emulador):

```powershell
flutter run
```

### Opción D: Windows / Chrome

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

---

## 3. Reconstruir la base de datos desde cero (opcional)

Si en algún momento necesitas reiniciar MongoDB Atlas:

1. Limpia las colecciones existentes en `mongosh`.
2. Ejecuta los bloques de `db.createCollection(...)` y `createIndex(...)` de `database/01_schema_and_indexes.txt`.
3. Ejecuta `database/02_seed_data.js` para cargar los datos iniciales (`role`, `organization`, `department`, `client`, `measurement`, `garment_order`, `payment`).
4. Inicia el backend (recrea automáticamente la colección `counters` y el índice único de `profile.email`) y vuelve a correr `.\venv\Scripts\python.exe seed_admin.py`.

---

## Solución rápida de problemas

- **`adb` no se reconoce como comando:** ejecuta `$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"` en esa terminal.
- **`Sin conexión con el servidor` al iniciar sesión en el teléfono:**
  1. Verifica que `uvicorn` esté corriendo en el puerto `8000`.
  2. Ejecuta `adb reverse tcp:8000 tcp:8000` y confirma con `adb reverse --list`.
  3. Verifica que lanzaste Flutter con `--dart-define=API_BASE_URL=http://localhost:8000`.
- **`device '...' not found` en `adb`:** reconecta el cable USB, desbloquea la pantalla, confirma modo MTP y ejecuta `adb kill-server` seguido de `adb start-server`.
