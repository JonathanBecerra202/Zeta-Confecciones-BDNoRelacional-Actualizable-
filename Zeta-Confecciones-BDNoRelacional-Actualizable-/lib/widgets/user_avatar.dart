import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'common.dart';

/// Foto de perfil circular. Si no hay foto (o no carga) muestra las iniciales,
/// con el mismo estilo de [ZAvatar]. Se usa en la lista de usuarios, en el
/// detalle y en «Más», para que siempre se vea la misma imagen.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? url;

  /// Vista previa local (p. ej. foto elegida y aún no subida).
  final Uint8List? bytes;
  final double size;
  const UserAvatar({super.key, required this.name, this.url, this.bytes, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final fallback = ZAvatar(name.isEmpty ? '?' : name, size: size);
    Widget? image;
    if (bytes != null) {
      image = Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover);
    } else if (url != null) {
      image = Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      );
    }
    if (image == null) return fallback;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40368FC5), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: ClipOval(child: image),
    );
  }
}