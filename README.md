# eatshots_video_player

A high-performance, Reels-style short-form video player plugin for Flutter. Optimized with aggressive caching, background prefetching, and native controller pooling for zero-lag vertical scrolling feeds.

## Features

- **Native Controller Pooling**: Recycles player instances instead of repeatedly creating/disposing of them, keeping memory and CPU usage extremely low.
- **Aggressive Caching**: Automatically caches video bytes using ExoPlayer's `SimpleCache` (Android) and system-level HTTP caching (iOS).
- **Background Prefetching**: Prefetches upcoming feed videos in the background to ensure instantaneous playback.
- **Robust Controller API**: Control volume, looping, playback, speed, and seek operations at any time (with automatic buffering for calls made before initialization completes).

---

## API Reference

### `EatshotsVideoPlayerController`

The main controller class managing the player's lifecycle and playback states.

| Method | Description |
|---|---|
| `initialize()` | Initializes the native texture and prepares the media source. |
| `play()` | Starts or resumes video playback. |
| `pause()` | Pauses video playback. |
| `seekTo(Duration position)` | Seeks to a specific timestamp in the video. |
| `setVolume(double volume)` | Sets player volume (`0.0` for muted, `1.0` for full volume). Can be called before initialization. |
| `setLooping(bool looping)` | Toggles whether the video should loop seamlessly. Can be called before initialization. |
| `setDataSource(String url)` | Swaps the video datasource on an existing player instance to avoid recreating the decoder. |
| `dispose()` | Cleans up the native player instance, event channel, and textures. |

---

## Getting Started

### 1. Add Dependency

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  eatshots_video_player: ^0.0.4
```

### 2. Basic Usage

Initialize the controller and use the `EatshotsVideoPlayer` widget to display the video:

```dart
import 'package:eatshots_video_player/eatshots_video_player.dart';

class VideoWidget extends StatefulWidget {
  const VideoWidget({super.key});

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late EatshotsVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EatshotsVideoPlayerController.asset('assets/my_video.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });

    // These settings will be safely buffered and applied as soon as the player is ready
    _controller.setLooping(false);
    _controller.setVolume(0.0);
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
