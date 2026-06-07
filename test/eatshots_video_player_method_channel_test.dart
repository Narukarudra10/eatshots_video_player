import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatshots_video_player/eatshots_video_player_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelEatshotsVideoPlayer platform = MethodChannelEatshotsVideoPlayer();
  const MethodChannel channel = MethodChannel('eatshots_video_player');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
