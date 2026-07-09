import 'package:flutter_test/flutter_test.dart';
import 'package:video_view_player/video_view_player.dart';
import 'package:video_view_player/video_view_player_platform_interface.dart';
import 'package:video_view_player/video_view_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoViewPlayerPlatform extends VideoViewPlayerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VideoViewPlayerPlatform initialPlatform = VideoViewPlayerPlatform.instance;

  test('$MethodChannelVideoViewPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVideoViewPlayer>());
  });

  test('getPlatformVersion', () async {
    VideoViewPlayerPlatformVersion eatshotsVideoPlayerPlugin = VideoViewPlayerPlatformVersion();
    MockVideoViewPlayerPlatform fakePlatform = MockVideoViewPlayerPlatform();
    VideoViewPlayerPlatform.instance = fakePlatform;

    expect(await eatshotsVideoPlayerPlugin.getPlatformVersion(), '42');
  });
}
