import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/utils/cloudinary_url.dart';

const _image =
    'https://res.cloudinary.com/connectdo/image/upload/v17/connect_do/post/u/a.jpg';
const _video =
    'https://res.cloudinary.com/connectdo/video/upload/v17/connect_do/post/u/b.mp4';

void main() {
  group('CloudinaryUrl', () {
    test('pide la imagen en tamaño de feed', () {
      expect(
        CloudinaryUrl.image(_image, width: 800),
        'https://res.cloudinary.com/connectdo/image/upload/'
        'c_limit,w_800,q_auto,f_auto/v17/connect_do/post/u/a.jpg',
      );
    });

    test('la portada de un video es su primer cuadro en jpg', () {
      final poster = CloudinaryUrl.videoPoster(_video);
      expect(poster, contains('/upload/so_0,'));
      expect(poster, endsWith('/b.jpg'));
    });

    test('no toca enlaces que no son de Cloudinary', () {
      const google = 'https://lh3.googleusercontent.com/foto';
      expect(CloudinaryUrl.image(google), google);
    });
  });

  group('photoProvider', () {
    test('enlace, base64 o vacío', () {
      expect(photoProvider(_image), isA<NetworkImage>());
      expect(photoProvider('aGVsbG8='), isA<MemoryImage>());
      expect(photoProvider(''), isNull);
      expect(photoProvider('null'), isNull);
    });
  });

  test('el modelo entiende fotos nuevas (url) y antiguas (base64)', () {
    final post = PublicationModel.fromJson({
      'id': 'p1',
      'author_id': 'a1',
      'type': 'general',
      'title': 'Hola',
      'description': 'Una publicación con fotos',
      'visibility': 'public',
      'created_at': DateTime.now().toIso8601String(),
      'author': {'first_name': 'Ana', 'last_name': 'López'},
      'media_items': [
        {'type': 'image', 'url': _image, 'width': 1200, 'height': 800},
        {'type': 'video', 'url': _video, 'duration': 12.4},
        {'type': 'image', 'base64': 'aGVsbG8='},
      ],
    });

    expect(post.mediaItems, hasLength(3));
    expect(post.mediaItems[0].aspectRatio, 1.5);
    expect(post.mediaItems[1].isVideo, isTrue);
    expect(post.mediaItems[1].duration, 12.4);
    expect(post.mediaItems[2].hasUrl, isFalse);
  });
}
