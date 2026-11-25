/// Configuración de conexión al backend FastAPI.
///
/// Por defecto apunta a `http://10.0.2.2:8000` (localhost desde emulador Android).
/// Se puede sobreescribir con `--dart-define=API_BASE_URL=http://TU_IP:8000`.
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
