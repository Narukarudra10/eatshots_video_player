import Flutter
import UIKit
import AVFoundation
import Network
import CoreTelephony
import MobileCoreServices

public class VideoViewPlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let registry: FlutterTextureRegistry
  private let messenger: FlutterBinaryMessenger
  private let registrar: FlutterPluginRegistrar
  private var players: [Int64: VideoViewPlayer] = [:]
  
  private let monitor = NWPathMonitor()
  private var currentConnectionType = "WIFI"
  private var networkEventChannel: FlutterEventChannel?
  private var networkEventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "video_view_player", binaryMessenger: registrar.messenger())
    let instance = VideoViewPlayerPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(registrar: FlutterPluginRegistrar) {
    self.registry = registrar.textures()
    self.messenger = registrar.messenger()
    self.registrar = registrar
    super.init()
    
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("VideoViewPlayerPlugin: Failed to configure AVAudioSession: \(error)")
    }
    
    let netChannel = FlutterEventChannel(name: "video_view_player/network_events", binaryMessenger: registrar.messenger())
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
      
      let player = VideoViewPlayer(
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
        },
        onUrlReleased: { [weak self] releasedUrl in
          guard let self = self else { return }
          let isUsed = self.players.values.contains { $0.currentUrl == releasedUrl }
          if !isUsed {
            VideoViewResourceLoaderDelegate.cancelDownloader(for: releasedUrl)
          }
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
      VideoViewResourceLoaderDelegate.prefetch(url: url, bytes: bytes)
      result(nil)
      
    case "cancelPrefetch":
      guard let urlString = args?["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "URL is invalid", details: nil))
        return
      }
      VideoViewResourceLoaderDelegate.cancelPrefetch(url: url)
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

class VideoViewPlayer: NSObject, FlutterTexture, FlutterStreamHandler {
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
  private let onUrlReleased: ((URL) -> Void)?
  private var resourceLoaderDelegate: VideoViewResourceLoaderDelegate? // Strong reference
  private let messenger: FlutterBinaryMessenger
  var currentUrl: URL?
  
  init(url: URL, registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger, urlResolver: @escaping (URL) -> URL, onUrlReleased: @escaping (URL) -> Void) {
    self.registry = registry
    self.messenger = messenger
    self.urlResolver = urlResolver
    self.onUrlReleased = onUrlReleased
    super.init()
    
    setupPlayer(url: url)
    
    self.displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
    self.displayLink?.add(to: .main, forMode: .common)
    self.displayLink?.isPaused = true
  }

  func setTextureId(_ textureId: Int64) {
    self.textureId = textureId
    self.eventChannel = FlutterEventChannel(name: "video_view_player/videoEvents_\(textureId)", binaryMessenger: messenger)
    self.eventChannel?.setStreamHandler(self)
  }

  private func setupPlayer(url: URL) {
    let resolvedUrl = urlResolver(url)
    self.currentUrl = resolvedUrl
    
    let asset: AVURLAsset
    if resolvedUrl.scheme == "http" || resolvedUrl.scheme == "https" {
      let isHls = resolvedUrl.pathExtension.lowercased() == "m3u8" || resolvedUrl.absoluteString.lowercased().contains("m3u8")
      
      if !isHls && VideoViewResourceLoaderDelegate.isFullyCached(url: resolvedUrl),
         let localUrl = VideoViewResourceLoaderDelegate.getCachedFileUrl(for: resolvedUrl) {
        asset = AVURLAsset(url: localUrl)
      } else if !isHls {
        var components = URLComponents(url: resolvedUrl, resolvingAgainstBaseURL: false)
        let origScheme = resolvedUrl.scheme ?? "https"
        components?.scheme = origScheme == "https" ? "videoviewcaches" : "videoviewcache"
        if let customUrl = components?.url {
          asset = AVURLAsset(url: customUrl)
          let delegate = VideoViewResourceLoaderDelegate()
          let queue = DispatchQueue(label: "com.video_view_player.loader")
          asset.resourceLoader.setDelegate(delegate, queue: queue)
          self.resourceLoaderDelegate = delegate
          
          let downloader = VideoViewResourceLoaderDelegate.getOrCreateDownloader(for: resolvedUrl)
          downloader.start(isPrefetch: false, limit: 0)
        } else {
          asset = AVURLAsset(url: resolvedUrl)
        }
      } else {
        asset = AVURLAsset(url: resolvedUrl)
      }
    } else {
      asset = AVURLAsset(url: resolvedUrl)
    }
    
    let item = AVPlayerItem(asset: asset)
    self.playerItem = item
    
    let pixBuffAttributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ]
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixBuffAttributes)
    self.videoOutput = output
    item.add(output)
    
    if let player = self.player {
      player.replaceCurrentItem(with: item)
    } else {
      self.player = AVPlayer(playerItem: item)
      self.player?.actionAtItemEnd = .none // loop handler will seek to start
    }
    
    // Add observers
    item.addObserver(self, forKeyPath: "status", options: [.old, .new], context: nil)
    item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [.old, .new], context: nil)
    item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.old, .new], context: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
  }

  @objc private func onDisplayLink(_ sender: CADisplayLink) {
    registry?.textureFrameAvailable(textureId)
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let videoOutput = videoOutput else { return nil }
    var time = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
    if !time.isValid || time.isIndefinite {
      if let item = playerItem {
        time = item.currentTime()
      }
    }
    if videoOutput.hasNewPixelBuffer(forItemTime: time) {
      if let buffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
        return Unmanaged.passRetained(buffer)
      }
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
    if CMTIME_IS_INVALID(time) || CMTIME_IS_INDEFINITE(time) {
      return 0
    }
    let seconds = CMTimeGetSeconds(time)
    return (seconds.isNaN || seconds.isInfinite) ? 0 : Int64(seconds * 1000)
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
    
    let oldUrl = currentUrl
    setupPlayer(url: url)
    if let oldUrl = oldUrl {
      onUrlReleased?(oldUrl)
    }
  }

  @objc private func itemDidPlayToEndTime(_ notification: Notification) {
    if isLooping {
      // Loop automatically for short-form feed
      player?.seek(to: .zero)
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
          var durationMs: Int64 = 0
          if !CMTIME_IS_INVALID(duration) && !CMTIME_IS_INDEFINITE(duration) {
            let seconds = CMTimeGetSeconds(duration)
            if !seconds.isNaN && !seconds.isInfinite {
              durationMs = Int64(seconds * 1000)
            }
          }
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
      var durationMs: Int64 = 0
      if !CMTIME_IS_INVALID(duration) && !CMTIME_IS_INDEFINITE(duration) {
        let seconds = CMTimeGetSeconds(duration)
        if !seconds.isNaN && !seconds.isInfinite {
          durationMs = Int64(seconds * 1000)
        }
      }
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
    
    if let oldUrl = currentUrl {
      currentUrl = nil
      onUrlReleased?(oldUrl)
    }
  }
}

struct VideoViewMetadata {
    let contentType: String
    let totalLength: Int64
}

class VideoViewMediaDownloader: NSObject, URLSessionDataDelegate {
    let url: URL
    let fileUrl: URL
    let tempFileUrl: URL
    let metaUrl: URL
    
    private var session: URLSession?
    private var task: URLSessionDataTask?
    
    private var fileHandle: FileHandle?
    var receivedLength: Int64 = 0
    var totalLength: Int64 = -1
    var mimeType: String = "video/mp4"
    var isPrefetchOnly = false
    var prefetchLimit: Int64 = 0
    
    private var pendingRequests = Set<AVAssetResourceLoadingRequest>()
    private let queue = DispatchQueue(label: "com.video_view_player.downloader")
    
    var onCompleted: (() -> Void)?
    var onError: ((Error?) -> Void)?
    
    init(url: URL, fileUrl: URL, tempFileUrl: URL, metaUrl: URL) {
        self.url = url
        self.fileUrl = fileUrl
        self.tempFileUrl = tempFileUrl
        self.metaUrl = metaUrl
        super.init()
        
        try? FileManager.default.createDirectory(at: VideoViewResourceLoaderDelegate.cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        
        if FileManager.default.fileExists(atPath: tempFileUrl.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: tempFileUrl.path),
               let size = attrs[.size] as? Int64 {
                self.receivedLength = size
            }
        } else {
            FileManager.default.createFile(atPath: tempFileUrl.path, contents: nil, attributes: nil)
        }
    }
    
    func start(isPrefetch: Bool, limit: Int64) {
        queue.async {
            if self.task == nil {
                self.isPrefetchOnly = isPrefetch
                self.prefetchLimit = limit
                self.startInternalTask()
            } else {
                if !isPrefetch && self.isPrefetchOnly {
                    self.isPrefetchOnly = false
                    self.prefetchLimit = 0
                    if self.receivedLength >= limit && self.totalLength > 0 && self.receivedLength < self.totalLength {
                        self.startInternalTask()
                    }
                }
            }
        }
    }
    
    private func startInternalTask() {
        if self.fileHandle == nil {
            self.fileHandle = FileHandle(forWritingAtPath: tempFileUrl.path)
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        
        var request = URLRequest(url: url)
        if receivedLength > 0 {
            request.setValue("bytes=\(receivedLength)-", forHTTPHeaderField: "Range")
        }
        
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }
    
    func cancel() {
        queue.async {
            self.task?.cancel()
            self.task = nil
            self.session?.invalidateAndCancel()
            self.session = nil
            if #available(iOS 13.0, *) {
                try? self.fileHandle?.close()
            } else {
                self.fileHandle?.closeFile()
            }
            self.fileHandle = nil
            
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
            for request in self.pendingRequests {
                request.finishLoading(with: error)
            }
            self.pendingRequests.removeAll()
        }
    }
    
    func add(request: AVAssetResourceLoadingRequest) {
        queue.async {
            self.pendingRequests.insert(request)
            self.processPendingRequests()
        }
    }
    
    func remove(request: AVAssetResourceLoadingRequest) {
        queue.async {
            self.pendingRequests.remove(request)
        }
    }
    
    private func processPendingRequests() {
        var completedRequests = Set<AVAssetResourceLoadingRequest>()
        
        for request in pendingRequests {
            var filledContent = false
            if let contentRequest = request.contentInformationRequest {
                if totalLength > 0 {
                    contentRequest.contentType = VideoViewResourceLoaderDelegate.getUTI(fromMimeType: self.mimeType)
                    contentRequest.contentLength = totalLength
                    contentRequest.isByteRangeAccessSupported = true
                    filledContent = true
                }
            } else {
                filledContent = true
            }
            
            if let dataRequest = request.dataRequest {
                let currentOffset = dataRequest.currentOffset
                let requestedOffset = dataRequest.requestedOffset
                let requestedLength = Int64(dataRequest.requestedLength)
                
                if currentOffset < receivedLength {
                    let remainingLength = requestedOffset + requestedLength - currentOffset
                    let availableLength = min(receivedLength - currentOffset, remainingLength)
                    if availableLength > 0 {
                        if let data = readData(from: tempFileUrl, offset: currentOffset, length: availableLength) {
                            dataRequest.respond(with: data)
                        }
                    }
                }
                
                if dataRequest.currentOffset >= requestedOffset + requestedLength && filledContent {
                    request.finishLoading()
                    completedRequests.insert(request)
                }
            } else if filledContent {
                request.finishLoading()
                completedRequests.insert(request)
            }
        }
        
        for req in completedRequests {
            pendingRequests.remove(req)
        }
    }
    
    private func readData(from url: URL, offset: Int64, length: Int64) -> Data? {
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer {
            if #available(iOS 13.0, *) {
                try? file.close()
            } else {
                file.closeFile()
            }
        }
        do {
            if #available(iOS 13.0, *) {
                try file.seek(toOffset: UInt64(offset))
            } else {
                file.seek(toFileOffset: UInt64(offset))
            }
            return file.readData(ofLength: Int(length))
        } catch {
            return nil
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        queue.async {
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 200 && statusCode < 300 {
                    let isRangeAccepted = statusCode == 206
                    
                    if !isRangeAccepted && self.receivedLength > 0 {
                        self.receivedLength = 0
                        if #available(iOS 13.0, *) {
                            try? self.fileHandle?.truncate(atOffset: 0)
                        } else {
                            self.fileHandle?.truncateFile(atOffset: 0)
                        }
                    }
                    
                    if self.totalLength == -1 {
                        var total: Int64 = -1
                        if let contentRange = httpResponse.valueCompat(forHTTPHeaderField: "Content-Range") {
                            if let lastPart = contentRange.split(separator: "/").last, let t = Int64(lastPart) {
                                total = t
                            }
                        }
                        if total == -1 {
                            total = httpResponse.expectedContentLength
                        }
                        self.totalLength = total
                        self.mimeType = httpResponse.mimeType ?? "video/mp4"
                    }
                    
                    completionHandler(.allow)
                    self.processPendingRequests()
                    return
                }
            }
            completionHandler(.cancel)
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async {
            guard let fileHandle = self.fileHandle else { return }
            
            do {
                if #available(iOS 13.4, *) {
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                } else {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }
                self.receivedLength += Int64(data.count)
            } catch {
                return
            }
            
            self.processPendingRequests()
            
            if self.isPrefetchOnly && self.receivedLength >= self.prefetchLimit {
                self.task?.cancel()
                self.task = nil
                self.session?.invalidateAndCancel()
                self.session = nil
                if #available(iOS 13.0, *) {
                    try? fileHandle.close()
                } else {
                    fileHandle.closeFile()
                }
                self.fileHandle = nil
                self.onCompleted?()
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async {
            if #available(iOS 13.0, *) {
                try? self.fileHandle?.close()
            } else {
                self.fileHandle?.closeFile()
            }
            self.fileHandle = nil
            
            if let error = error {
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    self.onError?(error)
                    for request in self.pendingRequests {
                        request.finishLoading(with: error)
                    }
                    self.pendingRequests.removeAll()
                }
                return
            }
            
            if self.receivedLength == self.totalLength {
                do {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: self.fileUrl.path) {
                        try? fileManager.removeItem(at: self.fileUrl)
                    }
                    try fileManager.moveItem(at: self.tempFileUrl, to: self.fileUrl)
                    
                    let uti = VideoViewResourceLoaderDelegate.getUTI(fromMimeType: self.mimeType)
                    let metaString = "contentType=\(uti)\ntotalLength=\(self.totalLength)"
                    if fileManager.fileExists(atPath: self.metaUrl.path) {
                        try? fileManager.removeItem(at: self.metaUrl)
                    }
                    try metaString.write(to: self.metaUrl, atomically: true, encoding: .utf8)
                    
                    self.processPendingRequests()
                    for request in self.pendingRequests {
                        request.finishLoading()
                    }
                    self.pendingRequests.removeAll()
                    
                    self.onCompleted?()
                } catch {
                    self.onError?(error)
                    for request in self.pendingRequests {
                        request.finishLoading(with: error)
                    }
                    self.pendingRequests.removeAll()
                }
            } else {
                let connError = NSError(domain: "videoviewcache", code: -2, userInfo: [NSLocalizedDescriptionKey: "Connection closed before receiving all data"])
                self.onError?(connError)
                for request in self.pendingRequests {
                    request.finishLoading(with: connError)
                }
                self.pendingRequests.removeAll()
            }
        }
    }
}

class VideoViewSingleRequestStreamer: NSObject, URLSessionDataDelegate {
    let loadingRequest: AVAssetResourceLoadingRequest
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private let queue = DispatchQueue(label: "com.video_view_player.streamer")
    
    init(url: URL, loadingRequest: AVAssetResourceLoadingRequest) {
        self.loadingRequest = loadingRequest
        super.init()
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        
        var request = URLRequest(url: url)
        if let dataRequest = loadingRequest.dataRequest {
            let offset = dataRequest.requestedOffset
            let length = dataRequest.requestedLength
            request.setValue("bytes=\(offset)-\(offset + Int64(length) - 1)", forHTTPHeaderField: "Range")
        }
        
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }
    
    func cancel() {
        queue.async {
            self.task?.cancel()
            self.task = nil
            self.session?.invalidateAndCancel()
            self.session = nil
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        queue.async {
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 200 && statusCode < 300 {
                    if let contentRequest = self.loadingRequest.contentInformationRequest {
                        let mimeType = httpResponse.mimeType ?? "video/mp4"
                        contentRequest.contentType = VideoViewResourceLoaderDelegate.getUTI(fromMimeType: mimeType)
                        
                        let contentRange = httpResponse.valueCompat(forHTTPHeaderField: "Content-Range")
                        if let totalLengthStr = contentRange?.split(separator: "/").last, let totalLength = Int64(totalLengthStr) {
                            contentRequest.contentLength = totalLength
                        } else {
                            contentRequest.contentLength = httpResponse.expectedContentLength
                        }
                        contentRequest.isByteRangeAccessSupported = true
                    }
                    completionHandler(.allow)
                    return
                }
            }
            completionHandler(.cancel)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async {
            if let dataRequest = self.loadingRequest.dataRequest {
                dataRequest.respond(with: data)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async {
            if let error = error {
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    self.loadingRequest.finishLoading(with: error)
                }
            } else {
                self.loadingRequest.finishLoading()
            }
            self.session?.invalidateAndCancel()
            self.session = nil
            self.task = nil
        }
    }
}

class VideoViewResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private var taskMap = [AVAssetResourceLoadingRequest: VideoViewSingleRequestStreamer]()
    private let taskQueue = DispatchQueue(label: "com.video_view_player.resourceLoaderTaskQueue")
    
    static var activeDownloaders = [URL: VideoViewMediaDownloader]()
    private static let downloaderLock = NSLock()
    
    static func getOrCreateDownloader(for url: URL) -> VideoViewMediaDownloader {
        downloaderLock.lock()
        defer { downloaderLock.unlock() }
        
        let cleanUrl = url.videoViewClean
        if let existing = activeDownloaders[cleanUrl] {
            return existing
        }
        
        let safeName = getSafeFileName(for: cleanUrl)
        let fileUrl = cacheDirectory.appendingPathComponent(safeName)
        let tempFileUrl = cacheDirectory.appendingPathComponent(safeName + ".tmp")
        let metaUrl = cacheDirectory.appendingPathComponent(safeName + ".meta")
        
        let downloader = VideoViewMediaDownloader(url: url, fileUrl: fileUrl, tempFileUrl: tempFileUrl, metaUrl: metaUrl)
        
        downloader.onCompleted = {
            downloaderLock.lock()
            activeDownloaders.removeValue(forKey: cleanUrl)
            downloaderLock.unlock()
        }
        
        downloader.onError = { _ in
            downloaderLock.lock()
            activeDownloaders.removeValue(forKey: cleanUrl)
            downloaderLock.unlock()
        }
        
        activeDownloaders[cleanUrl] = downloader
        return downloader
    }
    
    static func cancelDownloader(for url: URL) {
        downloaderLock.lock()
        let cleanUrl = url.videoViewClean
        let downloader = activeDownloaders[cleanUrl]
        downloaderLock.unlock()
        
        if let downloader = downloader {
            downloader.cancel()
            downloaderLock.lock()
            activeDownloaders.removeValue(forKey: cleanUrl)
            downloaderLock.unlock()
        }
    }
    
    // Cache directory path
    static var cacheDirectory: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("video_view_cache")
    }
    
    static func getSafeFileName(for url: URL) -> String {
        let cleanUrl = url.videoViewClean
        let regex = try! NSRegularExpression(pattern: "[^a-zA-Z0-9]", options: .caseInsensitive)
        let str = cleanUrl.absoluteString
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
    
    static func getCachedMeta(for url: URL) -> VideoViewMetadata? {
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
            return VideoViewMetadata(contentType: contentType, totalLength: totalLength)
        }
        return nil
    }
    
    static func isFullyCached(url: URL) -> Bool {
        let safeName = getSafeFileName(for: url)
        let fileUrl = cacheDirectory.appendingPathComponent(safeName)
        let metaUrl = cacheDirectory.appendingPathComponent(safeName + ".meta")
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileUrl.path),
              fileManager.fileExists(atPath: metaUrl.path),
              let meta = getCachedMeta(for: url) else {
            return false
        }
        
        do {
            let attrs = try fileManager.attributesOfItem(atPath: fileUrl.path)
            if let fileSize = attrs[.size] as? Int64 {
                return fileSize == meta.totalLength
            }
        } catch {
            return false
        }
        return false
    }
    
    static func getUTI(fromMimeType mimeType: String) -> String {
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
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let isHls = url.pathExtension.lowercased() == "m3u8" || url.absoluteString.contains(".m3u8")
        if isHls {
            let task = URLSession.shared.dataTask(with: url)
            task.resume()
            return
        }
        
        if isFullyCached(url: url) {
            return
        }
        
        let downloader = getOrCreateDownloader(for: url)
        downloader.start(isPrefetch: true, limit: Int64(bytes))
    }
    
    static func cancelPrefetch(url: URL) {
        downloaderLock.lock()
        let cleanUrl = url.videoViewClean
        let downloader = activeDownloaders[cleanUrl]
        downloaderLock.unlock()
        
        if let downloader = downloader, downloader.isPrefetchOnly {
            downloader.cancel()
            downloaderLock.lock()
            activeDownloaders.removeValue(forKey: cleanUrl)
            downloaderLock.unlock()
        }
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let originalUrl = loadingRequest.request.url else { return false }
        
        let originalScheme = originalUrl.scheme == "videoviewcaches" ? "https" : "http"
        var components = URLComponents(url: originalUrl, resolvingAgainstBaseURL: false)
        components?.scheme = originalScheme
        guard let httpUrl = components?.url else { return false }
        
        if VideoViewResourceLoaderDelegate.isFullyCached(url: httpUrl),
           let localUrl = VideoViewResourceLoaderDelegate.getCachedFileUrl(for: httpUrl),
           let meta = VideoViewResourceLoaderDelegate.getCachedMeta(for: httpUrl) {
            serveLocalFile(localUrl, meta: meta, loadingRequest: loadingRequest)
            return true
        }
        
        if let dataRequest = loadingRequest.dataRequest {
            let requestedOffset = dataRequest.requestedOffset
            
            let downloader = VideoViewResourceLoaderDelegate.getOrCreateDownloader(for: httpUrl)
            if requestedOffset > downloader.receivedLength + 512 * 1024 {
                startStreamingRequest(httpUrl, loadingRequest: loadingRequest)
                return true
            }
        }
        
        let downloader = VideoViewResourceLoaderDelegate.getOrCreateDownloader(for: httpUrl)
        downloader.add(request: loadingRequest)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        taskQueue.async {
            if let streamer = self.taskMap.removeValue(forKey: loadingRequest) {
                streamer.cancel()
            }
        }
        
        guard let originalUrl = loadingRequest.request.url else { return }
        let originalScheme = originalUrl.scheme == "videoviewcaches" ? "https" : "http"
        var components = URLComponents(url: originalUrl, resolvingAgainstBaseURL: false)
        components?.scheme = originalScheme
        if let httpUrl = components?.url {
            let cleanUrl = httpUrl.videoViewClean
            if let downloader = VideoViewResourceLoaderDelegate.activeDownloaders[cleanUrl] {
                downloader.remove(request: loadingRequest)
            }
        }
    }
    
    private func serveLocalFile(_ localUrl: URL, meta: VideoViewMetadata, loadingRequest: AVAssetResourceLoadingRequest) {
        guard let localData = try? Data(contentsOf: localUrl, options: .mappedIfSafe) else {
            loadingRequest.finishLoading(with: NSError(domain: "videoviewcache", code: -1, userInfo: nil))
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
        
        loadingRequest.finishLoading(with: NSError(domain: "videoviewcache", code: -3, userInfo: [NSLocalizedDescriptionKey: "Requested range not fully cached"]))
    }
    
    private func startStreamingRequest(_ httpUrl: URL, loadingRequest: AVAssetResourceLoadingRequest) {
        let streamer = VideoViewSingleRequestStreamer(url: httpUrl, loadingRequest: loadingRequest)
        taskQueue.async {
            self.taskMap[loadingRequest] = streamer
        }
    }
}

extension HTTPURLResponse {
    func valueCompat(forHTTPHeaderField field: String) -> String? {
        if #available(iOS 13.0, *) {
            return self.value(forHTTPHeaderField: field)
        } else {
            for (key, value) in self.allHeaderFields {
                if let keyStr = key as? String, keyStr.caseInsensitiveCompare(field) == .orderedSame {
                    return value as? String
                }
            }
            return nil
        }
    }
}

extension URL {
    var videoViewClean: URL {
        if var components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            components.query = nil
            if let cleanUrl = components.url {
                return cleanUrl
            }
        }
        return self
    }
}
