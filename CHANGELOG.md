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

