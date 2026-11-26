import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/services/media_upload_service.dart';

class StickerModel {
  final String id;
  final String url;
  final int? width;
  final int? height;

  const StickerModel({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  factory StickerModel.fromJson(Map<String, dynamic> json) => StickerModel(
    id: json['id'].toString(),
    url: json['url'].toString(),
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
  );
}

/// Colección de stickers de la persona (guardada en su cuenta).
///
/// Los de WhatsApp no se pueden leer directamente (Android los protege),
/// pero se importan eligiéndolos en la carpeta
/// Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers.
class StickerService {
  const StickerService._();

  static const String whatsAppFolder =
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers';

  /// Copia en memoria para abrir el selector al instante.
  static List<StickerModel>? _cache;

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) throw Exception('Tu sesión expiró.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static List<StickerModel>? get cached => _cache;

  static Future<List<StickerModel>> mine({bool refresh = false}) async {
    if (!refresh && _cache != null) return _cache!;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stickers'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar tus stickers.');
    }
    _cache = [
      for (final item in jsonDecode(response.body) as List)
        StickerModel.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    return _cache!;
  }

  /// Agrega a mi colección un sticker que ya está en Cloudinary (p. ej. uno
  /// que me enviaron en el chat).
  static Future<StickerModel> save({
    required String url,
    int? width,
    int? height,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/stickers'),
      headers: await _headers(),
      body: jsonEncode({
        'url': url,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      }),
    );
    if (response.statusCode != 201) {
      var message = 'No se pudo guardar el sticker.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['detail'] is String) message = data['detail'];
      } catch (_) {}
      throw Exception(message);
    }
    final sticker = StickerModel.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
    final list = _cache ?? [];
    _cache = [sticker, ...list.where((s) => s.id != sticker.id)];
    return sticker;
  }

  static Future<void> delete(StickerModel sticker) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/stickers/${sticker.id}'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) {
      throw Exception('No se pudo borrar el sticker.');
    }
    _cache?.removeWhere((s) => s.id == sticker.id);
  }

  static Future<StickerModel> _uploadAndSave(
    List<int> bytes,
    String fileName,
  ) async {
    final uploaded = await MediaUploadService.upload(
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      fileName: fileName,
      kind: MediaKind.image,
      purpose: MediaPurpose.sticker,
    );
    return save(
      url: uploaded.url,
      width: uploaded.width,
      height: uploaded.height,
    );
  }

  /// Elegir varios stickers del teléfono (los .webp de WhatsApp o imágenes).
  /// [onProgress] recibe (hechos, total). Devuelve cuántos se agregaron.
  static Future<int> importFromFiles({
    void Function(int done, int total)? onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['webp', 'png', 'gif', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return 0;

    final files = result.files.where((f) => f.bytes != null).take(30).toList();
    var added = 0;
    for (var i = 0; i < files.length; i++) {
      onProgress?.call(i, files.length);
      try {
        await _uploadAndSave(files[i].bytes!, files[i].name);
        added++;
      } catch (_) {
        // Si uno falla, se siguen los demás.
      }
    }
    onProgress?.call(files.length, files.length);
    return added;
  }

  /// Crear un sticker desde una foto de la galería.
  static Future<StickerModel?> createFromPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _uploadAndSave(await picked.readAsBytes(), picked.name);
  }
}
