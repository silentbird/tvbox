import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../library/application/library_providers.dart';
import '../../media/application/media_providers.dart';

class DetailScreen extends ConsumerWidget {
  const DetailScreen({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemProvider(itemId));
    final favorites = ref.watch(favoriteIdsProvider);

    if (item == null) {
      return const Scaffold(
        body: EmptyState(
          title: 'Item not found',
          message: 'The selected media item does not exist.',
        ),
      );
    }

    final isFavorite = favorites.contains(item.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
            onPressed: () {
              ref.read(favoriteIdsProvider.notifier).toggle(item.id);
            },
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${item.category} · ${item.year}'),
          const SizedBox(height: 16),
          Text(item.description),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutePaths.playerById(item.id)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
          ),
        ],
      ),
    );
  }
}
