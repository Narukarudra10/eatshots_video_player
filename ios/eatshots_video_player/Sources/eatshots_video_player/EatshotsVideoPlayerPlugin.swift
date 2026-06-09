import Flutter
import UIKit
import AVFoundation
import Network
import CoreTelephony

public class EatshotsVideoPlayerPlugin: NSObject, FlutterPlugin {
  private let registry: FlutterTextureRegistry
  private let messenger: FlutterBinaryMessenger
  private let registrar: FlutterPluginRegistrar
  private var players: [Int64: EatshotsVideoPlayer] = [:]
  
  private let monitor = NWPathMonitor()
  private var currentConnectionType = "WIFI"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "eatshots_video_player", binaryMessenger: registrar.messenger())
    let instance = EatshotsVideoPlayerPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(registrar: FlutterPluginRegistrar) {
    self.registry = registrar.textures()
    self.messenger = registrar.messenger()
    self.registrar = registrar
    super.init()
    
    // Start network monitor
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self = self else { return }
      if path.status == .satisfied {
        if path.usesInterfaceType(.wifi) {
          self.currentConnectionType = "WIFI"
        } else if path.usesInterfaceType(.wiredEthernet) {
          self.currentConnectionType = "WIFI"
        } else if path.usesInterfaceType(.cellular) {
          let teleInfo = CTTelephonyNetworkInfo()
          if #available(iOS 14.1, *) {
            if let activeDataId = teleInfo.dataServiceIdentifier,
               let carrierInfo = teleInfo.serviceCurrentRadioAccessTechnology,
               let tech = carrierInfo[activeDataId] {
              if tech == CTRadioAccessTechnologyNR || tech == CTRadioAccessTechnologyNRNSA {
                self.currentConnectionType = "5G"
              } else {
                self.currentConnectionType = "4G"
              }
            } else {
              self.currentConnectionType = "4G"
            }
          } else {
            self.currentConnectionType = "4G"
          }
        } else {
          self.currentConnectionType = "NONE"
        }
      } else {
        self.currentConnectionType = "NONE"
      }
    }
    monitor.start(queue: DispatchQueue.global(qos: .background))
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initialize":
      guard let urlString = args?["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "URL is invalid", details: nil))
        return
      }
      
      let textureId = registry.register(nil)
      let player = EatshotsVideoPlayer(
        url: url,
        textureId: textureId,
        registry: registry,
        messenger: messenger,
        urlResolver: { [weak self] url in
          guard let self = self else { return url }
          if url.scheme == "asset" {
            let assetKey = url.absoluteString.replacingOccurrences(of: "asset://", with: "")
            let key = self.registrar.lookupKey(forAsset: assetKey)
            if let path = Bundle.main.path(forResource: key, ofType: nil) {
              return URL(fileURLWithPath: path)
            }
          }
          return url
        }
      )
      players[textureId] = player
      registry.textureFrameAvailable(textureId)
      result(textureId)
      
    case "play":
      guard let textureId = args?["textureId"] as? Int64,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.play()
      result(nil)
      
    case "pause":
      guard let textureId = args?["textureId"] as? Int64,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.pause()
      result(nil)
      
    case "seekTo":
      guard let textureId = args?["textureId"] as? Int64,
            let position = args?["position"] as? Int64,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.seek(to: position)
      result(nil)
      
    case "setPlaybackSpeed":
      guard let textureId = args?["textureId"] as? Int64,
            let speed = args?["speed"] as? Double,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.setPlaybackSpeed(Float(speed))
      result(nil)
      
    case "setVolume":
      guard let textureId = args?["textureId"] as? Int64,
            let volume = args?["volume"] as? Double,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.setVolume(Float(volume))
      result(nil)
      
    case "setLooping":
      guard let textureId = args?["textureId"] as? Int64,
            let looping = args?["looping"] as? Bool,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.setLooping(looping)
      result(nil)
      
    case "getPosition":
      guard let textureId = args?["textureId"] as? Int64,
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      result(player.getPosition())
      
    case "setDataSource":
      guard let textureId = args?["textureId"] as? Int64,
            let urlString = args?["url"] as? String,
            let url = URL(string: urlString),
            let player = players[textureId] else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found or invalid URL", details: nil))
        return
      }
      player.setDataSource(url)
      result(nil)
      
    case "prefetch":
      // iOS prefetching is handled by the default URL cache and AVPlayerItem buffering
      // Nothing special needed here unless aggressive pre-downloads are requested
      result(nil)
      
    case "cancelPrefetch":
      result(nil)
      
    case "getNetworkType":
      result(currentConnectionType)
      
    case "dispose":
      guard let textureId = args?["textureId"] as? Int64,
            let player = players.removeValue(forKey: textureId) else {
        result(FlutterError(code: "NOT_FOUND", message: "Player not found", details: nil))
        return
      }
      player.dispose()
      registry.unregisterTexture(textureId)
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

class EatshotsVideoPlayer: NSObject, FlutterTexture, FlutterStreamHandler {
  private let textureId: Int64
  private weak var registry: FlutterTextureRegistry?
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?
  private var videoOutput: AVPlayerItemVideoOutput?
  private var displayLink: CADisplayLink?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  
  private var isInitialized = false
  private var isBuffering = false
  private var playbackSpeed: Float = 1.0
  private var isLooping = true
  private let urlResolver: (URL) -> URL
  
  init(url: URL, textureId: Int64, registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger, urlResolver: @escaping (URL) -> URL) {
    self.textureId = textureId
    self.registry = registry
    self.urlResolver = urlResolver
    super.init()
    
    setupPlayer(url: url)
    
    self.eventChannel = FlutterEventChannel(name: "eatshots_video_player/videoEvents_\(textureId)", binaryMessenger: messenger)
    self.eventChannel?.setStreamHandler(self)
    
    // Registry self as the texture provider
    registry.register(self)
    
    self.displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
    self.displayLink?.add(to: .main, forMode: .common)
    self.displayLink?.isPaused = true
  }

  private func setupPlayer(url: URL) {
    let resolvedUrl = urlResolver(url)
    let asset = AVURLAsset(url: resolvedUrl)
    let keys = ["playable", "hasProtectedContent"]
    let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: keys)
    self.playerItem = item
    
    let pixBuffAttributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixBuffAttributes)
    self.videoOutput = output
    item.add(output)
    
    if let player = self.player {
      player.replaceCurrentItem(with: item)
    } else {
      self.player = AVPlayer(playerItem: item)
      self.player?.actionAtItemEnd = .none // loop hander will seek to start
    }
    
    // Add observers
    item.addObserver(self, forKeyPath: "status", options: [.old, .new], context: nil)
    item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.old, .new], context: nil)
    item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.old, .new], context: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
  }

  @objc private func onDisplayLink(_ sender: CADisplayLink) {
    guard let videoOutput = videoOutput else { return }
    let time = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
    if videoOutput.hasNewPixelBuffer(forItemTime: time) {
      registry?.textureFrameAvailable(textureId)
    }
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let videoOutput = videoOutput else { return nil }
    let time = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
    if let buffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
      return Unmanaged.passRetained(buffer)
    }
    return nil
  }

  func play() {
    player?.play()
    player?.rate = playbackSpeed
    displayLink?.isPaused = false
  }

  func pause() {
    player?.pause()
    displayLink?.isPaused = true
  }

  func seek(to positionMs: Int64) {
    let time = CMTimeMake(value: positionMs, timescale: 1000)
    player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  func setPlaybackSpeed(_ speed: Float) {
    playbackSpeed = speed
    if player?.rate != 0 {
      player?.rate = speed
    }
  }

  func setVolume(_ volume: Float) {
    player?.volume = volume
  }

  func setLooping(_ looping: Bool) {
    isLooping = looping
  }

  func getPosition() -> Int64 {
    guard let player = player else { return 0 }
    let time = player.currentTime()
    return CMTIME_IS_INVALID(time) ? 0 : Int64(CMTimeGetSeconds(time) * 1000)
  }

  func setDataSource(_ url: URL) {
    isInitialized = false
    isBuffering = false
    
    // Clean up current item observers
    if let currentItem = playerItem {
      currentItem.removeObserver(self, forKeyPath: "status")
      currentItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
      currentItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
    }
    
    setupPlayer(url: url)
  }

  @objc private func itemDidPlayToEndTime(_ notification: Notification) {
    if isLooping {
      // Loop automatically for short-form feed
      seek(to: 0)
      player?.play()
      player?.rate = playbackSpeed
    }
    eventSink?(["event": "completed"])
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    guard let item = object as? AVPlayerItem, item == playerItem else { return }
    
    if keyPath == "status" {
      if item.status == .readyToPlay {
        if !isInitialized {
          isInitialized = true
          let duration = item.duration
          let durationMs = CMTIME_IS_INVALID(duration) ? 0 : Int64(CMTimeGetSeconds(duration) * 1000)
          let size = item.presentationSize
          
          eventSink?([
            "event": "initialized",
            "duration": durationMs,
            "width": Int(size.width),
            "height": Int(size.height)
          ])
        }
      } else if item.status == .failed {
        let error = item.error?.localizedDescription ?? "AVPlayerItem failed"
        eventSink?([
          "event": "error",
          "errorDescription": error
        ])
      }
    } else if keyPath == "playbackBufferEmpty" {
      if item.isPlaybackBufferEmpty {
        isBuffering = true
        eventSink?(["event": "bufferingStart"])
      }
    } else if keyPath == "playbackLikelyToKeepUp" {
      if item.isPlaybackLikelyToKeepUp {
        isBuffering = false
        eventSink?(["event": "bufferingEnd"])
      }
    }
  }

  // Stream handler
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    if isInitialized, let item = playerItem {
      let duration = item.duration
      let durationMs = CMTIME_IS_INVALID(duration) ? 0 : Int64(CMTimeGetSeconds(duration) * 1000)
      let size = item.presentationSize
      events([
        "event": "initialized",
        "duration": durationMs,
        "width": Int(size.width),
        "height": Int(size.height)
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  func dispose() {
    displayLink?.invalidate()
    displayLink = nil
    
    eventChannel?.setStreamHandler(nil)
    eventChannel = nil
    eventSink = nil
    
    if let item = playerItem {
      item.removeObserver(self, forKeyPath: "status")
      item.removeObserver(self, forKeyPath: "playbackBufferEmpty")
      item.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
    }
    
    player?.pause()
    player = nil
    playerItem = nil
    videoOutput = nil
  }
}
