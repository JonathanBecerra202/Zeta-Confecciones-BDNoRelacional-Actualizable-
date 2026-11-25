import 'dart:typed_data';

import '../core/api_client.dart';

/// Fotos de perfil almacenadas en el backend (`static/avatars`).
class AvatarService {
  final ApiClient _api;
  AvatarService(this._api);

  static const maxBytes = 2 * 1024 * 1024;

  static const _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const _extByMime = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
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

  /// Sube (o reemplaza) la foto y devuelve la ruta guardada en el perfil.
  Future<String> upload(String userId, Uint8List bytes, String contentType) async {
    if (bytes.length > maxBytes) {
      throw Exception('La imagen supera los 2 MB.');
    }
    final ext = _extByMime[contentType] ?? 'jpg';
    final res = await _api.uploadFile(
      '/users/$userId/avatar',
      bytes: bytes,
      contentType: contentType,
      filename: 'avatar.$ext',
    ) as Map<String, dynamic>;
    return res['avatar_path'] as String;
  }

  /// Borra el archivo y deja el perfil sin foto.
  Future<void> remove(String userId) async {
    await _api.delete('/users/$userId/avatar');
  }

  /// Resuelve rutas relativas `/static/avatars/...` a URLs completas del backend.
  Future<Map<String, String>> signedUrls(List<String> paths) async {
    if (paths.isEmpty) return const {};
    return {for (final p in paths) p: _api.resolveUrl(p)};
  }
}
