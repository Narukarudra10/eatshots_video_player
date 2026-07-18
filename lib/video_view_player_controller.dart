import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'video_view_player_platform_interface.dart';

/// Represents the reactive state of a [VideoViewPlayerController].
class VideoViewValue {
  /// Total duration of the loaded video.
  final Duration duration;

  /// Current playback position of the video.
  final Duration position;

  /// Width and height dimensions of the video stream.
  final Size size;

  /// Whether the native player has completed initial metadata loading.
  final bool isInitialized;

  /// Whether the video is currently actively playing.
  final bool isPlaying;

  /// Whether the player is currently waiting for network data buffering.
  final bool isBuffering;

  /// Whether the video automatically loops upon reaching the end.
  final bool isLooping;

  /// Description of any playback error encountered, or `null` if healthy.
  final String? errorDescription;

  /// Constructs a [VideoViewValue] snapshot with default or explicit values.
  const VideoViewValue({
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.size = Size.zero,
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isLooping = true,
    this.errorDescription,
  });

  /// True if an error description is present.
  bool get hasError => errorDescription != null;

  /// Calculated aspect ratio (width / height) or `9 / 16` if uninitialized.
  double get aspectRatio => size.width == 0 || size.height == 0 ? 9 / 16 : size.width / size.height;

  /// Creates a copy of [VideoViewValue] with updated fields.
  VideoViewValue copyWith({
    Duration? duration,
    Duration? position,
    Size? size,
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? isLooping,
    String? errorDescription,
  }) {
    return VideoViewValue(
      duration: duration ?? this.duration,
      position: position ?? this.position,
      size: size ?? this.size,
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isLooping: isLooping ?? this.isLooping,
      errorDescription: errorDescription ?? this.errorDescription,
    );
  }
}

/// Controls native video decoding, playback states, and hardware texture mapping.
class VideoViewPlayerController extends ValueNotifier<VideoViewValue> {
  String _dataSource;
  int? _textureId;
  StreamSubscription? _eventSubscription;
  Timer? _positionTimer;
  bool _isDisposed = false;
  Future<void>? _initializationFuture;

  // Track settings to apply them upon initialization
  double _volume = 1.0;
  bool _looping = true;
  bool _shouldPlay = false;

  /// Creates a controller for a given [dataSource] string URL.
  VideoViewPlayerController(String dataSource)
      : _dataSource = dataSource,
        super(const VideoViewValue());

  /// Named constructor for network video streams from a [url].
  VideoViewPlayerController.networkUrl(Uri url)
      : _dataSource = url.toString(),
        super(const VideoViewValue());

  /// Named constructor for local filesystem files.
  VideoViewPlayerController.file(dynamic file)
      : _dataSource = 'file://${file.path}',
        super(const VideoViewValue());

  /// Named constructor for local Flutter app assets.
  VideoViewPlayerController.asset(String asset)
      : _dataSource = 'asset://$asset',
        super(const VideoViewValue());

  /// Hardware texture ID assigned by the native platform engine.
  int? get textureId => _textureId;

  /// Whether this controller instance has been disposed.
  bool get isDisposed => _isDisposed;

  /// The active video data source URL or path string.
  String get dataSource => _dataSource;

  /// Initializes the native video player and binds hardware texture rendering.
  Future<void> initialize() async {
    if (_isDisposed) return;
    _initializationFuture = _initializeInternal();
    return _initializationFuture;
  }

  Future<void> _initializeInternal() async {
    try {
      debugPrint("VideoViewPlayerController: Initializing for $_dataSource");
      final id = await VideoViewPlayerPlatform.instance.initialize(_dataSource);
      _textureId = id;
      value = value.copyWith(isInitialized: false, errorDescription: null, isLooping: _looping);
      notifyListeners(); // Notify listeners that textureId is resolved

      debugPrint("VideoViewPlayerController: Initialized texture id $id, listening to EventChannel...");
      // Listen to EventChannel for state updates
      _eventSubscription = EventChannel('video_view_player/videoEvents_$id')
          .receiveBroadcastStream()
          .listen(_handleEvent, onError: _handleError);

      // Apply pending settings now that textureId is resolved
      await VideoViewPlayerPlatform.instance.setVolume(id, _volume);
      await VideoViewPlayerPlatform.instance.setLooping(id, _looping);

      if (_shouldPlay) {
        await VideoViewPlayerPlatform.instance.play(id);
        value = value.copyWith(isPlaying: true);
        _startPositionTimer();
      }
    } catch (e, stack) {
      debugPrint("VideoViewPlayerController: Initialization failed for $_dataSource: $e\n$stack");
      _handleError(e);
      rethrow;
    }
  }

  void _handleEvent(dynamic event) {
    if (_isDisposed) return;
    final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
    debugPrint("VideoViewPlayerController: Received event: ${map['event']} for texture $_textureId details: $map");
    switch (map['event']) {
      case 'initialized':
        value = value.copyWith(
          isInitialized: true,
          duration: Duration(milliseconds: map['duration'] as int),
          size: Size(
            (map['width'] as num).toDouble(),
            (map['height'] as num).toDouble(),
          ),
        );
        debugPrint("VideoViewPlayerController: Updated state for texture $_textureId: isInitialized=true, size=${value.size}");
        break;
      case 'bufferingStart':
        value = value.copyWith(isBuffering: true);
        break;
      case 'bufferingEnd':
        value = value.copyWith(isBuffering: false);
        break;
      case 'completed':
        value = value.copyWith(isPlaying: false, position: value.duration);
        _stopPositionTimer();
        break;
      case 'error':
        value = value.copyWith(
          errorDescription: map['errorDescription'] as String?,
        );
        break;
    }
  }

  void _handleError(dynamic error) {
    if (_isDisposed) return;
    debugPrint("VideoViewPlayerController: Error on EventChannel for texture $_textureId: $error");
    value = value.copyWith(
      errorDescription: error is PlatformException ? error.message : error.toString(),
    );
  }

  /// Starts or resumes video playback.
  Future<void> play() async {
    if (_isDisposed) return;
    _shouldPlay = true;
    final id = _textureId;
    if (id == null) return;
    await VideoViewPlayerPlatform.instance.play(id);
    value = value.copyWith(isPlaying: true);
    _startPositionTimer();
  }

  /// Pauses video playback.
  Future<void> pause() async {
    if (_isDisposed) return;
    _shouldPlay = false;
    final id = _textureId;
    if (id == null) return;
    await VideoViewPlayerPlatform.instance.pause(id);
    value = value.copyWith(isPlaying: false);
    _stopPositionTimer();
  }

  /// Seeks playback to the specified [position].
  Future<void> seekTo(Duration position) async {
    final id = _textureId;
    if (id == null || _isDisposed) return;
    await VideoViewPlayerPlatform.instance.seekTo(id, position);
    value = value.copyWith(position: position);
  }

  /// Sets the native player playback [speed] (e.g. `1.0`, `1.5`, `2.0`).
  Future<void> setPlaybackSpeed(double speed) async {
    final id = _textureId;
    if (id == null || _isDisposed) return;
    await VideoViewPlayerPlatform.instance.setPlaybackSpeed(id, speed);
  }

  /// Sets player audio [volume] (`0.0` - `1.0`). Safely buffers before init.
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    _volume = volume;
    final id = _textureId;
    if (id == null) return;
    await VideoViewPlayerPlatform.instance.setVolume(id, volume);
  }

  /// Sets whether the video should automatically loop upon completion.
  Future<void> setLooping(bool looping) async {
    if (_isDisposed) return;
    _looping = looping;
    value = value.copyWith(isLooping: looping);
    final id = _textureId;
    if (id == null) return;
    await VideoViewPlayerPlatform.instance.setLooping(id, looping);
  }

  /// Swaps the active video source to [url] without recreating native player instances.
  Future<void> setDataSource(String url) async {
    if (_isDisposed) return;
    if (_initializationFuture != null) {
      try {
        await _initializationFuture;
      } catch (e) {
        // Ignore initialization error since we are recycling the player for a new URL
      }
    }
    final id = _textureId;
    if (id == null || _isDisposed) return;
    _dataSource = url;
    await pause();
    value = value.copyWith(
      isInitialized: false,
      isPlaying: false,
      isBuffering: false,
      position: Duration.zero,
      duration: Duration.zero,
      errorDescription: null,
    );
    await VideoViewPlayerPlatform.instance.setDataSource(id, url);
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      final id = _textureId;
      if (id == null || _isDisposed || !value.isPlaying) {
        _stopPositionTimer();
        return;
      }
      try {
        final posMs = await VideoViewPlayerPlatform.instance.getPosition(id);
        if (!_isDisposed) {
          value = value.copyWith(position: Duration(milliseconds: posMs));
        }
      } catch (e) {
        // Ignore polling errors
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Releases native player instances, event listeners, and hardware texture resources.
  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _stopPositionTimer();
    await _eventSubscription?.cancel();
    final id = _textureId;
    if (id != null) {
      await VideoViewPlayerPlatform.instance.dispose(id);
    }
    super.dispose();
  }
}
