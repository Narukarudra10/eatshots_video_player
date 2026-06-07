import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'eatshots_video_player_method_channel.dart';

abstract class EatshotsVideoPlayerPlatform extends PlatformInterface {
  /// Constructs a EatshotsVideoPlayerPlatform.
  EatshotsVideoPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static EatshotsVideoPlayerPlatform _instance = MethodChannelEatshotsVideoPlayer();

  /// The default instance of [EatshotsVideoPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelEatshotsVideoPlayer].
  static EatshotsVideoPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EatshotsVideoPlayerPlatform] when
  /// they register themselves.
  static set instance(EatshotsVideoPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> initialize(String url) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> play(int textureId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  Future<void> pause(int textureId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> seekTo(int textureId, Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  Future<void> setPlaybackSpeed(int textureId, double speed) {
    throw UnimplementedError('setPlaybackSpeed() has not been implemented.');
  }

  Future<void> setDataSource(int textureId, String url) {
    throw UnimplementedError('setDataSource() has not been implemented.');
  }

  Future<void> prefetch(String url, int bytes) {
    throw UnimplementedError('prefetch() has not been implemented.');
  }

  Future<int> getPosition(int textureId) {
    throw UnimplementedError('getPosition() has not been implemented.');
  }

  Future<void> dispose(int textureId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Future<void> setVolume(int textureId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<void> setLooping(int textureId, bool looping) {
    throw UnimplementedError('setLooping() has not been implemented.');
  }
}
