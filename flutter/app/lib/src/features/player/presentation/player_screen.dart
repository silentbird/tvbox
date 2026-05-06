import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../library/application/library_providers.dart';
import '../../media/application/media_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyIdsProvider.notifier).record(widget.itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(mediaItemProvider(widget.itemId));

    if (item == null) {
      return const Scaffold(
        body: EmptyState(
          title: 'Playback unavailable',
          message: 'The selected media item does not exist.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 72,
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Stream URL'),
            subtitle: Text(item.streamUrl.toString()),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '播放器插件尚未接入；这里先记录播放历史并占位播放页结构。',
            ),
          ),
        ],
      ),
    );
  }
}
