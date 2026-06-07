import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'eatshots_video_player_platform_interface.dart';

class EatshotsVideoValue {
  final Duration duration;
  final Duration position;
  final Size size;
  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLooping;
  final String? errorDescription;

  const EatshotsVideoValue({
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.size = Size.zero,
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isLooping = true,
    this.errorDescription,
  });

  bool get hasError => errorDescription != null;
  double get aspectRatio => size.width == 0 || size.height == 0 ? 9 / 16 : size.width / size.height;

  EatshotsVideoValue copyWith({
    Duration? duration,
    Duration? position,
    Size? size,
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? isLooping,
    String? errorDescription,
  }) {
    return EatshotsVideoValue(
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

class EatshotsVideoPlayerController extends ValueNotifier<EatshotsVideoValue> {
  String _dataSource;
  int? _textureId;
  StreamSubscription? _eventSubscription;
  Timer? _positionTimer;
  bool _isDisposed = false;

  // Track settings to apply them upon initialization
  double _volume = 1.0;
  bool _looping = true;
  bool _shouldPlay = false;

  EatshotsVideoPlayerController(String dataSource)
      : _dataSource = dataSource,
        super(const EatshotsVideoValue());

  EatshotsVideoPlayerController.networkUrl(Uri url)
      : _dataSource = url.toString(),
        super(const EatshotsVideoValue());

  EatshotsVideoPlayerController.file(dynamic file)
      : _dataSource = 'file://${file.path}',
        super(const EatshotsVideoValue());

  EatshotsVideoPlayerController.asset(String asset)
      : _dataSource = 'asset://$asset',
        super(const EatshotsVideoValue());

  int? get textureId => _textureId;
  bool get isDisposed => _isDisposed;
  String get dataSource => _dataSource;

  Future<void> initialize() async {
    if (_isDisposed) return;
    try {
      debugPrint("EatshotsPlayerController: Initializing for $_dataSource");
      final id = await EatshotsVideoPlayerPlatform.instance.initialize(_dataSource);
      _textureId = id;
      value = value.copyWith(isInitialized: false, errorDescription: null, isLooping: _looping);
      notifyListeners(); // Notify listeners that textureId is resolved

      debugPrint("EatshotsPlayerController: Initialized texture id $id, listening to EventChannel...");
      // Listen to EventChannel for state updates
      _eventSubscription = EventChannel('eatshots_video_player/videoEvents_$id')
          .receiveBroadcastStream()
          .listen(_handleEvent, onError: _handleError);

      // Apply pending settings now that textureId is resolved
      await EatshotsVideoPlayerPlatform.instance.setVolume(id, _volume);
      await EatshotsVideoPlayerPlatform.instance.setLooping(id, _looping);

      if (_shouldPlay) {
        await EatshotsVideoPlayerPlatform.instance.play(id);
        value = value.copyWith(isPlaying: true);
        _startPositionTimer();
      }
    } catch (e, stack) {
      debugPrint("EatshotsPlayerController: Initialization failed for $_dataSource: $e\n$stack");
      _handleError(e);
    }
  }

  void _handleEvent(dynamic event) {
    if (_isDisposed) return;
    final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
    debugPrint("EatshotsPlayerController: Received event: ${map['event']} for texture $_textureId details: $map");
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
        debugPrint("EatshotsPlayerController: Updated state for texture $_textureId: isInitialized=true, size=${value.size}");
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
    debugPrint("EatshotsPlayerController: Error on EventChannel for texture $_textureId: $error");
    value = value.copyWith(
      errorDescription: error is PlatformException ? error.message : error.toString(),
    );
  }

  Future<void> play() async {
    if (_isDisposed) return;
    _shouldPlay = true;
    final id = _textureId;
    if (id == null) return;
    await EatshotsVideoPlayerPlatform.instance.play(id);
    value = value.copyWith(isPlaying: true);
    _startPositionTimer();
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    _shouldPlay = false;
    final id = _textureId;
    if (id == null) return;
    await EatshotsVideoPlayerPlatform.instance.pause(id);
    value = value.copyWith(isPlaying: false);
    _stopPositionTimer();
  }

  Future<void> seekTo(Duration position) async {
    final id = _textureId;
    if (id == null || _isDisposed) return;
    await EatshotsVideoPlayerPlatform.instance.seekTo(id, position);
    value = value.copyWith(position: position);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final id = _textureId;
    if (id == null || _isDisposed) return;
    await EatshotsVideoPlayerPlatform.instance.setPlaybackSpeed(id, speed);
  }

  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    _volume = volume;
    final id = _textureId;
    if (id == null) return;
    await EatshotsVideoPlayerPlatform.instance.setVolume(id, volume);
  }

  Future<void> setLooping(bool looping) async {
    if (_isDisposed) return;
    _looping = looping;
    value = value.copyWith(isLooping: looping);
    final id = _textureId;
    if (id == null) return;
    await EatshotsVideoPlayerPlatform.instance.setLooping(id, looping);
  }

  Future<void> setDataSource(String url) async {
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
    await EatshotsVideoPlayerPlatform.instance.setDataSource(id, url);
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
        final posMs = await EatshotsVideoPlayerPlatform.instance.getPosition(id);
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

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _stopPositionTimer();
    await _eventSubscription?.cancel();
    final id = _textureId;
    if (id != null) {
      await EatshotsVideoPlayerPlatform.instance.dispose(id);
    }
    super.dispose();
  }
}
