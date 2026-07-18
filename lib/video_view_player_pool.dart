import 'dart:async';
import 'package:flutter/foundation.dart';

import 'video_view_player_controller.dart';
import 'video_view_player_platform_interface.dart';

/// Manages native video player recycling, prefetching, and network-adaptive feeds.
class VideoViewPlayerPoolManager extends ChangeNotifier {
  // A list containing at most 3 controller instances
  final List<VideoViewPlayerController> _pool = [];
  // Mapping from video URL to the active controller managing it
  final Map<String, VideoViewPlayerController> _activeControllers = {};

  /// The complete ordered list of video URLs in the scrolling feed.
  final List<String> urls;

  int? _nextIndexToUpdate;
  bool _isUpdating = false;

  // Connection & Adaptive properties
  String _networkType = 'WIFI';

  /// Real-time detected network connection type (`WIFI`, `5G`, `4G`, `3G`, or `NONE`).
  String get networkType => _networkType;

  String? _simulatedNetworkType;

  /// Optional network type override for testing adaptive buffer behaviors.
  String? get simulatedNetworkType => _simulatedNetworkType;
  set simulatedNetworkType(String? value) {
    _simulatedNetworkType = value;
    notifyListeners();
  }

  /// Effective network type considering active simulated override or real hardware network status.
  String get effectiveNetworkType => _simulatedNetworkType ?? _networkType;

  // A set to track urls that are currently undergoing background prefetching
  final Set<String> _activePrefetches = {};
  
  StreamSubscription<String>? _networkSubscription;

  /// Creates a [VideoViewPlayerPoolManager] managing the specified feed [urls].
  VideoViewPlayerPoolManager({required this.urls}) {
    _networkSubscription = VideoViewPlayerPlatform.instance.onNetworkTypeChanged.listen((netType) {
      if (_networkType != netType) {
        _networkType = netType;
        notifyListeners();
      }
    });
  }

  /// Triggers background prefetching of the first [bytes] of a video [url].
  Future<void> prefetch(String url, {required int bytes}) async {
    try {
      await VideoViewPlayerPlatform.instance.prefetch(url, bytes);
    } catch (e) {
      // Ignore prefetch errors in background
    } finally {
      _activePrefetches.remove(url);
    }
  }

  /// Updates active controllers based on the current scroll [currentIndex].
  /// Instantiates at most 3 controllers, recycling idle controllers
  /// using URL swapping rather than disposing and recreating them.
  Future<void> updateActiveIndex(int currentIndex) async {
    _nextIndexToUpdate = currentIndex;
    
    // Update network connection status
    try {
      final netType = await VideoViewPlayerPlatform.instance.getNetworkType();
      if (_networkType != netType) {
        _networkType = netType;
        notifyListeners();
      }
    } catch (_) {}

    if (_isUpdating) return;
    _isUpdating = true;

    try {
      while (_nextIndexToUpdate != null) {
        final targetIndex = _nextIndexToUpdate!;
        _nextIndexToUpdate = null;
        await _performUpdate(targetIndex);
      }
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> _performUpdate(int currentIndex) async {
    // 1. Identify the 3 desired URLs (previous, current, next)
    final desiredUrls = <String>[];
    if (currentIndex - 1 >= 0) {
      desiredUrls.add(urls[currentIndex - 1]);
    }
    desiredUrls.add(urls[currentIndex]);
    if (currentIndex + 1 < urls.length) {
      desiredUrls.add(urls[currentIndex + 1]);
    }

    // 2. Adaptive prefetch logic based on connection quality
    final net = effectiveNetworkType;
    final int prefetchBytes;
    final int prefetchCount;

    if (net == 'WIFI' || net == '5G') {
      prefetchBytes = 1500 * 1024; // 1.5MB for high speed
      prefetchCount = 2; // Prefetch next 2 videos ahead
    } else if (net == '4G') {
      prefetchBytes = 384 * 1024; // 384KB optimized for 4G
      prefetchCount = 1; // Prefetch 1 video ahead
    } else {
      prefetchBytes = 128 * 1024; // 128KB for slow networks
      prefetchCount = 1; // Prefetch 1 video ahead
    }

    // Determine upcoming prefetch URLs
    final prefetchUrls = <String>[];
    for (int i = 1; i <= prefetchCount; i++) {
      if (currentIndex + 1 + i < urls.length) {
        prefetchUrls.add(urls[currentIndex + 1 + i]);
      }
    }

    // Start new background prefetch tasks
    for (final url in prefetchUrls) {
      if (!_activePrefetches.contains(url)) {
        _activePrefetches.add(url);
        prefetch(url, bytes: prefetchBytes);
      }
    }

    // Active cancellation: Abort background prefetching for any URLs no longer relevant
    final toCancel = _activePrefetches.where((url) => !prefetchUrls.contains(url)).toList();
    for (final url in toCancel) {
      _activePrefetches.remove(url);
      VideoViewPlayerPlatform.instance.cancelPrefetch(url);
    }

    // 3. See which desired URLs already have controllers
    final urlsToAssign = desiredUrls.where((url) => !_activeControllers.containsKey(url)).toList();

    // 4. Find controllers that are no longer needed in the active set
    final idleUrls = _activeControllers.keys.where((url) => !desiredUrls.contains(url)).toList();
    final idleControllers = idleUrls.map((url) => _activeControllers[url]!).toList();

    // 5. Recycle idle controllers or create new ones if pool is not full
    for (final url in urlsToAssign) {
      VideoViewPlayerController controller;
      if (_pool.length < 3) {
        controller = VideoViewPlayerController(url);
        _pool.add(controller);
        _activeControllers[url] = controller;
        notifyListeners(); // Notify UI that a controller has been assigned so it shows the loading texture
        await controller.initialize();
      } else if (idleControllers.isNotEmpty) {
        // Recycle the idle controller
        controller = idleControllers.removeAt(0);
        // Find and remove old URL mapping
        final oldUrl = _activeControllers.entries.firstWhere((e) => e.value == controller).key;
        _activeControllers.remove(oldUrl);
        _activeControllers[url] = controller;
        notifyListeners(); // Notify UI of URL swapping
        await controller.setDataSource(url);
      } else {
        break;
      }
    }

    // 6. Play the current index and pause the other active ones
    final currentUrl = urls[currentIndex];
    for (final entry in _activeControllers.entries) {
      if (entry.key == currentUrl) {
        await entry.value.play();
      } else {
        await entry.value.pause();
      }
    }
    notifyListeners();
  }

  /// Retrieves the active controller for a given [url], if assigned in the pool.
  VideoViewPlayerController? getControllerForUrl(String url) {
    return _activeControllers[url];
  }

  /// Disposes all managed player controllers and releases network event subscriptions.
  @override
  Future<void> dispose() async {
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    _activePrefetches.clear();
    _activeControllers.clear();
    for (final controller in _pool) {
      await controller.dispose();
    }
    _pool.clear();
    super.dispose();
  }
}
