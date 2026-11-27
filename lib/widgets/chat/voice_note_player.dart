import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/error_reporter.dart';
import 'package:connect_do/services/voice_note_cache.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/media/media_gallery.dart';

/// Nota de voz dentro de una burbuja del chat.
///
/// Usa el reproductor nativo del teléfono (MediaPlayer en Android) y no
/// ExoPlayer: la app trae otra versión de ExoPlayer para los videos y,
/// mezcladas, las notas fallaban con "código 2" (error interno).
class VoiceNotePlayer extends StatefulWidget {
  final String url;
  final double? duration;

  /// Burbuja azul (mis mensajes) o clara (los del otro).
  final bool onDark;

  const VoiceNotePlayer({
    super.key,
    required this.url,
    this.duration,
    this.onDark = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  // Solo suena una nota a la vez en toda la app.
  static _VoiceNotePlayerState? _playing;

  AudioPlayer? _player;
  final List<StreamSubscription> _subs = [];
  Duration _position = Duration.zero;
  Duration? _total;
  bool _loading = false;
  bool _isPlaying = false;
  bool _failed = false;

  @override
  void dispose() {
    _release();
    if (_playing == this) _playing = null;
    super.dispose();
  }

  void _release() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
  }

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;
    final player = AudioPlayer();
    _player = player;
    _subs
      ..add(
        player.onPositionChanged.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      )
      ..add(
        player.onDurationChanged.listen((d) {
          if (mounted && d > Duration.zero) setState(() => _total = d);
        }),
      )
      ..add(
        player.onPlayerStateChanged.listen((state) {
          if (mounted) {
            setState(() => _isPlaying = state == PlayerState.playing);
          }
        }),
      )
      ..add(
        player.onPlayerComplete.listen((_) {
          if (!mounted) return;
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }),
      );
    await _load(player);
    return player;
  }

  /// Se descarga la nota y se reproduce desde el teléfono. Primero el MP3;
  /// si ese no abre, el archivo original.
  Future<void> _load(AudioPlayer player) async {
    if (kIsWeb) {
      await player.setSource(UrlSource(CloudinaryUrl.audio(widget.url)));
      return;
    }
    Object? lastError;
    for (final url in VoiceNoteCache.candidates(widget.url)) {
      try {
        final path = await VoiceNoteCache.localFile(url);
        await player.setSource(DeviceFileSource(path));
        return;
      } catch (error) {
        debugPrint('Nota de voz: no abrió $url → $error');
        lastError = error;
      }
    }
    throw lastError ?? Exception('Sin audio');
  }

  /// Texto corto del error, para poder diagnosticarlo si vuelve a pasar.
  static String _errorDetail(Object error) {
    if (error is HttpException) return error.message;
    if (error is TimeoutException) return 'sin conexión';
    final text = error.toString();
    return text.length > 60 ? text.substring(0, 60) : text;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_isPlaying) {
        await _player?.pause();
        return;
      }
      setState(() => _loading = true);
      final player = await _ensurePlayer();
      if (_playing != null && _playing != this) {
        await _playing!._player?.pause();
      }
      _playing = this;
      if (mounted) setState(() => _loading = false);
      await player.resume();
    } catch (error, stack) {
      debugPrint('No se pudo reproducir la nota de voz: $error');
      // Llega a "Errores de la app" para saber qué pasó en ese teléfono.
      ErrorReporter.report('Nota de voz (${widget.url}): $error', stack);
      // Se descarta el reproductor para poder reintentar con otro toque.
      _release();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo reproducir la nota de voz (${_errorDetail(error)}).',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final fg = widget.onDark ? Colors.white : Brand.blue;
    final track =
        widget.onDark
            ? Colors.white.withValues(alpha: 0.3)
            : palette.fieldBorder;

    final total =
        _total ??
        Duration(milliseconds: ((widget.duration ?? 0) * 1000).round());
    final progress =
        total.inMilliseconds == 0
            ? 0.0
            : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final shown = _isPlaying || _position > Duration.zero ? _position : total;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_failed) setState(() => _failed = false);
              _toggle();
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    widget.onDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Brand.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  _loading
                      ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                      : Icon(
                        _failed
                            ? PhosphorIconsRegular.warningCircle
                            : _isPlaying
                            ? PhosphorIconsFill.pause
                            : PhosphorIconsFill.play,
                        size: 18,
                        color: fg,
                      ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: fg,
                inactiveTrackColor: track,
                thumbColor: fg,
              ),
              child: Slider(
                value: progress,
                onChanged:
                    _player == null || total == Duration.zero
                        ? null
                        : (value) => _player!.seek(total * value),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatDuration(shown.inMilliseconds / 1000),
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.onDark ? Colors.white : palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
