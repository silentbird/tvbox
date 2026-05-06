class AppRoutePaths {
  const AppRoutePaths._();

  static const home = '/';
  static const catalog = '/catalog';
  static const search = '/search';
  static const settings = '/settings';
  static const detail = '/detail';
  static const player = '/player';

  static String detailById(String id) => '$detail/$id';

  static String playerById(String id) => '$player/$id';
}
