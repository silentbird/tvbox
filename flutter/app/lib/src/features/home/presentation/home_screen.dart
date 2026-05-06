import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/startup/startup_controller.dart';
import '../../../core/state/app_providers.dart';
import '../../../shared/widgets/media_item_tile.dart';
import '../../library/application/library_providers.dart';
import '../../media/application/media_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final startup = ref.watch(startupProvider);
    final items = ref.watch(mediaItemsProvider);
    final favorites = ref.watch(favoriteIdsProvider);
    final history = ref.watch(historyIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(config.appName),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go(AppRoutePaths.search),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: startup.when(
              data: (state) => _StartupSummary(
                title: state.appName,
                subtitle: 'Config: ${state.configSource}',
              ),
              error: (error, stackTrace) => _StartupSummary(
                title: 'Initialization failed',
                subtitle: error.toString(),
              ),
              loading: () => const LinearProgressIndicator(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => context.go(AppRoutePaths.catalog),
              icon: const Icon(Icons.view_list_outlined),
              label: const Text('Browse catalog'),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            MediaItemTile(
              item: item,
              onOpen: () => context.go(AppRoutePaths.detailById(item.id)),
              trailing: IconButton(
                tooltip: favorites.contains(item.id)
                    ? 'Remove favorite'
                    : 'Add favorite',
                onPressed: () {
                  ref.read(favoriteIdsProvider.notifier).toggle(item.id);
                },
                icon: Icon(
                  favorites.contains(item.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
              ),
            ),
          if (history.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in items.where((item) => history.contains(item.id)))
              MediaItemTile(
                item: item,
                onOpen: () => context.go(AppRoutePaths.detailById(item.id)),
              ),
          ],
        ],
      ),
    );
  }
}

class _StartupSummary extends StatelessWidget {
  const _StartupSummary({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(subtitle),
      ],
    );
  }
}
