class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  void info(String message) {
    // Hook structured logging or crash reporting here after the target service is selected.
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {}

  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
