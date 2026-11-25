<<<<<<< HEAD
# Zeta Confecciones — App móvil (Flutter)

Port a Flutter de la web Angular, con la interfaz del mockup móvil.
Backend: Supabase (proyecto Z_Confecciones_Mobile, schema `z_conf`).

## Ejecutar
```
flutter pub get
flutter run
```
La conexión a Supabase ya viene configurada en `lib/core/config.dart`
(si quieres otra, pasa `--dart-define-from-file=env.json`).

## Requisito en Supabase
Project Settings → Data API → **Exposed schemas** debe incluir `z_conf`.

## Estructura
```
lib/main.dart            inicia Supabase (schema z_conf)
lib/app.dart             login -> perfil/rol -> app
lib/pages/               pantallas: auth, shell, dashboard, orders, clients, more
lib/widgets/             componentes compartidos
lib/models/              modelos
lib/repositories/        consultas a Supabase
lib/bloc/                estado (Riverpod)
lib/core/                tema, formato, config
```
=======
# Zeta-Confecciones-BDNoRelacional
>>>>>>> 35c921dcc544614c1d0e5994e47ef49f5acb65be
