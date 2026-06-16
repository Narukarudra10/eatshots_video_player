import Flutter
import UIKit
import AVFoundation
import Network
import CoreTelephony
import MobileCoreServices
import UniformTypeIdentifiers

public class EatshotsVideoPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let registry: FlutterTextureRegistry
  private let messenger: FlutterBinaryMessenger
  private let registrar: FlutterPluginRegistrar
  private var players: [Int64: EatshotsVideoPlayer] = [:]
  
  private let monitor = NWPathMonitor()
  private var currentConnectionType = "WIFI"
  private var networkEventChannel: FlutterEventChannel?
  private var networkEventSink: FlutterEventSink?

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
    
    let netChannel = FlutterEventChannel(name: "eatshots_video_player/network_events", binaryMessenger: registrar.messenger())
    self.networkEventChannel = netChannel
    netChannel.setStreamHandler(self)
    
    // Start network monitor
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self = self else { return }
      let newType: String
      if path.status == .satisfied {
        if path.usesInterfaceType(.wifi) {
          newType = "WIFI"
        } else if path.usesInterfaceType(.wiredEthernet) {
          newType = "WIFI"
        } else if path.usesInterfaceType(.cellular) {
          let teleInfo = CTTelephonyNetworkInfo()
          if #available(iOS 14.1, *) {
            if let activeDataId = teleInfo.dataServiceIdentifier,
               let carrierInfo = teleInfo.serviceCurrentRadioAccessTechnology,
               let tech = carrierInfo[activeDataId] {
              if tech == CTRadioAccessTechnologyNR || tech == CTRadioAccessTechnologyNRNSA {
                newType = "5G"
              } else {
                newType = "4G"
              }
            } else {
              newType = "4G"
            }
          } else {
            newType = "4G"
          }
        } else {
          newType = "NONE"
        }
      } else {
        newType = "NONE"
      }
      
      self.currentConnectionType = newType
      if let sink = self.networkEventSink {
        DispatchQueue.main.async {
          sink(newType)
        }
      }
    }
    monitor.start(queue: DispatchQueue.global(qos: .background))
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.networkEventSink = events
    events(self.currentConnectionType)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.networkEventSink = nil
    return nil
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
      
      let player = EatshotsVideoPlayer(
        url: url,
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
      
      let textureId = registry.register(player)
      player.setTextureId(textureId)
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
      guard let urlString = args?["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "URL is invalid", details: nil))
        return
      }
      let bytes = args?["bytes"] as? Int ?? (1024 * 1024)
      EatshotsResourceLoaderDelegate.prefetch(url: url, bytes: bytes)
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
  private var textureId: Int64 = -1
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
  private var resourceLoaderDelegate: EatshotsResourceLoaderDelegate? // Strong reference
  private let messenger: FlutterBinaryMessenger
  
  init(url: URL, registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger, urlResolver: @escaping (URL) -> URL) {
    self.registry = registry
    self.messenger = messenger
    self.urlResolver = urlResolver
    super.init()
    
    setupPlayer(url: url)
    
    self.displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
    self.displayLink?.add(to: .main, forMode: .common)
    self.displayLink?.isPaused = true
  }

  func setTextureId(_ textureId: Int64) {
    self.textureId = textureId
    self.eventChannel = FlutterEventChannel(name: "eatshots_video_player/videoEvents_\(textureId)", binaryMessenger: messenger)
    self.eventChannel?.setStreamHandler(self)
  }

  private func setupPlayer(url: URL) {
    let resolvedUrl = urlResolver(url)
    
    let asset: AVURLAsset
    if resolvedUrl.scheme == "http" || resolvedUrl.scheme == "https" {
      if let localUrl = EatshotsResourceLoaderDelegate.getCachedFileUrl(for: resolvedUrl),
         let _ = EatshotsResourceLoaderDelegate.getCachedMeta(for: resolvedUrl) {
        var components = URLComponents(url: resolvedUrl, resolvingAgainstBaseURL: false)
        let origScheme = resolvedUrl.scheme ?? "https"
        components?.scheme = origScheme == "https" ? "eatshotscaches" : "eatshotscache"
        if let customUrl = components?.url {
          asset = AVURLAsset(url: customUrl)
          let delegate = EatshotsResourceLoaderDelegate()
          asset.resourceLoader.setDelegate(delegate, queue: DispatchQueue.global(qos: .userInitiated))
          self.resourceLoaderDelegate = delegate
        } else {
          asset = AVURLAsset(url: resolvedUrl)
        }
      } else {
        asset = AVURLAsset(url: resolvedUrl)
        EatshotsResourceLoaderDelegate.prefetch(url: resolvedUrl, bytes: 2 * 1024 * 1024)
      }
    } else {
      asset = AVURLAsset(url: resolvedUrl)
    }
    
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

struct EatshotsVideoMetadata {
    let contentType: String
    let totalLength: Int64
}

class EatshotsResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private var taskMap = [AVAssetResourceLoadingRequest: URLSessionDataTask]()
    private lazy var session: URLSession = {
        return URLSession(configuration: .default)
    }()
    
    // Cache directory path
    private static var cacheDirectory: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("eatshots_video_cache")
    }
    
    private static var activePrefetchUrls = Set<URL>()
    private static let lock = NSLock()
    
    override init() {
        super.init()
        try? FileManager.default.createDirectory(at: EatshotsResourceLoaderDelegate.cacheDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    static func getSafeFileName(for url: URL) -> String {
        let regex = try! NSRegularExpression(pattern: "[^a-zA-Z0-9]", options: .caseInsensitive)
        let str = url.absoluteString
        let modString = regex.stringByReplacingMatches(in: str, options: [], range: NSRange(0..<str.utf16.count), withTemplate: "_")
        return String(modString.suffix(100)) + ".mp4"
    }
    
    static func getCachedFileUrl(for url: URL) -> URL? {
        let fileManager = FileManager.default
        let safeName = getSafeFileName(for: url)
        let fileUrl = cacheDirectory.appendingPathComponent(safeName)
        if fileManager.fileExists(atPath: fileUrl.path) {
            return fileUrl
        }
        return nil
    }
    
    static func getCachedMeta(for url: URL) -> EatshotsVideoMetadata? {
        let safeName = getSafeFileName(for: url)
        let metaUrl = cacheDirectory.appendingPathComponent(safeName + ".meta")
        guard let content = try? String(contentsOf: metaUrl, encoding: .utf8) else {
            return nil
        }
        
        var contentType = "public.mpeg-4"
        var totalLength: Int64 = 0
        
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if key == "contentType" {
                    contentType = val
                } else if key == "totalLength" {
                    totalLength = Int64(val) ?? 0
                }
            }
        }
        
        if totalLength > 0 {
            return EatshotsVideoMetadata(contentType: contentType, totalLength: totalLength)
        }
        return nil
    }
    
    static func getUTI(fromMimeType mimeType: String) -> String {
        if #available(iOS 14.0, *) {
            if let utType = UTType(mimeType: mimeType) {
                return utType.identifier
            }
        }
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue() {
            return uti as String
        }
        
        let lowerMime = mimeType.lowercased()
        if lowerMime.contains("mp4") {
            return "public.mpeg-4"
        } else if lowerMime.contains("quicktime") || lowerMime.contains("mov") {
            return "com.apple.quicktime-movie"
        } else if lowerMime.contains("mpegurl") || lowerMime.contains("m3u8") {
            return "public.mpeg-url"
        } else if lowerMime.contains("3gpp") {
            return "public.3gpp"
        }
        
        return "public.mpeg-4"
    }
    
    static func prefetch(url: URL, bytes: Int) {
        lock.lock()
        if activePrefetchUrls.contains(url) {
            lock.unlock()
            return
        }
        
        let safeName = getSafeFileName(for: url)
        let fileUrl = cacheDirectory.appendingPathComponent(safeName)
        let metaUrl = cacheDirectory.appendingPathComponent(safeName + ".meta")
        if FileManager.default.fileExists(atPath: fileUrl.path) && FileManager.default.fileExists(atPath: metaUrl.path) {
            lock.unlock()
            return
        }
        
        activePrefetchUrls.insert(url)
        lock.unlock()
        
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(bytes)", forHTTPHeaderField: "Range")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer {
                lock.lock()
                activePrefetchUrls.remove(url)
                lock.unlock()
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse, error == nil else { return }
            
            let tempFileUrl = cacheDirectory.appendingPathComponent(safeName + ".tmp")
            let tempMetaUrl = cacheDirectory.appendingPathComponent(safeName + ".meta.tmp")
            
            do {
                try data.write(to: tempFileUrl)
                
                var totalLength: Int64 = -1
                if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range") {
                    if let lastPart = contentRange.split(separator: "/").last, let total = Int64(lastPart) {
                        totalLength = total
                    }
                }
                if totalLength == -1 {
                    totalLength = httpResponse.expectedContentLength
                }
                
                let mimeType = httpResponse.mimeType ?? "video/mp4"
                let uti = getUTI(fromMimeType: mimeType)
                
                let metaString = "contentType=\(uti)\ntotalLength=\(totalLength)"
                try metaString.write(to: tempMetaUrl, atomically: true, encoding: .utf8)
                
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    try? FileManager.default.removeItem(at: fileUrl)
                }
                try FileManager.default.moveItem(at: tempFileUrl, to: fileUrl)
                
                if FileManager.default.fileExists(atPath: metaUrl.path) {
                    try? FileManager.default.removeItem(at: metaUrl)
                }
                try FileManager.default.moveItem(at: tempMetaUrl, to: metaUrl)
            } catch {
                try? FileManager.default.removeItem(at: tempFileUrl)
                try? FileManager.default.removeItem(at: tempMetaUrl)
            }
        }
        task.resume()
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let originalUrl = loadingRequest.request.url else { return false }
        
        let originalScheme = originalUrl.scheme == "eatshotscaches" ? "https" : "http"
        var components = URLComponents(url: originalUrl, resolvingAgainstBaseURL: false)
        components?.scheme = originalScheme
        guard let httpUrl = components?.url else { return false }
        
        if let localUrl = EatshotsResourceLoaderDelegate.getCachedFileUrl(for: httpUrl),
           let meta = EatshotsResourceLoaderDelegate.getCachedMeta(for: httpUrl) {
            serveLocalFile(localUrl, meta: meta, httpUrl: httpUrl, loadingRequest: loadingRequest)
            return true
        }
        
        startStreamingRequest(httpUrl, loadingRequest: loadingRequest)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        if let task = taskMap.removeValue(forKey: loadingRequest) {
            task.cancel()
        }
    }
    
    private func serveLocalFile(_ localUrl: URL, meta: EatshotsVideoMetadata, httpUrl: URL, loadingRequest: AVAssetResourceLoadingRequest) {
        guard let localData = try? Data(contentsOf: localUrl, options: .mappedIfSafe) else {
            loadingRequest.finishLoading(with: NSError(domain: "eatshotscache", code: -1, userInfo: nil))
            return
        }
        
        if let contentRequest = loadingRequest.contentInformationRequest {
            contentRequest.contentType = meta.contentType
            contentRequest.contentLength = meta.totalLength
            contentRequest.isByteRangeAccessSupported = true
        }
        
        guard let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading()
            return
        }
        
        let requestedOffset = dataRequest.requestedOffset
        let requestedLength = Int64(dataRequest.requestedLength)
        let cachedLength = Int64(localData.count)
        
        if requestedOffset < cachedLength {
            let cachedPartLength = min(cachedLength - requestedOffset, requestedLength)
            let subData = localData.subdata(in: Int(requestedOffset)..<Int(requestedOffset + cachedPartLength))
            dataRequest.respond(with: subData)
            
            if cachedPartLength == requestedLength {
                loadingRequest.finishLoading()
                return
            }
        }
        
        let startOffset = max(requestedOffset, cachedLength)
        let endOffset = requestedOffset + requestedLength - 1
        
        var request = URLRequest(url: httpUrl)
        request.setValue("bytes=\(startOffset)-\(endOffset)", forHTTPHeaderField: "Range")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            defer {
                self?.taskMap.removeValue(forKey: loadingRequest)
            }
            
            if let error = error {
                loadingRequest.finishLoading(with: error)
                return
            }
            
            if let data = data {
                dataRequest.respond(with: data)
                loadingRequest.finishLoading()
            } else {
                loadingRequest.finishLoading()
            }
        }
        taskMap[loadingRequest] = task
        task.resume()
    }
    
    private func startStreamingRequest(_ httpUrl: URL, loadingRequest: AVAssetResourceLoadingRequest) {
        var request = URLRequest(url: httpUrl)
        if let dataRequest = loadingRequest.dataRequest {
            let offset = dataRequest.requestedOffset
            let length = dataRequest.requestedLength
            request.setValue("bytes=\(offset)-\(offset + Int64(length) - 1)", forHTTPHeaderField: "Range")
        }
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.taskMap.removeValue(forKey: loadingRequest) }
            
            if let error = error {
                loadingRequest.finishLoading(with: error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if let contentRequest = loadingRequest.contentInformationRequest {
                    let mimeType = httpResponse.mimeType ?? "video/mp4"
                    contentRequest.contentType = EatshotsResourceLoaderDelegate.getUTI(fromMimeType: mimeType)
                    
                    let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range")
                    if let totalLengthStr = contentRange?.split(separator: "/").last, let totalLength = Int64(totalLengthStr) {
                        contentRequest.contentLength = totalLength
                    } else {
                        contentRequest.contentLength = httpResponse.expectedContentLength
                    }
                    contentRequest.isByteRangeAccessSupported = true
                }
            }
            
            if let data = data, let dataRequest = loadingRequest.dataRequest {
                dataRequest.respond(with: data)
                loadingRequest.finishLoading()
            }
        }
        taskMap[loadingRequest] = task
        task.resume()
    }
}
