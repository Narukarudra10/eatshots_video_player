import 'package:flutter_test/flutter_test.dart';
import 'package:eatshots_video_player/eatshots_video_player.dart';
import 'package:eatshots_video_player/eatshots_video_player_platform_interface.dart';
import 'package:eatshots_video_player/eatshots_video_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockEatshotsVideoPlayerPlatform extends EatshotsVideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final EatshotsVideoPlayerPlatform initialPlatform = EatshotsVideoPlayerPlatform.instance;

  test('$MethodChannelEatshotsVideoPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelEatshotsVideoPlayer>());
  });

  test('getPlatformVersion', () async {
    EatshotsVideoPlayerPlatformVersion eatshotsVideoPlayerPlugin = EatshotsVideoPlayerPlatformVersion();
    MockEatshotsVideoPlayerPlatform fakePlatform = MockEatshotsVideoPlayerPlatform();
    EatshotsVideoPlayerPlatform.instance = fakePlatform;

    expect(await eatshotsVideoPlayerPlugin.getPlatformVersion(), '42');
  });
}
