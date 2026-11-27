# Zeta Confecciones — App Móvil + API FastAPI + MongoDB Atlas

Sistema de gestión para taller de confecciones (clientes, medidas, pedidos, abonos, auditoría y administración de usuarios), migrado de Supabase a **MongoDB Atlas** mediante una API REST en **FastAPI + PyMongo** y una app móvil en **Flutter (Riverpod)**.

---

## Arquitectura actual

```text
[App Flutter (mobile/)]  ──HTTPS/JWT──▶  [API FastAPI (Render)]  ──PyMongo──▶  [MongoDB Atlas (Z-Confecciones)]
```

- **Base de datos:** Clúster en **MongoDB Atlas** (`Z-Confecciones`).
- **Backend (`backend/`):** Desplegado en **Render** (`https://zeta-confecciones-bdnorelacional.onrender.com`).
  - Salud: `https://zeta-confecciones-bdnorelacional.onrender.com/health`
  - Documentación (Swagger): `https://zeta-confecciones-bdnorelacional.onrender.com/docs`
- **App móvil (`mobile/`):** Configurada por defecto en `mobile/lib/core/config.dart` para conectarse a Render.

---

## 1. Ejecutar la App Móvil (`mobile/`)

Con el backend ya desplegado en Render, no necesitas levantar Python localmente ni usar `adb reverse`.

```powershell
cd mobile
flutter pub get
flutter run
```

Para generar el APK instalable:

```powershell
cd mobile
flutter build apk
```

### Credenciales iniciales (Admin)
- **Correo:** `admin@zetaconfecciones.com`
- **Contraseña:** `Admin1234!`

> **Nota (plan gratuito de Render):** si el servidor pasa ~15 minutos sin tráfico, entra en suspensión y la primera petición puede tardar entre 30 y 50 segundos en responder. Además, las fotos guardadas en `static/avatars` se borran si el servicio se reinicia o se redespliega.

---

## 2. Correr el Backend en local (opcional, para desarrollo)

Si necesitas probar cambios del backend en tu PC antes de subirlos a GitHub/Render:

```powershell
cd backend
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Edita `backend/.env` con tu `MONGODB_URI` de Atlas y un `JWT_SECRET` (32+ caracteres), y levanta `uvicorn`:

```powershell
.\venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload
```

Luego apunta Flutter a tu servidor local usando `--dart-define`:

- **Windows / Chrome:** `flutter run --dart-define=API_BASE_URL=http://localhost:8000`
- **Emulador Android:** `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
- **Teléfono Android por USB:**
  ```powershell
  $env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
  adb reverse tcp:8000 tcp:8000
  flutter run --dart-define=API_BASE_URL=http://localhost:8000
  ```

---

## 3. Reconstruir la base de datos desde cero (opcional)

Si en algún momento necesitas reiniciar MongoDB Atlas:

1. Limpia las colecciones existentes en `mongosh`.
2. Ejecuta `database/01_schema_and_indexes.js` en `mongosh` (`load("database/01_schema_and_indexes.js")`).
3. Ejecuta `database/02_seed_data.js` para cargar los datos iniciales (`role`, `organization`, `department`, `client`, `measurement`, `garment_order`, `payment`).
4. Al iniciar el backend, se recrean automáticamente `counters` y el índice único de `profile.email`; luego ejecuta `.\venv\Scripts\python.exe seed_admin.py` para crear de nuevo el Admin inicial.
