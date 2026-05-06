import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_media_repository.dart';
import '../domain/media_item.dart';

final mediaRepositoryProvider = Provider<SampleMediaRepository>((ref) {
  return const SampleMediaRepository();
});

final mediaItemsProvider = Provider<List<MediaItem>>((ref) {
  return ref.watch(mediaRepositoryProvider).listItems();
});

final mediaItemProvider = Provider.family<MediaItem?, String>((ref, id) {
  return ref.watch(mediaRepositoryProvider).findById(id);
});

final categoriesProvider = Provider<List<String>>((ref) {
  final categories = ref.watch(mediaItemsProvider).map((item) => item.category);
  return categories.toSet().toList()..sort();
});

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryController, String?>(
  SelectedCategoryController.new,
);

class SelectedCategoryController extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void select(String? category) {
    state = category;
  }
}

final filteredMediaItemsProvider = Provider<List<MediaItem>>((ref) {
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final items = ref.watch(mediaItemsProvider);

  if (selectedCategory == null) {
    return items;
  }

  return items.where((item) => item.category == selectedCategory).toList();
});

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

class SearchQueryController extends Notifier<String> {
  @override
  String build() {
    return '';
  }

  void setQuery(String query) {
    state = query;
  }
}

final searchResultsProvider = Provider<List<MediaItem>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final items = ref.watch(mediaItemsProvider);

  if (query.isEmpty) {
    return items;
  }

  return items.where((item) {
    return item.title.toLowerCase().contains(query) ||
        item.category.toLowerCase().contains(query) ||
        item.description.toLowerCase().contains(query);
  }).toList();
});
