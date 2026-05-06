import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';

final startupProvider = FutureProvider<StartupState>((ref) async {
  final config = ref.watch(appConfigProvider);
  final logger = ref.watch(appLoggerProvider);

  logger.info('Initializing ${config.appName}');

  await Future<void>.delayed(const Duration(milliseconds: 250));

  return StartupState(
    appName: config.appName,
    configSource: config.apiBaseUrl.toString(),
  );
});

class StartupState {
  const StartupState({
    required this.appName,
    required this.configSource,
  });

  final String appName;
  final String configSource;
}
