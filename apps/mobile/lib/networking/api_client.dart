import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'http://localhost:8000');
});
