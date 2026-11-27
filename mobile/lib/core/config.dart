/// Configuración de conexión al backend FastAPI.
///
/// Por defecto apunta al backend desplegado en Render.
/// Para apuntar a un servidor local, pasa `--dart-define=API_BASE_URL=http://localhost:8000`.
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://zeta-confecciones-bdnorelacional.onrender.com',
  );
}
