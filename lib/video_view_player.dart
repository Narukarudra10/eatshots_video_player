export 'video_view_player_controller.dart';
export 'video_view_player_widget.dart';
export 'video_view_player_pool.dart';

import 'video_view_player_platform_interface.dart';

class VideoViewPlayerPlatformVersion {
  Future<String?> getPlatformVersion() {
    return VideoViewPlayerPlatform.instance.getPlatformVersion();
  }
}
