import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/media_item_tile.dart';
import '../../media/application/media_providers.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Title, category, description',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).setQuery(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            EmptyState(
              title: 'No results',
              message: query.isEmpty ? null : 'Try another keyword.',
            )
          else
            for (final item in results)
              MediaItemTile(
                item: item,
                onOpen: () => context.go(AppRoutePaths.detailById(item.id)),
              ),
        ],
      ),
    );
  }
}
