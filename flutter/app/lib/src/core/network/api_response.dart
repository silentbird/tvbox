sealed class ApiResponse<T> {
  const ApiResponse();
}

class ApiSuccess<T> extends ApiResponse<T> {
  const ApiSuccess(this.data);

  final T data;
}

class ApiFailure<T> extends ApiResponse<T> {
  const ApiFailure({
    required this.message,
    this.code,
    this.cause,
  });

  final String message;
  final String? code;
  final Object? cause;
}
