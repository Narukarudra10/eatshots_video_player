import 'package:flutter/widgets.dart';

import 'video_view_player_controller.dart';

/// A Flutter widget that renders native video player frames via a hardware [Texture].
///
/// Requires a fully initialized [VideoViewPlayerController].
class VideoViewPlayer extends StatelessWidget {
  /// The [VideoViewPlayerController] controlling playback state and texture rendering.
  final VideoViewPlayerController controller;

  /// Creates a [VideoViewPlayer] widget for rendering native video output.
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
