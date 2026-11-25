import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/media/media_gallery.dart';

/// Nota de voz dentro de una burbuja del chat.
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
    for (final sub in _subs) {
      sub.cancel();
    }
    _player?.dispose();
    if (_playing == this) _playing = null;
    super.dispose();
  }

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;
    final player = AudioPlayer();
    _player = player;
    _subs
      ..add(
        player.positionStream.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      )
      ..add(
        player.playerStateStream.listen((state) {
          if (!mounted) return;
          if (state.processingState == ProcessingState.completed) {
            player.pause();
            player.seek(Duration.zero);
          }
          setState(() => _isPlaying = player.playing);
        }),
      );
    final total = await player.setUrl(widget.url);
    if (mounted) setState(() => _total = total);
    return player;
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
      await player.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
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
            onTap: _failed ? null : _toggle,
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
