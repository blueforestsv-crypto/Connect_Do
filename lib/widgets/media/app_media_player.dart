import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class AppMediaPlayer extends StatefulWidget {
  final String filePath;
  final String? fileName;
  final String mediaType;
  final bool isDarkMode;

  const AppMediaPlayer({
    super.key,
    required this.filePath,
    this.fileName,
    required this.mediaType,
    required this.isDarkMode,
  });

  @override
  State<AppMediaPlayer> createState() => _AppMediaPlayerState();
}

class _AppMediaPlayerState extends State<AppMediaPlayer> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;

  bool _isVideoReady = false;
  bool _isAudioReady = false;
  bool _isPlayingAudio = false;

  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  bool get _isVideo => widget.mediaType == 'video';
  bool get _isAudio =>
      widget.mediaType == 'audio' || widget.mediaType == 'voice';
  bool get _isImage => widget.mediaType == 'image';
  bool get _isDocument => widget.mediaType == 'document';

  @override
  void initState() {
    super.initState();

    if (_isVideo) {
      _initVideo();
    }

    if (_isAudio) {
      _initAudio();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // ===============================
  // INICIAR VIDEO
  // ===============================
  Future<void> _initVideo() async {
    final file = File(widget.filePath);

    if (!file.existsSync()) return;

    final controller = VideoPlayerController.file(file);

    await controller.initialize();

    controller.setLooping(false);

    if (!mounted) return;

    setState(() {
      _videoController = controller;
      _isVideoReady = true;
    });

    controller.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  // ===============================
  // INICIAR AUDIO / NOTA DE VOZ
  // ===============================
  Future<void> _initAudio() async {
    final file = File(widget.filePath);

    if (!file.existsSync()) return;

    final player = AudioPlayer();

    await player.setFilePath(widget.filePath);

    player.durationStream.listen((duration) {
      if (!mounted) return;

      setState(() {
        _audioDuration = duration ?? Duration.zero;
      });
    });

    player.positionStream.listen((position) {
      if (!mounted) return;

      setState(() {
        _audioPosition = position;
      });
    });

    player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlayingAudio = state.playing;
      });

      if (state.processingState == ProcessingState.completed) {
        player.seek(Duration.zero);
        player.pause();
      }
    });

    if (!mounted) return;

    setState(() {
      _audioPlayer = player;
      _isAudioReady = true;
    });
  }

  // ===============================
  // PLAY / PAUSE VIDEO
  // ===============================
  void _toggleVideo() {
    final controller = _videoController;

    if (controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  // ===============================
  // PLAY / PAUSE AUDIO
  // ===============================
  Future<void> _toggleAudio() async {
    final player = _audioPlayer;

    if (player == null) return;

    if (_isPlayingAudio) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return _buildImagePreview();
    }

    if (_isVideo) {
      return _buildVideoPlayer();
    }

    if (_isAudio) {
      return _buildAudioPlayer();
    }

    if (_isDocument) {
      return _buildDocumentCard();
    }

    return _buildUnsupportedCard();
  }

  // ===============================
  // IMAGEN
  // ===============================
  Widget _buildImagePreview() {
    final file = File(widget.filePath);

    if (!file.existsSync()) {
      return _buildUnsupportedCard(message: 'No se encontró la imagen');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(file, width: double.infinity, fit: BoxFit.cover),
      ),
    );
  }

  // ===============================
  // VIDEO
  // ===============================
  Widget _buildVideoPlayer() {
    final bgColor =
        widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    if (!_isVideoReady || _videoController == null) {
      return _mediaContainer(
        child: const SizedBox(
          height: 170,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF22C55E)),
          ),
        ),
      );
    }

    final controller = _videoController!;
    final isPlaying = controller.value.isPlaying;

    final duration = controller.value.duration;
    final position = controller.value.position;

    final progress =
        duration.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / duration.inMilliseconds;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),

                    GestureDetector(
                      onTap: _toggleVideo,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),

                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor:
                          widget.isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF22C55E),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.fileName ?? 'Video adjunto',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: TextStyle(
                            color:
                                widget.isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================
  // AUDIO / VOZ
  // ===============================
  Widget _buildAudioPlayer() {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    if (!_isAudioReady || _audioPlayer == null) {
      return _mediaContainer(
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF22C55E)),
          ),
        ),
      );
    }

    final maxMilliseconds =
        _audioDuration.inMilliseconds == 0 ? 1 : _audioDuration.inMilliseconds;

    final currentMilliseconds = _audioPosition.inMilliseconds.clamp(
      0,
      maxMilliseconds,
    );

    return _mediaContainer(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InkWell(
              onTap: _toggleAudio,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlayingAudio
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName ?? 'Nota de voz',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: const Color(0xFF22C55E),
                      inactiveTrackColor:
                          widget.isDarkMode
                              ? Colors.white12
                              : Colors.grey.shade300,
                      thumbColor: const Color(0xFF22C55E),
                    ),
                    child: Slider(
                      value: currentMilliseconds.toDouble(),
                      min: 0,
                      max: maxMilliseconds.toDouble(),
                      onChanged: (value) {
                        _audioPlayer?.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_audioPosition),
                        style: TextStyle(
                          color:
                              widget.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _formatDuration(_audioDuration),
                        style: TextStyle(
                          color:
                              widget.isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // DOCUMENTO
  // ===============================
  Widget _buildDocumentCard() {
    return _mediaContainer(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A2563EB),
          child: Icon(Icons.insert_drive_file, color: Color(0xFF2563EB)),
        ),
        title: Text(
          widget.fileName ?? widget.filePath.split('/').last,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Documento adjunto',
          style: TextStyle(
            color:
                widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedCard({String message = 'Archivo no compatible'}) {
    return _mediaContainer(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1AFF0000),
          child: Icon(Icons.warning_amber_rounded, color: Colors.red),
        ),
        title: Text(
          message,
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _mediaContainer({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color:
              widget.isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: child,
      ),
    );
  }
}
