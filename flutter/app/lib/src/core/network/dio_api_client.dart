import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_request.dart';
import 'api_response.dart';

class DioApiClient implements ApiClient {
  DioApiClient(Uri baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl.toString(),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  final Dio _dio;

  @override
  Future<ApiResponse<T>> send<T>(
    ApiRequest request, {
    required T Function(Object? json) decode,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        request.path,
        data: request.body,
        queryParameters: request.query,
        options: Options(method: request.method.name.toUpperCase()),
      );

      return ApiSuccess<T>(decode(response.data));
    } on DioException catch (error) {
      return ApiFailure<T>(
        message: error.message ?? 'Network request failed',
        code: error.response?.statusCode?.toString(),
        cause: error,
      );
    } on Object catch (error) {
      return ApiFailure<T>(
        message: 'Unexpected response error',
        cause: error,
      );
    }
  }
}
