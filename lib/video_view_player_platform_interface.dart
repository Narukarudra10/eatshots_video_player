import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'video_view_player_method_channel.dart';

/// The interface that implementations of `video_view_player` must implement.
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

  /// Retrieves the host platform OS version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Initializes the native video player for [url] and returns a hardware texture ID.
  Future<int> initialize(String url) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Starts playback on player instance with [textureId].
  Future<void> play(int textureId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Pauses playback on player instance with [textureId].
  Future<void> pause(int textureId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Seeks player instance [textureId] to [position].
  Future<void> seekTo(int textureId, Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  /// Sets playback speed for player instance [textureId].
  Future<void> setPlaybackSpeed(int textureId, double speed) {
    throw UnimplementedError('setPlaybackSpeed() has not been implemented.');
  }

  /// Swaps video data source for player instance [textureId] to [url].
  Future<void> setDataSource(int textureId, String url) {
    throw UnimplementedError('setDataSource() has not been implemented.');
  }

  /// Triggers native prefetching of initial [bytes] for video [url].
  Future<void> prefetch(String url, int bytes) {
    throw UnimplementedError('prefetch() has not been implemented.');
  }

  /// Gets current playback position in milliseconds for player instance [textureId].
  Future<int> getPosition(int textureId) {
    throw UnimplementedError('getPosition() has not been implemented.');
  }

  /// Disposes native player instance [textureId].
  Future<void> dispose(int textureId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Sets audio volume for player instance [textureId].
  Future<void> setVolume(int textureId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  /// Toggles looping for player instance [textureId].
  Future<void> setLooping(int textureId, bool looping) {
    throw UnimplementedError('setLooping() has not been implemented.');
  }

  /// Gets current network type string from native network detector.
  Future<String> getNetworkType() {
    throw UnimplementedError('getNetworkType() has not been implemented.');
  }

  /// Cancels active prefetching for [url].
  Future<void> cancelPrefetch(String url) {
    throw UnimplementedError('cancelPrefetch() has not been implemented.');
  }

  /// Stream emitting real-time network connection type changes.
  Stream<String> get onNetworkTypeChanged {
    throw UnimplementedError('onNetworkTypeChanged has not been implemented.');
  }
}
