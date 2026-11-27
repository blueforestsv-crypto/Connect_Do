import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/theme/brand.dart';

class DocumentException implements Exception {
  final String message;
  const DocumentException(this.message);

  @override
  String toString() => message;
}

/// Descarga los documentos del chat al teléfono (una vez: abrirlos de nuevo
/// no gasta datos).
class DocumentCache {
  const DocumentCache._();

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static Future<File> fileFor(String url, String name) async {
    final base = await getTemporaryDirectory();
    final dir = Directory(
      '${base.path}/documentos/${url.hashCode.toUnsigned(32).toRadixString(16)}',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${_safeName(name.isEmpty ? 'documento' : name)}');
  }

  static Future<File> download(String url, String name) async {
    final file = await fileFor(url, name);
    if (await file.exists() && await file.length() > 0) return file;
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 2));
    } catch (_) {
      throw const DocumentException(
        'No se pudo descargar. Revisa tu conexión.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Cuentas gratis de Cloudinary: PDF y ZIP bloqueados por defecto.
      throw const DocumentException(
        'Cloudinary está bloqueando este archivo. En Cloudinary → Settings → '
        'Security activa "Allow delivery of PDF and ZIP files".',
      );
    }
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw DocumentException(
        'No se pudo descargar (error ${response.statusCode}).',
      );
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}

String _extension(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

/// Abre un documento del chat: PDF y texto dentro de la app; Word, Excel,
/// PowerPoint, ZIP… con la app instalada (o el visor de Google si no hay).
Future<void> openDocument(
  BuildContext context, {
  required String url,
  required String name,
}) async {
  final extension = _extension(name.isEmpty ? url : name);
  if (kIsWeb) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  if (extension == 'pdf' || extension == 'txt' || extension == 'csv') {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(url: url, name: name),
      ),
    );
    return;
  }

  // Otros formatos: se descargan y se abren con la app del teléfono.
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    const SnackBar(
      content: Text('Abriendo documento…'),
      duration: Duration(seconds: 2),
    ),
  );
  try {
    final file = await DocumentCache.download(url, name);
    final result = await OpenFilex.open(file.path);
    if (result.type == ResultType.done) return;
    // No hay app para ese formato: el visor de Google en el navegador.
    await launchUrl(
      Uri.parse(
        'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  } on DocumentException catch (error) {
    messenger?.showSnackBar(SnackBar(content: Text(error.message)));
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el documento.')),
    );
  }
}

/// Visor de PDF (páginas con zoom) y de texto, con botón de compartir.
class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final String name;

  const DocumentViewerScreen({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  File? _file;
  String? _error;
  PdfControllerPinch? _pdf;
  String? _text;

  bool get _isPdf =>
      _extension(widget.name.isEmpty ? widget.url : widget.name) == 'pdf';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await DocumentCache.download(widget.url, widget.name);
      if (!mounted) return;
      if (_isPdf) {
        _pdf = PdfControllerPinch(document: PdfDocument.openFile(file.path));
      } else {
        final bytes = await file.readAsBytes();
        _text = utf8.decode(bytes, allowMalformed: true);
      }
      setState(() => _file = file);
    } on DocumentException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo abrir el documento.');
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    await Share.shareXFiles([XFile(file.path)], subject: widget.name);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final pdf = _pdf;

    return Scaffold(
      backgroundColor: _isPdf ? const Color(0xFF525659) : palette.background,
      appBar: AppBar(
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (pdf != null)
            Center(
              child: PdfPageNumber(
                controller: pdf,
                builder:
                    (_, __, page, pages) => Text(
                      pages == null ? '' : '$page / $pages',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
              ),
            ),
          IconButton(
            tooltip: 'Guardar o compartir',
            onPressed: _file == null ? null : _share,
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
          ),
        ],
      ),
      body:
          _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      color: _isPdf ? Colors.white : palette.body,
                    ),
                  ),
                ),
              )
              : _file == null
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : pdf != null
              ? PdfViewPinch(controller: pdf)
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _text ?? '',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: palette.title,
                  ),
                ),
              ),
    );
  }
}
