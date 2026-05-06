import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Environment'),
            subtitle: Text(config.environment.name),
          ),
          ListTile(
            title: const Text('API Base URL'),
            subtitle: Text(config.apiBaseUrl.toString()),
          ),
          const ListTile(
            title: Text('Storage'),
            subtitle: Text('SharedPreferences adapter is configured.'),
          ),
        ],
      ),
    );
  }
}
