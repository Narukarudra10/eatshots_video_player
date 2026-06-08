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

  EatshotsVideoPlayerPoolManager({required this.urls});

  /// Prefetch the first N bytes of a video to the cache
  Future<void> prefetch(String url, {int bytes = 1024 * 1024}) async {
    try {
      await EatshotsVideoPlayerPlatform.instance.prefetch(url, bytes);
    } catch (e) {
      // Ignore prefetch errors in background
    }
  }

  /// Updates active controllers based on the current scroll index.
  /// Instantiates at most 3 controllers, recycling idle controllers
  /// using URL swapping rather than disposing and recreating them.
  Future<void> updateActiveIndex(int currentIndex) async {
    _nextIndexToUpdate = currentIndex;
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

    // Background prefetching: Prefetch the next 2 upcoming videos (currentIndex + 2, currentIndex + 3)
    if (currentIndex + 2 < urls.length) {
      prefetch(urls[currentIndex + 2]);
    }
    if (currentIndex + 3 < urls.length) {
      prefetch(urls[currentIndex + 3]);
    }

    // 2. See which desired URLs already have controllers
    final urlsToAssign = desiredUrls.where((url) => !_activeControllers.containsKey(url)).toList();

    // 3. Find controllers that are no longer needed in the active set
    final idleUrls = _activeControllers.keys.where((url) => !desiredUrls.contains(url)).toList();
    final idleControllers = idleUrls.map((url) => _activeControllers[url]!).toList();

    // 4. Recycle idle controllers or create new ones if pool is not full
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

    // 5. Play the current index and pause the other active ones
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
    _activeControllers.clear();
    for (final controller in _pool) {
      await controller.dispose();
    }
    _pool.clear();
    super.dispose();
  }
}
