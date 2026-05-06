import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvbox_flutter/src/app/tvbox_app.dart';
import 'package:tvbox_flutter/src/core/config/app_config.dart';
import 'package:tvbox_flutter/src/core/config/app_environment.dart';
import 'package:tvbox_flutter/src/core/logging/app_logger.dart';
import 'package:tvbox_flutter/src/core/state/app_providers.dart';
import 'package:tvbox_flutter/src/core/storage/in_memory_key_value_store.dart';

void main() {
  testWidgets('opens catalog detail and player flow', (tester) async {
    const environment = AppEnvironment.dev;
    final config = AppConfig.forEnvironment(environment);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          appConfigProvider.overrideWithValue(config),
          appLoggerProvider.overrideWithValue(
            const AppLogger('test'),
          ),
          keyValueStoreProvider.overrideWithValue(
            InMemoryKeyValueStore(),
          ),
        ],
        child: const TvboxApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('TVBox Dev'), findsOneWidget);

    await tester.tap(find.text('Browse catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);

    await tester.tap(find.text('山海试播源').first);
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Stream URL'), findsOneWidget);
  });
}
