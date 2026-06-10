import 'dart:async';
import 'package:flutter/foundation.dart';

import 'eatshots_video_player_controller.dart';
import 'eatshots_video_player_platform_interface.dart';

class EatshotsVideoPlayerPoolManager extends ChangeNotifier {
  // A list containing at most 3 controller instances
  final List<EatshotsVideoPlayerController> _pool = [];
  // Mapping from video URL to the active controller managing it
  final Map<String, EatshotsVideoPlayerController> _activeControllers = {};
  // The complete list of video URLs in the feed
  final List<String> urls;

  int? _nextIndexToUpdate;
  bool _isUpdating = false;

  // Connection & Adaptive properties
  String _networkType = 'WIFI';
  String get networkType => _networkType;

  String? _simulatedNetworkType;
  String? get simulatedNetworkType => _simulatedNetworkType;
  set simulatedNetworkType(String? value) {
    _simulatedNetworkType = value;
    notifyListeners();
  }

  String get effectiveNetworkType => _simulatedNetworkType ?? _networkType;

  // A set to track urls that are currently undergoing background prefetching
  final Set<String> _activePrefetches = {};
  
  StreamSubscription<String>? _networkSubscription;

  EatshotsVideoPlayerPoolManager({required this.urls}) {
    _networkSubscription = EatshotsVideoPlayerPlatform.instance.onNetworkTypeChanged.listen((netType) {
      if (_networkType != netType) {
        _networkType = netType;
        notifyListeners();
      }
    });
  }

  /// Prefetch the first N bytes of a video to the cache
  Future<void> prefetch(String url, {required int bytes}) async {
    try {
      await EatshotsVideoPlayerPlatform.instance.prefetch(url, bytes);
    } catch (e) {
      // Ignore prefetch errors in background
    } finally {
      _activePrefetches.remove(url);
    }
  }

  /// Updates active controllers based on the current scroll index.
  /// Instantiates at most 3 controllers, recycling idle controllers
  /// using URL swapping rather than disposing and recreating them.
  Future<void> updateActiveIndex(int currentIndex) async {
    _nextIndexToUpdate = currentIndex;
    
    // Update network connection status
    try {
      final netType = await EatshotsVideoPlayerPlatform.instance.getNetworkType();
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
      EatshotsVideoPlayerPlatform.instance.cancelPrefetch(url);
    }

    // 3. See which desired URLs already have controllers
    final urlsToAssign = desiredUrls.where((url) => !_activeControllers.containsKey(url)).toList();

    // 4. Find controllers that are no longer needed in the active set
    final idleUrls = _activeControllers.keys.where((url) => !desiredUrls.contains(url)).toList();
    final idleControllers = idleUrls.map((url) => _activeControllers[url]!).toList();

    // 5. Recycle idle controllers or create new ones if pool is not full
    for (final url in urlsToAssign) {
      EatshotsVideoPlayerController controller;
      if (_pool.length < 3) {
        controller = EatshotsVideoPlayerController(url);
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

  /// Retrieves the active controller for a URL, if any
  EatshotsVideoPlayerController? getControllerForUrl(String url) {
    return _activeControllers[url];
  }

  /// Clear resources and dispose all controllers
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
