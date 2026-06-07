import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'eatshots_video_player_platform_interface.dart';

/// An implementation of [EatshotsVideoPlayerPlatform] that uses method channels.
class MethodChannelEatshotsVideoPlayer extends EatshotsVideoPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('eatshots_video_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<int> initialize(String url) async {
    final textureId = await methodChannel.invokeMethod<int>(
      'initialize',
      <String, dynamic>{'url': url},
    );
    if (textureId == null) {
      throw PlatformException(
        code: 'INITIALIZATION_FAILED',
        message: 'Could not initialize player texture.',
      );
    }
    return textureId;
  }

  @override
  Future<void> play(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'play',
      <String, dynamic>{'textureId': textureId},
    );
  }

  @override
  Future<void> pause(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'pause',
      <String, dynamic>{'textureId': textureId},
    );
  }

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    await methodChannel.invokeMethod<void>(
      'seekTo',
      <String, dynamic>{
        'textureId': textureId,
        'position': position.inMilliseconds,
      },
    );
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {
    await methodChannel.invokeMethod<void>(
      'setPlaybackSpeed',
      <String, dynamic>{
        'textureId': textureId,
        'speed': speed,
      },
    );
  }

  @override
  Future<void> setDataSource(int textureId, String url) async {
    await methodChannel.invokeMethod<void>(
      'setDataSource',
      <String, dynamic>{
        'textureId': textureId,
        'url': url,
      },
    );
  }

  @override
  Future<void> prefetch(String url, int bytes) async {
    await methodChannel.invokeMethod<void>(
      'prefetch',
      <String, dynamic>{
        'url': url,
        'bytes': bytes,
      },
    );
  }

  @override
  Future<int> getPosition(int textureId) async {
    final position = await methodChannel.invokeMethod<int>(
      'getPosition',
      <String, dynamic>{'textureId': textureId},
    );
    return position ?? 0;
  }

  @override
  Future<void> dispose(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'dispose',
      <String, dynamic>{'textureId': textureId},
    );
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {
    await methodChannel.invokeMethod<void>(
      'setVolume',
      <String, dynamic>{
        'textureId': textureId,
        'volume': volume,
      },
    );
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {
    await methodChannel.invokeMethod<void>(
      'setLooping',
      <String, dynamic>{
        'textureId': textureId,
        'looping': looping,
      },
    );
  }
}
