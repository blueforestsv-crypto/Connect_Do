import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/api_config.dart';

class PublicationApiService {
  Future<List<PublicationModel>> getPublications({
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (type != null && type.trim().isNotEmpty) {
      queryParams['type'] = type.trim();
    }

    final response = await http.get(
      ApiConfig.uri('/publications', queryParams),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar publicaciones: ${response.statusCode} ${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! List) {
      throw Exception('La respuesta del servidor no es una lista válida.');
    }

    return decodedBody
        .whereType<Map<String, dynamic>>()
        .map(PublicationModel.fromJson)
        .toList();
  }
}
