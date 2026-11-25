/// Conexión a Supabase.
///
/// Por defecto usa el proyecto Z_Confecciones_Mobile, así la app conecta
/// aunque no se pase `--dart-define-from-file=env.json` (por ejemplo al
/// darle "Run" desde Android Studio). Si se pasan las variables, esas mandan.
///
/// La clave `sb_publishable_...` es pública: la seguridad la da el RLS.
/// NUNCA pongas aquí la `service_role` / `sb_secret_...`.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pbdvcxkqxdiauxqhlzbz.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2oXiQmv5h0ZBIcJdnojHaA_RTbF20Cn',
  );
}
