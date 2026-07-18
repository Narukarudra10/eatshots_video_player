/// Library exports for the video_view_player plugin.
library;

export 'video_view_player_controller.dart';
export 'video_view_player_pool.dart';
export 'video_view_player_widget.dart';

import 'video_view_player_platform_interface.dart';

/// Helper class to query host platform details.
class VideoViewPlayerPlatformVersion {
  /// Default constructor for [VideoViewPlayerPlatformVersion].
  const VideoViewPlayerPlatformVersion();

  /// Retrieves the current platform version string (e.g. Android version or iOS version).
  Future<String?> getPlatformVersion() {
    return VideoViewPlayerPlatform.instance.getPlatformVersion();
  }
}
