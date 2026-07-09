import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'video_view_player_method_channel.dart';

abstract class VideoViewPlayerPlatform extends PlatformInterface {
  /// Constructs a VideoViewPlayerPlatform.
  VideoViewPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static VideoViewPlayerPlatform _instance = MethodChannelVideoViewPlayer();

  /// The default instance of [VideoViewPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelVideoViewPlayer].
  static VideoViewPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VideoViewPlayerPlatform] when
  /// they register themselves.
  static set instance(VideoViewPlayerPlatform instance) {
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

  Future<String> getNetworkType() {
    throw UnimplementedError('getNetworkType() has not been implemented.');
  }

  Future<void> cancelPrefetch(String url) {
    throw UnimplementedError('cancelPrefetch() has not been implemented.');
  }

  Stream<String> get onNetworkTypeChanged {
    throw UnimplementedError('onNetworkTypeChanged has not been implemented.');
  }
}
