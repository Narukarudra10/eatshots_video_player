package com.example.eatshots_video_player

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.Surface
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

@OptIn(UnstableApi::class)
class EatshotsVideoPlayerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, Application.ActivityLifecycleCallbacks {
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var textureRegistry: TextureRegistry
  private lateinit var binaryMessenger: BinaryMessenger
  private val players = HashMap<Long, EatshotsVideoPlayer>()
  private var activity: Activity? = null

  private var networkEventChannel: EventChannel? = null
  private var networkEventSink: EventChannel.EventSink? = null
  private var networkCallback: ConnectivityManager.NetworkCallback? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "eatshots_video_player")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    textureRegistry = flutterPluginBinding.textureRegistry
    binaryMessenger = flutterPluginBinding.binaryMessenger

    networkEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "eatshots_video_player/network_events")
    networkEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
            networkEventSink = sink
            sendNetworkUpdate()
            startNetworkMonitoring()
        }

        override fun onCancel(arguments: Any?) {
            stopNetworkMonitoring()
            networkEventSink = null
        }
    })
  }

  private fun startNetworkMonitoring() {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
    val request = android.net.NetworkRequest.Builder().build()
    networkCallback = object : ConnectivityManager.NetworkCallback() {
      override fun onAvailable(network: android.net.Network) {
        sendNetworkUpdate()
      }
      override fun onLost(network: android.net.Network) {
        sendNetworkUpdate()
      }
      override fun onCapabilitiesChanged(network: android.net.Network, networkCapabilities: android.net.NetworkCapabilities) {
        sendNetworkUpdate()
      }
    }
    try {
      cm.registerNetworkCallback(request, networkCallback!!)
    } catch (e: Exception) {
      android.util.Log.e("EatshotsVideoPlayer", "Failed to register network callback: ${e.message}")
    }
  }

  private fun stopNetworkMonitoring() {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
    networkCallback?.let {
      try {
        cm.unregisterNetworkCallback(it)
      } catch (e: Exception) {
        // Ignore
      }
    }
    networkCallback = null
  }

  private fun sendNetworkUpdate() {
    val handler = android.os.Handler(android.os.Looper.getMainLooper())
    handler.post {
      val type = VideoCache.getNetworkType(context)
      networkEventSink?.success(type)
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        val url = call.argument<String>("url")
        if (url == null) {
          result.error("INVALID_ARGUMENT", "URL cannot be null", null)
          return
        }
        try {
          val textureEntry = textureRegistry.createSurfaceTexture()
          val textureId = textureEntry.id()
          val player = EatshotsVideoPlayer(context, url, textureEntry, binaryMessenger)
          players[textureId] = player
          result.success(textureId)
        } catch (e: Exception) {
          result.error("INITIALIZATION_FAILED", e.message, null)
        }
      }
      "play" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        if (textureId == null) {
          result.error("INVALID_ARGUMENT", "Texture ID cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.play()
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "pause" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        if (textureId == null) {
          result.error("INVALID_ARGUMENT", "Texture ID cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.pause()
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "seekTo" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        val position = call.argument<Number>("position")?.toLong()
        if (textureId == null || position == null) {
          result.error("INVALID_ARGUMENT", "Texture ID and Position cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.seekTo(position)
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "setPlaybackSpeed" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        val speed = call.argument<Number>("speed")?.toDouble()
        if (textureId == null || speed == null) {
          result.error("INVALID_ARGUMENT", "Texture ID and Speed cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.setPlaybackSpeed(speed.toFloat())
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "setVolume" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        val volume = call.argument<Number>("volume")?.toDouble()
        if (textureId == null || volume == null) {
          result.error("INVALID_ARGUMENT", "Texture ID and Volume cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.setVolume(volume.toFloat())
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "setLooping" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        val looping = call.argument<Boolean>("looping")
        if (textureId == null || looping == null) {
          result.error("INVALID_ARGUMENT", "Texture ID and Looping cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.setLooping(looping)
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "getPosition" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        if (textureId == null) {
          result.error("INVALID_ARGUMENT", "Texture ID cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          result.success(player.getPosition())
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "setDataSource" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        val url = call.argument<String>("url")
        if (textureId == null || url == null) {
          result.error("INVALID_ARGUMENT", "Texture ID and URL cannot be null", null)
          return
        }
        val player = players[textureId]
        if (player != null) {
          player.setDataSource(url)
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      "prefetch" -> {
        val url = call.argument<String>("url")
        val bytes = call.argument<Number>("bytes")?.toLong() ?: (1024 * 1024L) // default 1MB
        if (url == null) {
          result.error("INVALID_ARGUMENT", "URL cannot be null for prefetch", null)
          return
        }
        VideoCache.prefetch(context, url, bytes)
        result.success(null)
      }
      "cancelPrefetch" -> {
        val url = call.argument<String>("url")
        if (url == null) {
          result.error("INVALID_ARGUMENT", "URL cannot be null for cancelPrefetch", null)
          return
        }
        VideoCache.cancelPrefetch(url)
        result.success(null)
      }
      "getNetworkType" -> {
        result.success(VideoCache.getNetworkType(context))
      }
      "dispose" -> {
        val textureId = call.argument<Number>("textureId")?.toLong()
        if (textureId == null) {
          result.error("INVALID_ARGUMENT", "Texture ID cannot be null", null)
          return
        }
        val player = players.remove(textureId)
        if (player != null) {
          player.dispose()
          result.success(null)
        } else {
          result.error("NOT_FOUND", "Player not found for texture ID: $textureId", null)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    networkEventChannel?.setStreamHandler(null)
    networkEventChannel = null
    stopNetworkMonitoring()
    for (player in players.values) {
      player.dispose()
    }
    players.clear()
  }

  // Activity Lifecycle handling to recover Surface when returning from background
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activity?.application?.registerActivityLifecycleCallbacks(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity?.application?.unregisterActivityLifecycleCallbacks(this)
    activity = null
  }

  override fun onActivityResumed(a: Activity) {
    if (a == activity) {
      for (player in players.values) {
        player.handleActivityResumed()
      }
    }
  }

  override fun onActivityCreated(a: Activity, savedInstanceState: Bundle?) {}
  override fun onActivityStarted(a: Activity) {}
  override fun onActivityPaused(a: Activity) {}
  override fun onActivityStopped(a: Activity) {}
  override fun onActivitySaveInstanceState(a: Activity, outState: Bundle) {}
  override fun onActivityDestroyed(a: Activity) {}
}

@OptIn(UnstableApi::class)
class EatshotsVideoPlayer(
    private val context: Context,
    url: String,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry,
    binaryMessenger: BinaryMessenger
) {
    private var exoPlayer: ExoPlayer? = null
    private var surface: Surface? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isInitialized = false
    private var videoWidth = 0
    private var videoHeight = 0
    private var isBuffering = false

    init {
        val textureId = textureEntry.id()
        eventChannel = EventChannel(binaryMessenger, "eatshots_video_player/videoEvents_$textureId")
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                if (isInitialized && exoPlayer != null) {
                    sendInitializedEvent()
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        val surfaceTexture = textureEntry.surfaceTexture()
        surfaceTexture.setDefaultBufferSize(1080, 1920)
        surface = Surface(surfaceTexture)

        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36")
            .setAllowCrossProtocolRedirects(true)
            .setTransferListener(VideoCache.getBandwidthMeter(context))

        val cacheDataSourceFactory = CacheDataSource.Factory()
            .setCache(VideoCache.getCache(context))
            .setUpstreamDataSourceFactory(httpDataSourceFactory)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)

        val defaultDataSourceFactory = DefaultDataSource.Factory(context, cacheDataSourceFactory)

        android.util.Log.d("EatshotsVideoPlayer", "EatshotsVideoPlayer init: URL=$url, defaultDataSourceFactory=$defaultDataSourceFactory")

        val mediaSourceFactory = DefaultMediaSourceFactory(defaultDataSourceFactory)

        val networkType = VideoCache.getNetworkType(context)
        val isHighSpeed = networkType == "WIFI" || networkType == "5G"
        
        val minBufferMs = if (isHighSpeed) 3000 else 5000
        val maxBufferMs = if (isHighSpeed) 8000 else 10000
        val bufferForPlaybackMs = if (isHighSpeed) 250 else 500
        val bufferForPlaybackAfterRebufferMs = 1000

        android.util.Log.d("EatshotsVideoPlayer", "EatshotsVideoPlayer init: URL=$url, NetworkType=$networkType, Buffers=[min:$minBufferMs, max:$maxBufferMs, play:$bufferForPlaybackMs, rebuffer:$bufferForPlaybackAfterRebufferMs]")

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                minBufferMs,
                maxBufferMs,
                bufferForPlaybackMs,
                bufferForPlaybackAfterRebufferMs
            )
            .build()

        exoPlayer = ExoPlayer.Builder(context, renderersFactory)
            .setMediaSourceFactory(mediaSourceFactory)
            .setLoadControl(loadControl)
            .build().apply {
                setVideoSurface(surface)
                repeatMode = Player.REPEAT_MODE_ONE

                addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(playbackState: Int) {
                        when (playbackState) {
                            Player.STATE_BUFFERING -> {
                                isBuffering = true
                                eventSink?.success(mapOf("event" to "bufferingStart"))
                            }
                            Player.STATE_READY -> {
                                if (isBuffering) {
                                    isBuffering = false
                                    eventSink?.success(mapOf("event" to "bufferingEnd"))
                                }
                                if (!isInitialized) {
                                    isInitialized = true
                                    sendInitializedEvent()
                                }
                            }
                            Player.STATE_ENDED -> {
                                eventSink?.success(mapOf("event" to "completed"))
                            }
                            Player.STATE_IDLE -> {
                                // Do nothing
                            }
                        }
                    }

                    override fun onVideoSizeChanged(videoSize: VideoSize) {
                        videoWidth = videoSize.width
                        videoHeight = videoSize.height
                        if (videoWidth > 0 && videoHeight > 0) {
                            try {
                                textureEntry.surfaceTexture().setDefaultBufferSize(videoWidth, videoHeight)
                            } catch (e: Exception) {
                                android.util.Log.e("EatshotsVideoPlayer", "Failed to set default buffer size", e)
                            }
                        }
                        if (isInitialized && videoWidth > 0 && videoHeight > 0) {
                            sendInitializedEvent()
                        }
                    }

                    override fun onPlayerError(error: PlaybackException) {
                        eventSink?.success(mapOf(
                            "event" to "error",
                            "errorCode" to error.errorCode,
                            "errorDescription" to (error.message ?: "Unknown ExoPlayer error")
                        ))
                    }
                })

                val mediaItem = getMediaItemForUrl(url)
                setMediaItem(mediaItem)
                prepare()
            }
    }

    private fun sendInitializedEvent() {
        val player = exoPlayer ?: return
        val duration = player.duration
        val event = mapOf(
            "event" to "initialized",
            "duration" to if (duration == androidx.media3.common.C.TIME_UNSET || duration < 0) 0 else duration,
            "width" to videoWidth,
            "height" to videoHeight
        )
        eventSink?.success(event)
    }

    fun play() {
        exoPlayer?.playWhenReady = true
    }

    fun pause() {
        exoPlayer?.playWhenReady = false
    }

    fun seekTo(positionMs: Long) {
        exoPlayer?.seekTo(positionMs)
    }

    fun setPlaybackSpeed(speed: Float) {
        exoPlayer?.playbackParameters = PlaybackParameters(speed)
    }

    fun setVolume(volume: Float) {
        exoPlayer?.volume = volume
    }

    fun setLooping(looping: Boolean) {
        exoPlayer?.repeatMode = if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    fun getPosition(): Long {
        return exoPlayer?.currentPosition ?: 0L
    }

    private fun getMediaItemForUrl(url: String): MediaItem {
        val resolvedUrl = if (url.startsWith("asset://")) {
            val assetKey = url.substring("asset://".length)
            "asset:///flutter_assets/$assetKey"
        } else {
            url
        }
        return MediaItem.fromUri(resolvedUrl)
    }

    fun setDataSource(url: String) {
        exoPlayer?.apply {
            stop()
            clearMediaItems()
            isInitialized = false
            videoWidth = 0
            videoHeight = 0
            val mediaItem = getMediaItemForUrl(url)
            setMediaItem(mediaItem)
            prepare()
        }
    }

    fun handleActivityResumed() {
        val surfaceTexture = textureEntry.surfaceTexture()
        surface?.release()
        surface = Surface(surfaceTexture)
        exoPlayer?.setVideoSurface(surface)
    }

    fun dispose() {
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null

        exoPlayer?.stop()
        exoPlayer?.release()
        exoPlayer = null

        surface?.release()
        surface = null
        textureEntry.release()
    }
}