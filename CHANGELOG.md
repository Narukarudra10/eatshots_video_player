## 0.1.5

* iOS Xcode Build Fix:
  * Resolved Swift compilation error (`'nil' is not compatible with expected argument type 'any FlutterTexture'`) in `EatshotsVideoPlayerPlugin.swift`.
  * Refactored `EatshotsVideoPlayer` initialization to register the player instance with the texture registry after initialization, matching the macOS plugin implementation pattern.

## 0.1.4

* Native Lifecycle & Log Warning Fixes:
  * Implemented `onActivityPaused` callback inside the Android native Activity callbacks to loop through all active players and trigger a native pause.
  * Added `handleActivityPaused()` in the `EatshotsVideoPlayer` class, which calls `exoPlayer?.playWhenReady = false` to stop frame decoding before the OS suspends the graphics surface rendering, preventing "pipeline full" log warnings.

## 0.1.3

* Android Build Fix:
  * Added missing `android.net.ConnectivityManager` import in `EatshotsVideoPlayerPlugin.kt` to resolve Gradle Kotlin compiler errors.

## 0.1.2

* Connection-Aware Native Caching & Performance Optimizations:
  * Implemented an EventChannel stream (`eatshots_video_player/network_events`) on Android and iOS to broadcast network connection status reactively to Dart.
  * Added native bandwidth estimation using ExoPlayer's `DefaultBandwidthMeter` on Android to dynamically adjust background prefetch sizes based on real-time speeds.
  * Implemented `AVAssetResourceLoaderDelegate` (`EatshotsResourceLoaderDelegate`) in Swift on iOS to cache progressive streaming MP4 videos directly to the local disk caches directory.
  * Optimized ExoPlayer's load control buffering settings for fast startup: reduced initial play buffer to 250ms on Wi-Fi and 500ms on Cellular data.
  * Corrected buffering visibility logic in the video player widget to avoid showing the starting thumbnail during buffer stalls.

## 0.1.1

* Fix diagonal rendering shearing and green lines glitch:
  * Dynamically resize the `SurfaceTexture` default buffer size to match actual video dimensions on Android.
  * Resolves layout/stride mismatch rendering artifacts on certain GPUs (such as Mali and PowerVR) common in Redmi/Xiaomi devices.

## 0.1.0

* Cellular Network Optimization & adaptive zero-delay playback:
  * Added native network connectivity checks (Wi-Fi, 5G, 4G, 3G) using `ConnectivityManager` link bandwidth estimation on Android, and `NWPathMonitor` framework on iOS/macOS.
  * Implemented dynamic ExoPlayer buffer adjustment: fast startup buffers on Wi-Fi (800ms) and safer buffers (2000-3000ms) on cellular to prevent playback stutters under jitter.
  * Implemented active prefetch cancellation when scrolling fast via native `CacheWriter.cancel()`.
  * Added adaptive prefetching sizes and queue depths based on network speeds (1.5MB for Wi-Fi/5G, 384KB for 4G, 128KB for 3G).
  * Added floating glassmorphic Network Quality HUD overlay and simulated connection speed controls in example app.

## 0.0.9

* Optimize video startup latency:
  * Implemented a custom `DefaultLoadControl` reducing the required startup buffer to `500ms` (down from the default `2.5s`), resulting in near-instant playback.
  * Optimized `DefaultRenderersFactory` to skip software extension renderer checks, utilizing the platform hardware decoders immediately.

## 0.0.8


* Fix Android Media3 setter bug:
  * Initialized `DefaultMediaSourceFactory` using the constructor that accepts the data source factory directly, bypassing a bug in some Media3 versions where `setDataSourceFactory` is ignored.

## 0.0.7


* Fix Android asset playback:
  * Wrapped ExoPlayer's CacheDataSource upstream factory with `DefaultDataSource.Factory`.
  * Resolved `unknown protocol: asset` exception when trying to load local Flutter video assets.

## 0.0.6


* Add macOS platform support:
  * Implemented native macOS video player in Swift using AVFoundation.
  * Used a Swift Timer running at 60fps to drive frame rendering updates.
  * Enabled client network access entitlements in the macOS example runner to allow playing video streams in sandboxed mode.
  * Declared macOS platform support in pubspec.yaml.
* Fix fast-scrolling concurrency crashes:
  * Implemented a coalesced sequential update queue in `EatshotsVideoPlayerPoolManager` to serialize active index updates and skip intermediate indices during fast scrolling.
  * Added an initialization guard to `EatshotsVideoPlayerController.setDataSource` to wait for native player setup to finish before changing data sources, avoiding native decoder races and crashes.

## 0.0.5

* Updated repository and homepage URLs to the correct GitHub path (`Narukarudra10/eatshots_video_player`).
* Updated README dependency reference versions.

## 0.0.4

* Expanded documentation in the README with:
  * Feature overview highlighting native controller pooling, aggressive caching, and background prefetching.
  * API reference documentation for `EatshotsVideoPlayerController`.
  * Detailed usage example code for initialization and playback settings.

## 0.0.3

* Enhanced initialization lifecycle:
  * Added caching of volume, looping, and play states set before native initialization finishes, automatically applying them once the player is ready.
  * Refactored volume, looping, and playback status controls to be resilient to pre-initialization states.

## 0.0.2

* Expanded source capabilities:
  * Added `EatshotsVideoPlayerController.networkUrl`, `.file`, and `.asset` constructors.
  * Added volume controls (`setVolume`) and looping toggles (`setLooping`) in Dart API, platform interface, and Android/iOS native implementations.

## 0.0.1

* Initial release of eatshots_video_player.

