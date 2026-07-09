import 'package:flutter/widgets.dart';

import 'video_view_player_controller.dart';

class VideoViewPlayer extends StatelessWidget {
  final VideoViewPlayerController controller;

  const VideoViewPlayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final id = controller.textureId;
    if (id == null) {
      return const SizedBox.shrink();
    }
    return Texture(textureId: id);
  }
}
