import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/app_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TvboxApp extends ConsumerWidget {
  const TvboxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return MaterialApp.router(
      title: config.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: AppRouter.config,
      debugShowCheckedModeBanner: config.showDebugBanner,
    );
  }
}
