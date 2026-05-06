class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.year,
    required this.duration,
    required this.streamUrl,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final int year;
  final Duration duration;
  final Uri streamUrl;
}
