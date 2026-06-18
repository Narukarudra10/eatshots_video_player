# eatshots_video_player

[![pub package](https://img.shields.io/pub/v/eatshots_video_player.svg)](https://pub.dev/packages/eatshots_video_player)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20macos-lightgrey.svg)](https://pub.dev/packages/eatshots_video_player)

A premium, high-performance, Reels/TikTok-style short-form video player plugin for Flutter. Optimized at the native layer with aggressive caching, connection-aware background prefetching, and native controller pooling to deliver zero-lag vertical scrolling feeds.

---

## ❤️ Support the Project

If you love using this package and find it helpful, please support it!
* **Like it** on [pub.dev](https://pub.dev/packages/eatshots_video_player)
* **Star** the repository on [GitHub](https://github.com/Narukarudra10/eatshots_video_player)

Your support helps keep this project active and updated!

---

## ⚡ Why eatshots_video_player?

Standard Flutter video players (like the official `video_player` package) are designed for single-video or long-form playback. When used in rapid vertical scrolling feeds, they suffer from:
- **High Startup Latency:** Default players buffer 2.5+ seconds of video before starting playback, creating a noticeable delay when swiping.
- **Decoder Overhead:** Constantly initializing and disposing of native player instances causes CPU spikes, frame drops, and memory leaks.
- **Race Conditions:** Fast scrolling triggers overlapping asynchronous initialization/disposal loops, causing native-level crashes.

`eatshots_video_player` resolves these performance bottlenecks by optimizing the playback pipeline directly at the native layer (using Android Media3 ExoPlayer and iOS AVFoundation).

---

## ✨ Key Engineering Achievements

### 1. Zero-Lag Startup Latency (Buffer Tuning)
We tuned ExoPlayer's `DefaultLoadControl` on Android to reduce the initial startup buffer to **500ms** (down from 2.5s). Additionally, the `DefaultRenderersFactory` skips unnecessary software extension checks, utilizing hardware decoders instantly. This results in near-instantaneous playback on swipe.

### 2. Native Controller Pooling (The 3-Player Rule)
Instead of destroying and recreating players on scroll, the package maintains a maximum of **3 active controller instances** (previous, current, next). When scrolling, idle decoders are reused by swapping the media datasource under the hood rather than disposing of the player, keeping CPU and memory usage extremely low.

### 3. Concurrency & Fast-Scroll Guards
Rapid scrolling is shielded from race conditions via a sequential update queue in `EatshotsVideoPlayerPoolManager`. The queue serializes active updates and skips intermediate video sources if the user scrolls past them quickly, preventing decoder races and native-level crashes.

### 4. Connection-Aware Adaptive Prefetching
The pool manager dynamically adjusts prefetch parameters based on the device's connection quality:
* **WIFI / 5G:** Prefetches **1.5 MB** of media for the next **2** videos.
* **4G:** Prefetches **384 KB** for the next **1** video.
* **3G / Slow Network:** Prefetches **128 KB** for the next **1** video.
* Prefetch tasks are automatically cancelled if the user scrolls in a different direction.

### 5. Aggressive Caching & Offline Support
Utilizes ExoPlayer's `SimpleCache` (Android) and system-level HTTP caching (iOS) to store video chunks locally. Replaying a video requires zero network requests, saving bandwidth and enabling offline support.

---

## 🚀 Getting Started

### 1. Add Dependency

Add `eatshots_video_player` to your `pubspec.yaml`:

```yaml
dependencies:
  eatshots_video_player: ^0.1.7
```

### 2. Import

```dart
import 'package:eatshots_video_player/eatshots_video_player.dart';
```

---

## 📖 Usage Examples

### Example 1: Basic Video Playback
For playing a single video, initialize the controller and pass it to the player widget:

```dart
class SingleVideoScreen extends StatefulWidget {
  const SingleVideoScreen({super.key});

  @override
  State<SingleVideoScreen> createState() => _SingleVideoScreenState();
}

class _SingleVideoScreenState extends State<SingleVideoScreen> {
  late EatshotsVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Support asset, file, or network sources
    _controller = EatshotsVideoPlayerController.asset('assets/my_video.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });

    // Operations called before initialization completes are safely buffered
    _controller.setLooping(true);
    _controller.setVolume(1.0);
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: EatshotsVideoPlayer(controller: _controller),
    );
  }
}
```

### Example 2: Reels/TikTok-Style Vertical Feed (Advanced)
Use `EatshotsVideoPlayerPoolManager` along with a vertical `PageView` to achieve a high-performance scrolling feed:

```dart
class ShortFeedScreen extends StatefulWidget {
  const ShortFeedScreen({super.key});

  @override
  State<ShortFeedScreen> createState() => _ShortFeedScreenState();
}

class _ShortFeedScreenState extends State<ShortFeedScreen> {
  final List<String> _videoUrls = [
    'https://example.com/video1.mp4',
    'https://example.com/video2.mp4',
    'https://example.com/video3.mp4',
  ];

  late EatshotsVideoPlayerPoolManager _poolManager;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _poolManager = EatshotsVideoPlayerPoolManager(urls: _videoUrls);
    
    // Initialize the pool at page 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _poolManager.updateActiveIndex(0);
    });
  }

  @override
  void dispose() {
    _poolManager.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Automatically prefetch, recycle players, play current, and pause others
    _poolManager.updateActiveIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _videoUrls.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final url = _videoUrls[index];
        
        // Listen to the pool manager for controller updates
        return AnimatedBuilder(
          animation: _poolManager,
          builder: (context, _) {
            final controller = _poolManager.getControllerForUrl(url);

            if (controller == null || !controller.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.pink),
              );
            }

            return FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: EatshotsVideoPlayer(controller: controller),
              ),
            );
          },
        );
      },
    );
  }
}
```

---

## 🛠️ API Reference

### `EatshotsVideoPlayerController`
Main controller class managing player states and native interactions.

| Method / Property | Description |
|---|---|
| `EatshotsVideoPlayerController(String dataSource)` | Creates a controller with a custom datasource URL. |
| `EatshotsVideoPlayerController.networkUrl(Uri url)` | Named constructor for network video URLs. |
| `EatshotsVideoPlayerController.asset(String asset)` | Named constructor for Flutter app assets. |
| `EatshotsVideoPlayerController.file(dynamic file)` | Named constructor for local files. |
| `initialize()` | Resolves the native texture and prepares the media decoder. |
| `play()` | Starts or resumes video playback. |
| `pause()` | Pauses video playback. |
| `seekTo(Duration position)` | Seeks to a specific timestamp in the video. |
| `setVolume(double volume)` | Sets player volume (`0.0` - `1.0`). Safely buffers before init. |
| `setLooping(bool looping)` | Toggles seamless playback loop. Safely buffers before init. |
| `setPlaybackSpeed(double speed)` | Modifies playback speed (e.g. `1.0`, `1.5`, `2.0`). |
| `setDataSource(String url)` | Swaps the video source without destroying the native decoder (recycles instance). |
| `dispose()` | Cleans up the native player, events channel, and texture bindings. |

### `EatshotsVideoValue`
Exposes the reactive state of a player instance via `ValueNotifier`.

| Property | Type | Description |
|---|---|---|
| `duration` | `Duration` | Total duration of the video. |
| `position` | `Duration` | Current playback position. |
| `size` | `Size` | Resolution of the video (width & height). |
| `isInitialized` | `bool` | True if the native player has parsed metadata and is ready. |
| `isPlaying` | `bool` | True if the video is currently playing. |
| `isBuffering` | `bool` | True if the video is waiting for network buffer. |
| `isLooping` | `bool` | True if the video loops. |
| `hasError` | `bool` | True if a playback error has occurred. |
| `errorDescription`| `String?` | Error description details, if any. |
| `aspectRatio` | `double` | Pre-calculated aspect ratio (defaults to `9/16` if uninitialized). |

### `EatshotsVideoPlayerPoolManager`
Manages native video player recycling, caching, and network-aware prefetching.

| Method / Property | Type / Description |
|---|---|
| `EatshotsVideoPlayerPoolManager({required List<String> urls})` | Creates a pool manager managing the complete list of feed URLs. |
| `updateActiveIndex(int currentIndex)` | Tells the manager to shift the active playing index, trigger recycling, and adapt prefetching. |
| `getControllerForUrl(String url)` | Returns `EatshotsVideoPlayerController?` for a URL if it's currently loaded in the pool. |
| `prefetch(String url, {required int bytes})` | Explicitly triggers background prefetching of the first `bytes` of a video. |
| `dispose()` | Disposes all players in the pool and releases event channels. |

---

## 📱 Platform Support

* **Android:** Native player implementation via Media3 ExoPlayer.
* **iOS:** High-fidelity playback via AVFoundation.
* **macOS:** Premium desktop playback via AVFoundation.



