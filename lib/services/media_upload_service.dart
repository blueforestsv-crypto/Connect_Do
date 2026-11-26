import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

/// Para qué se sube el archivo (define la carpeta y qué tipos se aceptan).
enum MediaPurpose { post, avatar, chat, story, sticker }

enum MediaKind { image, video, audio }

/// Archivo ya subido a Cloudinary.
class UploadedMedia {
  final String url;
  final MediaKind kind;
  final int? width;
  final int? height;
  final double? duration;
  final int bytes;

  const UploadedMedia({
    required this.url,
    required this.kind,
    required this.bytes,
    this.width,
    this.height,
    this.duration,
  });

  String get type => kind.name;

  Map<String, dynamic> toJson() => {
    'type': type,
    'url': url,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (duration != null) 'duration': duration,
    'size_bytes': bytes,
  };
}

class MediaUploadException implements Exception {
  final String message;
  const MediaUploadException(this.message);

  @override
  String toString() => message;
}

/// Sube fotos, videos y audios directo a Cloudinary con una firma que da el
/// servidor. El archivo no pasa por Render: es más rápido y no gasta su
/// memoria.
class MediaUploadService {
  const MediaUploadService._();

  static Future<Map<String, dynamic>> _sign(
    MediaPurpose purpose,
    MediaKind kind,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) {
      throw const MediaUploadException('Tu sesión expiró.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/media/sign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'purpose': purpose.name, 'kind': kind.name}),
    );

    if (response.statusCode != 200) {
      var message = 'No se pudo preparar la subida.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['detail'] is String) message = data['detail'];
      } catch (_) {}
      throw MediaUploadException(message);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  /// Sube [bytes]. [onProgress] recibe de 0.0 a 1.0.
  static Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String fileName,
    required MediaKind kind,
    required MediaPurpose purpose,
    void Function(double progress)? onProgress,
  }) async {
    final signed = await _sign(purpose, kind);

    final maxBytes = (signed['max_bytes'] as num?)?.toInt() ?? 0;
    if (maxBytes > 0 && bytes.length > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).round();
      throw MediaUploadException('El archivo no puede pesar más de $mb MB.');
    }

    final request =
        _ProgressRequest(
            'POST',
            Uri.parse(signed['upload_url'] as String),
            onProgress: onProgress,
          )
          ..fields.addAll({
            'api_key': signed['api_key'].toString(),
            'timestamp': signed['timestamp'].toString(),
            'signature': signed['signature'].toString(),
            'folder': signed['folder'].toString(),
            'allowed_formats': signed['allowed_formats'].toString(),
          })
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(const Duration(minutes: 5)),
      );
    } on TimeoutException {
      throw const MediaUploadException('La subida tardó demasiado.');
    } catch (_) {
      throw const MediaUploadException(
        'No se pudo subir el archivo. Revisa tu conexión.',
      );
    }

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map) {
      final error = data is Map ? data['error'] : null;
      final detail = error is Map ? error['message']?.toString() ?? '' : '';
      throw MediaUploadException(
        detail.toLowerCase().contains('format')
            ? 'Ese formato de archivo no se permite.'
            : 'No se pudo subir el archivo.',
      );
    }

    onProgress?.call(1);
    return UploadedMedia(
      url: data['secure_url'].toString(),
      kind: kind,
      bytes: (data['bytes'] as num?)?.toInt() ?? bytes.length,
      width: (data['width'] as num?)?.toInt(),
      height: (data['height'] as num?)?.toInt(),
      duration: (data['duration'] as num?)?.toDouble(),
    );
  }
}

/// MultipartRequest que avisa cuánto se ha enviado.
class _ProgressRequest extends http.MultipartRequest {
  final void Function(double progress)? onProgress;

  _ProgressRequest(super.method, super.url, {this.onProgress});

  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final total = contentLength;
    if (onProgress == null || total <= 0) return stream;

    var sent = 0;
    return http.ByteStream(
      stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (chunk, sink) {
            sent += chunk.length;
            // Se deja 1.0 para cuando Cloudinary confirme.
            onProgress!((sent / total).clamp(0, 0.98));
            sink.add(chunk);
          },
        ),
      ),
    );
  }
}
