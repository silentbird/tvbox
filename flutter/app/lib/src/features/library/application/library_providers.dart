import 'package:flutter_riverpod/flutter_riverpod.dart';

final favoriteIdsProvider =
    NotifierProvider<FavoriteIdsController, Set<String>>(
  FavoriteIdsController.new,
);

class FavoriteIdsController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return {};
  }

  void toggle(String id) {
    if (state.contains(id)) {
      final next = {...state};
      next.remove(id);
      state = next;
      return;
    }

    state = {...state, id};
  }
}

final historyIdsProvider = NotifierProvider<HistoryIdsController, List<String>>(
  HistoryIdsController.new,
);

class HistoryIdsController extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  void record(String id) {
    state = [
      id,
      ...state.where((historyId) => historyId != id),
    ].take(20).toList();
  }
}
