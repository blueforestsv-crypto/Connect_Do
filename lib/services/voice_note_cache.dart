import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:connect_do/utils/cloudinary_url.dart';

/// Descarga las notas de voz al teléfono antes de reproducirlas (como
/// WhatsApp). Reproducir desde un archivo local evita los problemas del
/// reproductor con el audio por internet y, como queda guardada, volver a
/// escucharla no gasta datos.
class VoiceNoteCache {
  const VoiceNoteCache._();

  static Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/notas_de_voz');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Versiones a probar, en orden: MP3 (la que suena en cualquier teléfono
  /// y pesa menos) y el archivo original.
  static List<String> candidates(String url) {
    final mp3 = CloudinaryUrl.audio(url);
    return mp3 == url ? [url] : [mp3, url];
  }

  static String _extension(String url) {
    final match = RegExp(r'\.(\w{2,4})(?:\?.*)?$').firstMatch(url);
    return match?.group(1) ?? 'mp3';
  }

  /// Ruta local del archivo de [url], descargándolo si hace falta.
  static Future<String> localFile(String url) async {
    final dir = await _dir();
    final name =
        'nota_${url.hashCode.toUnsigned(32).toRadixString(16)}.'
        '${_extension(url)}';
    final file = File('${dir.path}/$name');

    if (await file.exists() && await file.length() > 0) return file.path;

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }
}
