import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/theme/brand.dart';

/// Avatar con foto (URL o base64) o, si no hay, iniciales sobre un color
/// de marca estable para cada nombre.
class UserAvatar extends StatelessWidget {
  final String name;
  final String photo;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    required this.photo,
    this.radius = 22,
  });

  static const _tints = [Brand.blue, Brand.green, Color(0xFF0EA5E9)];

  // Cache simple para no decodificar el mismo base64 en cada reconstrucción.
  static final Map<int, Uint8List?> _decoded = {};

  static Uint8List? _decode(String value) {
    return _decoded.putIfAbsent(value.hashCode, () {
      try {
        final clean = value.contains(',') ? value.split(',').last : value;
        return clean.trim().isEmpty ? null : base64Decode(clean.trim());
      } catch (_) {
        return null;
      }
    });
  }

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final value = photo.trim();

    ImageProvider? image;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      image = CachedNetworkImageProvider(
        CloudinaryUrl.isCloudinary(value)
            ? CloudinaryUrl.square(value, size: (radius * 4).round())
            : value,
      );
    } else if (value.isNotEmpty && value != 'null') {
      final bytes = _decode(value);
      if (bytes != null) image = MemoryImage(bytes);
    }

    if (image != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AuthPalette.of(context).fieldFill,
        backgroundImage: image,
        onBackgroundImageError: (_, __) {},
      );
    }

    final tint = _tints[name.hashCode.abs() % _tints.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: tint.withValues(alpha: 0.14),
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          color: tint,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.62,
        ),
      ),
    );
  }
}

/// "Ahora", "5 min", "3 h", "2 d", "4 sem", "3 meses"...
String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);

  if (diff.inSeconds < 60) return 'Ahora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} sem';
  if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    return months == 1 ? '1 mes' : '$months meses';
  }
  final years = (diff.inDays / 365).floor();
  return years == 1 ? '1 año' : '$years años';
}
