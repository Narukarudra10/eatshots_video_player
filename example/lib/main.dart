import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:video_view_player/video_view_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eatshots Video Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2F6D), // Vibrant hot pink
          secondary: Color(0xFF00F2FE), // Sleek cyan
          surface: Color(0xFF121212),
        ),
      ),
      home: const FeedScreen(),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // 8 highly reliable public test video URLs (GitHub & W3Schools)
  final List<String> _videoUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://www.w3schools.com/html/mov_bbb.mp4',
    'https://www.w3schools.com/html/movie.mp4',
    'https://github.com/intel-iot-devkit/sample-videos/raw/master/car-detection.mp4',
    'https://github.com/intel-iot-devkit/sample-videos/raw/master/bottle-detection.mp4',
    'https://github.com/intel-iot-devkit/sample-videos/raw/master/store-aisle-detection.mp4',
    'https://github.com/intel-iot-devkit/sample-videos/raw/master/people-detection.mp4',
  ];

  late VideoViewPlayerPoolManager _poolManager;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _showDebug = true;

  @override
  void initState() {
    super.initState();
    _poolManager = VideoViewPlayerPoolManager(urls: _videoUrls);
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
    setState(() {
      _currentIndex = index;
    });
    _poolManager.updateActiveIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VideoViewPlayerPoolManager>.value(
      value: _poolManager,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'EatShots',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          titleSpacing: 0,
          actions: [
            IconButton(
              icon: Icon(
                _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                color: _showDebug ? Theme.of(context).colorScheme.secondary : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showDebug = !_showDebug;
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Vertical PageView for short-form feed
            PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              itemCount: _videoUrls.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final url = _videoUrls[index];
                return FeedItemWidget(
                  url: url,
                  index: index,
                  isActive: index == _currentIndex,
                );
              },
            ),

            // Floating Adaptive Network HUD
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const NetworkHudWidget(),
                  ),
                ),
              ),
            ),

            // Pool Controller Debug Overlay positioned higher up to avoid overlapping bottom controls
            if (_showDebug)
              Positioned(
                bottom: 220,
                left: 16,
                right: 80,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: DebugPoolStatsWidget(urls: _videoUrls),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DebugPoolStatsWidget extends StatelessWidget {
  final List<String> urls;

  const DebugPoolStatsWidget({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    final poolManager = Provider.of<VideoViewPlayerPoolManager>(context);

    // List of active controllers to merge listeners
    final activeControllers = urls
        .map((url) => poolManager.getControllerForUrl(url))
        .where((c) => c != null)
        .cast<VideoViewPlayerController>()
        .toList();

    return AnimatedBuilder(
      animation: Listenable.merge(activeControllers),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'POOL MONITOR (3-Player Rule)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00F2FE),
                  ),
                ),
                Text(
                  'Active: ${activeControllers.length}/3',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 8),
            ...activeControllers.map((controller) {
              final state = controller.value;
              final isPlayingThis = state.isPlaying;
              final shortUrl = controller.dataSource.split('/').last;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      isPlayingThis ? Icons.play_arrow : Icons.pause,
                      size: 12,
                      color: isPlayingThis ? const Color(0xFFFF2F6D) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'ID: ${controller.textureId} • $shortUrl',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      state.isInitialized
                          ? '${state.position.inSeconds}s/${state.duration.inSeconds}s'
                          : 'Initializing...',
                      style: TextStyle(
                        fontSize: 9,
                        color: state.isInitialized ? Colors.white60 : Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class FeedItemWidget extends StatefulWidget {
  final String url;
  final int index;
  final bool isActive;

  const FeedItemWidget({
    super.key,
    required this.url,
    required this.index,
    required this.isActive,
  });

  @override
  State<FeedItemWidget> createState() => _FeedItemWidgetState();
}

class _FeedItemWidgetState extends State<FeedItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimController;
  bool _showHeartOverlay = false;
  double _heartScale = 0.0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        setState(() {
          final t = _heartAnimController.value;
          if (t < 0.3) {
            _heartScale = (t / 0.3) * 1.2;
          } else if (t < 0.6) {
            _heartScale = 1.2 - ((t - 0.3) / 0.3) * 0.2;
          } else if (t < 0.9) {
            _heartScale = 1.0;
          } else {
            _heartScale = 1.0 - ((t - 0.9) / 0.1);
          }
        });
      });
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    setState(() {
      _isLiked = true;
      _showHeartOverlay = true;
    });
    _heartAnimController.reset();
    _heartAnimController.forward().then((_) {
      setState(() {
        _showHeartOverlay = false;
      });
    });
  }

  Widget _buildBottomAction({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poolManager = Provider.of<VideoViewPlayerPoolManager>(context);
    final controller = poolManager.getControllerForUrl(widget.url);

    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return ListenableProvider<VideoViewPlayerController>.value(
      value: controller,
      child: GestureDetector(
        onTap: () {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        },
        onDoubleTap: _onDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Video Content (Independent sub-widget to optimize rebuilds)
            const VideoPlayerSurface(),

            // 2. Play/Pause Overlay Indicator
            const CenterPlayPauseOverlay(),

            // 3. Buffering Indicator
            const BufferingOverlay(),

            // 4. Double Tap Heart Animation Overlay
            if (_showHeartOverlay)
              Center(
                child: Transform.scale(
                  scale: _heartScale,
                  child: const Icon(
                    Icons.favorite,
                    size: 110,
                    color: Color(0xFFFF2F6D),
                  ),
                ),
              ),

            // 5. Bottom Gradient Shadow
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 250,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 6. Creator Info, Caption, Progress Bar, and Bottom Navigation Action Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator Profile and Name Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(
                                widget.index % 2 == 0
                                    ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'
                                    : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&auto=format&fit=crop&q=80',
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Mohd Mizna Ansari',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D26A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Follow',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Caption / Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      widget.index == 0 ? 'new' : 'shot #${widget.index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Green Progress Bar with thumb
                  const VideoProgressBar(),
                  const SizedBox(height: 4),

                  // Bottom Action Navigation Bar (Solid black background)
                  Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBottomAction(
                            icon: const Text(
                              '👏',
                              style: TextStyle(fontSize: 22),
                            ),
                            label: _isLiked ? '2' : '1',
                            onTap: () {
                              setState(() {
                                _isLiked = !_isLiked;
                              });
                            },
                          ),
                          _buildBottomAction(
                            icon: const Icon(
                              Icons.people_outline_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            label: '1',
                            onTap: () {},
                          ),
                          _buildBottomAction(
                            icon: const Icon(
                              Icons.storefront_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                            label: '1',
                            onTap: () {},
                          ),
                          _buildBottomAction(
                            icon: const Icon(
                              Icons.shortcut_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                            label: '5',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerSurface extends StatelessWidget {
  const VideoPlayerSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<VideoViewPlayerController>(context, listen: false);
    
    // Select specific values to trigger rebuilds only when they change.
    final isInitialized = context.select<VideoViewPlayerController, bool>((c) => c.value.isInitialized);
    final hasError = context.select<VideoViewPlayerController, bool>((c) => c.value.hasError);
    final size = context.select<VideoViewPlayerController, Size>((c) => c.value.size);
    final textureId = context.select<VideoViewPlayerController, int?>((c) => c.textureId);

    debugPrint("VideoPlayerSurface: Build for texture $textureId (isInitialized: $isInitialized, hasError: $hasError, size: $size)");

    if (hasError) {
      final error = context.select<VideoViewPlayerController, String?>((c) => c.value.errorDescription);
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Playback Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown playback issue occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (textureId == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFFF2F6D),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Preparing video stream...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final videoWidth = size.width > 0 ? size.width : 1080.0;
    final videoHeight = size.height > 0 ? size.height : 1920.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: VideoViewPlayer(controller: controller),
            ),
          ),
        ),
        if (!isInitialized)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFFF2F6D),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Preparing video stream...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class CenterPlayPauseOverlay extends StatelessWidget {
  const CenterPlayPauseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isInitialized = context.select<VideoViewPlayerController, bool>((c) => c.value.isInitialized);
    final isPlaying = context.select<VideoViewPlayerController, bool>((c) => c.value.isPlaying);
    final isBuffering = context.select<VideoViewPlayerController, bool>((c) => c.value.isBuffering);
    final hasError = context.select<VideoViewPlayerController, bool>((c) => c.value.hasError);

    if (isInitialized && !isPlaying && !isBuffering && !hasError) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class BufferingOverlay extends StatelessWidget {
  const BufferingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isInitialized = context.select<VideoViewPlayerController, bool>((c) => c.value.isInitialized);
    final isBuffering = context.select<VideoViewPlayerController, bool>((c) => c.value.isBuffering);
    final hasError = context.select<VideoViewPlayerController, bool>((c) => c.value.hasError);

    if (isInitialized && isBuffering && !hasError) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00D26A),
          strokeWidth: 3,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class VideoProgressBar extends StatelessWidget {
  const VideoProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isInitialized = context.select<VideoViewPlayerController, bool>((c) => c.value.isInitialized);
    final position = context.select<VideoViewPlayerController, Duration>((c) => c.value.position);
    final duration = context.select<VideoViewPlayerController, Duration>((c) => c.value.duration);

    if (!isInitialized || duration.inMilliseconds <= 0) {
      return const SizedBox(height: 8);
    }

    final progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbSize = 12.0;
        final thumbLeft = progress * (width - thumbSize);

        return Container(
          height: 12,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Track (Gray line)
              Container(
                height: 2.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(1.0),
                ),
              ),
              // Active Track (Green line)
              Container(
                height: 2.0,
                width: progress * width,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D26A),
                  borderRadius: BorderRadius.circular(1.0),
                ),
              ),
              // Thumb (Green dot)
              Positioned(
                left: thumbLeft,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D26A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NetworkHudWidget extends StatelessWidget {
  const NetworkHudWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final poolManager = Provider.of<VideoViewPlayerPoolManager>(context);
    final netType = poolManager.effectiveNetworkType;
    final isSimulated = poolManager.simulatedNetworkType != null;

    IconData netIcon;
    Color iconColor;
    String qualityText;
    String prefetchText;
    const String latencyText = "Zero-Delay Playback";

    switch (netType) {
      case 'WIFI':
        netIcon = Icons.wifi_rounded;
        iconColor = const Color(0xFF00F2FE); // Cyan
        qualityText = "1080p Ultra HD (Original)";
        prefetchText = "1.5MB prefetch • 2 videos ahead";
        break;
      case '5G':
        netIcon = Icons.bolt_rounded;
        iconColor = const Color(0xFFFFCC00); // Amber/Yellow
        qualityText = "1080p High Quality";
        prefetchText = "1.5MB prefetch • 2 videos ahead";
        break;
      case '4G':
        netIcon = Icons.four_g_mobiledata_rounded;
        iconColor = const Color(0xFFFF2F6D); // Pink
        qualityText = "720p Balanced HD";
        prefetchText = "384KB prefetch • 1 video ahead";
        break;
      default:
        netIcon = Icons.signal_cellular_connected_no_internet_4_bar_rounded;
        iconColor = Colors.grey;
        qualityText = "480p Data Saver";
        prefetchText = "128KB prefetch • 1 video ahead";
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(netIcon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'NETWORK QUALITY: ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        isSimulated ? '$netType (Simulated)' : netType,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    qualityText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String?>(
              tooltip: "Simulate Network Speed",
              icon: Icon(Icons.settings_input_antenna_rounded, color: Colors.white.withValues(alpha: 0.8)),
              onSelected: (val) {
                poolManager.simulatedNetworkType = val;
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.autorenew_rounded, color: Colors.cyan),
                      SizedBox(width: 8),
                      Text("Auto-Detect Network"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'WIFI',
                  child: Row(
                    children: [
                      Icon(Icons.wifi_rounded, color: Colors.lightGreenAccent),
                      SizedBox(width: 8),
                      Text("Simulate Wi-Fi"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '5G',
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.yellowAccent),
                      SizedBox(width: 8),
                      Text("Simulate 5G Mobile"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '4G',
                  child: Row(
                    children: [
                      Icon(Icons.four_g_mobiledata_rounded, color: Colors.pinkAccent),
                      SizedBox(width: 8),
                      Text("Simulate 4G Data Saver"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '3G',
                  child: Row(
                    children: [
                      Icon(Icons.network_check_rounded, color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      Text("Simulate 3G Poor Speed"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prefetchText,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D26A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    latencyText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D26A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
