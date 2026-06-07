export 'eatshots_video_player_controller.dart';
export 'eatshots_video_player_widget.dart';
export 'eatshots_video_player_pool.dart';

import 'eatshots_video_player_platform_interface.dart';

class EatshotsVideoPlayerPlatformVersion {
  Future<String?> getPlatformVersion() {
    return EatshotsVideoPlayerPlatform.instance.getPlatformVersion();
  }
}
