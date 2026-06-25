class ApiConfig {
  static const String baseUrl = 'https://connect-do-api.onrender.com';

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}
