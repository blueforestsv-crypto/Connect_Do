class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}
