import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Fotos de perfil en el bucket PRIVADO `avatars`.
///
/// - Cada usuario tiene un único archivo fijo: `{user_id}/avatar`. Cambiar la
///   foto lo sobrescribe, así que nunca quedan archivos duplicados ni huérfanos.
/// - En `z_conf.profile` solo se guarda la ruta (`avatar_path`), no la imagen.
/// - Para mostrarla se piden URLs firmadas que caducan.
/// - Los permisos reales (solo administradores suben, cambian o borran) los
///   aplican las políticas de Storage y un trigger en la base de datos.
class AvatarService {
  final SupabaseClient _db;
  AvatarService(this._db);

  static const bucket = 'avatars';
  static const maxBytes = 2 * 1024 * 1024; // igual que el límite del bucket
  static const _urlLifetime = 3600; // segundos

  static const _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// Tipo de imagen admitido a partir del mime o del nombre del archivo;
  /// null si no es JPG, PNG o WebP.
  static String? contentTypeFor({String? mime, required String fileName}) {
    final m = mime?.toLowerCase();
    if (m != null && _mimeByExtension.containsValue(m)) return m;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return _mimeByExtension[fileName.substring(dot + 1).toLowerCase()];
  }

  static String pathFor(String userId) => '$userId/avatar';

  /// Sube (o reemplaza) la foto y guarda la ruta en el perfil.
  Future<String> upload(String userId, Uint8List bytes, String contentType) async {
    if (bytes.length > maxBytes) {
      throw Exception('La imagen supera los 2 MB.');
    }
    final path = pathFor(userId);
    await _db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _db.from('profile').update({'avatar_path': path}).eq('user_id', userId);
    return path;
  }

  /// Borra el archivo y deja el perfil sin foto.
  Future<void> remove(String userId) async {
    await _db.storage.from(bucket).remove([pathFor(userId)]);
    await _db.from('profile').update({'avatar_path': null}).eq('user_id', userId);
  }

  /// URLs firmadas (ruta -> url) en una sola llamada. Las rutas que no se
  /// puedan firmar (archivo ausente o sin permiso) se omiten sin fallar.
  Future<Map<String, String>> signedUrls(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final res = await _db.storage.from(bucket).createSignedUrls(paths, _urlLifetime);
    return {
      for (final r in res)
        if (r.signedUrl.isNotEmpty) r.path: r.signedUrl,
    };
  }
}