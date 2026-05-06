import '../domain/media_item.dart';

class SampleMediaRepository {
  const SampleMediaRepository();

  List<MediaItem> listItems() {
    return [
      MediaItem(
        id: 'movie-001',
        title: '山海试播源',
        category: '电影',
        description: '用于验证详情、收藏、历史和播放入口的样例影片。',
        year: 2026,
        duration: const Duration(minutes: 96),
        streamUrl: Uri.https('example.invalid', '/movie-001.m3u8'),
      ),
      MediaItem(
        id: 'series-001',
        title: '跨端剧集样例',
        category: '剧集',
        description: '用于验证分类、搜索和选集扩展的数据占位。',
        year: 2025,
        duration: const Duration(minutes: 45),
        streamUrl: Uri.https('example.invalid', '/series-001.m3u8'),
      ),
      MediaItem(
        id: 'live-001',
        title: '直播频道样例',
        category: '直播',
        description: '用于后续验证直播协议、遥控器焦点和大屏布局。',
        year: 2026,
        duration: Duration.zero,
        streamUrl: Uri.https('example.invalid', '/live-001.m3u8'),
      ),
    ];
  }

  MediaItem? findById(String id) {
    for (final item in listItems()) {
      if (item.id == id) {
        return item;
      }
    }

    return null;
  }
}
