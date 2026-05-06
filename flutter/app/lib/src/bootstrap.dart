import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/tvbox_app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_environment.dart';
import 'core/logging/app_logger.dart';
import 'core/state/app_providers.dart';
import 'core/storage/shared_preferences_key_value_store.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.forEnvironment(environment);
  final logger = AppLogger(config.environment.name);
  final preferences = await SharedPreferences.getInstance();

  logger.info('Bootstrapping ${config.appName}');

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        appConfigProvider.overrideWithValue(config),
        appLoggerProvider.overrideWithValue(logger),
        keyValueStoreProvider.overrideWithValue(
          SharedPreferencesKeyValueStore(preferences),
        ),
      ],
      child: const TvboxApp(),
    ),
  );
}
