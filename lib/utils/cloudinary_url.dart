import 'dart:convert';

import 'package:flutter/painting.dart';

/// Ayudas para pedirle a Cloudinary cada archivo en el tamaño justo.
/// Ej.: en el feed se pide una imagen de 900 px y calidad automática, en vez
/// del original de varios MB.
class CloudinaryUrl {
  const CloudinaryUrl._();

  static bool isCloudinary(String url) =>
      url.contains('res.cloudinary.com/') && url.contains('/upload/');

  /// Inserta una transformación después de "/upload/".
  static String transform(String url, String transformation) {
    if (!isCloudinary(url)) return url;
    return url.replaceFirst('/upload/', '/upload/$transformation/');
  }

  /// Imagen ajustada a [width] px, formato y calidad automáticos.
  static String image(String url, {int width = 900}) =>
      transform(url, 'c_limit,w_$width,q_auto,f_auto');

  /// Miniatura cuadrada (avatares).
  static String square(String url, {int size = 200}) =>
      transform(url, 'c_fill,g_face,w_$size,h_$size,q_auto,f_auto');

  /// Video comprimido para el teléfono.
  static String video(String url) => transform(url, 'q_auto,w_1080,c_limit');

  /// Primer cuadro de un video como imagen (portada).
  static String videoPoster(String url, {int width = 900}) {
    if (!isCloudinary(url)) return url;
    final withFrame = transform(url, 'so_0,c_limit,w_$width,q_auto');
    return withFrame.replaceFirst(RegExp(r'\.\w+$'), '.jpg');
  }
}

/// Foto de perfil o imagen que puede venir como enlace (Cloudinary/Google)
/// o como base64 (cuentas antiguas).
ImageProvider? photoProvider(String? value, {int size = 200}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || text == 'null') return null;

  if (text.startsWith('http://') || text.startsWith('https://')) {
    return NetworkImage(
      CloudinaryUrl.isCloudinary(text)
          ? CloudinaryUrl.square(text, size: size)
          : text,
    );
  }

  try {
    final clean = text.contains(',') ? text.split(',').last : text;
    return MemoryImage(base64Decode(clean));
  } catch (_) {
    return null;
  }
}
