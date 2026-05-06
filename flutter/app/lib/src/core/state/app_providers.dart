import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/app_environment.dart';
import '../logging/app_logger.dart';
import '../storage/in_memory_key_value_store.dart';
import '../storage/key_value_store.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.dev;
});

final appConfigProvider = Provider<AppConfig>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return AppConfig.forEnvironment(environment);
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppLogger(config.environment.name);
});

final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return InMemoryKeyValueStore();
});
