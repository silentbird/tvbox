import 'api_request.dart';
import 'api_response.dart';

abstract interface class ApiClient {
  Future<ApiResponse<T>> send<T>(
    ApiRequest request, {
    required T Function(Object? json) decode,
  });
}
