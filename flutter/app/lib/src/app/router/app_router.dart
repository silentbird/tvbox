import 'package:go_router/go_router.dart';

import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/detail/presentation/detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_route_paths.dart';

class AppRouter {
  const AppRouter._();

  static final config = GoRouter(
    initialLocation: AppRoutePaths.home,
    routes: [
      GoRoute(
        path: AppRoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.catalog,
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '${AppRoutePaths.detail}/:id',
        builder: (context, state) {
          return DetailScreen(
            itemId: state.pathParameters['id'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '${AppRoutePaths.player}/:id',
        builder: (context, state) {
          return PlayerScreen(
            itemId: state.pathParameters['id'] ?? '',
          );
        },
      ),
    ],
  );
}
