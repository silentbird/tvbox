class ApiRequest {
  const ApiRequest({
    required this.path,
    this.method = ApiMethod.get,
    this.query = const {},
    this.body,
  });

  final String path;
  final ApiMethod method;
  final Map<String, String> query;
  final Object? body;
}

enum ApiMethod {
  get,
  post,
  put,
  delete,
}
