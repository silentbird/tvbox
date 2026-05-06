import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    required this.showDebugBanner,
  });

  final AppEnvironment environment;
  final String appName;
  final Uri apiBaseUrl;
  final bool showDebugBanner;

  factory AppConfig.forEnvironment(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.dev => AppConfig(
          environment: environment,
          appName: 'TVBox Dev',
          apiBaseUrl: Uri.parse('https://example.invalid/dev'),
          showDebugBanner: true,
        ),
      AppEnvironment.staging => AppConfig(
          environment: environment,
          appName: 'TVBox Staging',
          apiBaseUrl: Uri.parse('https://example.invalid/staging'),
          showDebugBanner: true,
        ),
      AppEnvironment.prod => AppConfig(
          environment: environment,
          appName: 'TVBox',
          apiBaseUrl: Uri.parse('https://example.invalid'),
          showDebugBanner: false,
        ),
    };
  }
}
