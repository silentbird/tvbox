import 'package:flutter/material.dart';

import '../../features/media/domain/media_item.dart';

class MediaItemTile extends StatelessWidget {
  const MediaItemTile({
    required this.item,
    required this.onOpen,
    this.trailing,
    super.key,
  });

  final MediaItem item;
  final VoidCallback onOpen;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final durationText = item.duration == Duration.zero
        ? 'Live'
        : '${item.duration.inMinutes} min';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        child: Text(item.category.substring(0, 1)),
      ),
      title: Text(item.title),
      subtitle: Text('${item.category} · ${item.year} · $durationText'),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onOpen,
    );
  }
}
