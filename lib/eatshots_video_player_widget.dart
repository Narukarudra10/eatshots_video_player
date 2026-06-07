import 'package:flutter/widgets.dart';

import 'eatshots_video_player_controller.dart';

class EatshotsVideoPlayer extends StatelessWidget {
  final EatshotsVideoPlayerController controller;

  const EatshotsVideoPlayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final id = controller.textureId;
    if (id == null) {
      return const SizedBox.shrink();
    }
    return Texture(textureId: id);
  }
}
