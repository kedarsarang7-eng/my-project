class ApiConfig {
  static const String baseUrl = 'https://api.example.com';
  static const String apiVersion = 'v1';
  
  static String get apiBaseUrl => '$baseUrl/$apiVersion';
}
