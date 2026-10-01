import ReplayKit

/// The Broadcast Upload Extension behind screen sharing during a call.
///
/// iOS only lets an app capture the whole screen — other apps included —
/// through an extension like this one, started from the system broadcast
/// picker. It runs in its own process, so the frames are passed to the app
/// over a Unix socket in the shared App Group container (`rtc_SSFD`), where
/// flutter_webrtc's FlutterBroadcastScreenCapturer feeds them to WebRTC.
///
/// Start and stop are signalled both ways with Darwin notifications — see
/// [ScreenShareSignal] and `AppDelegate.registerScreenShareChannel`.
class SampleHandler: RPBroadcastSampleHandler {
  private var connection: SocketConnection?
  private var uploader: SampleUploader?
  private var connectTimer: Timer?

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    guard let path = ScreenShareSignal.socketPath else {
      finish("Screen sharing is not set up for this app.")
      return
    }
    DarwinNotificationCenter.observe(ScreenShareSignal.stopRequested) { [weak self] in
      self?.finish("You stopped sharing your screen.")
    }
    // The app only opens its end of the socket once it hears this.
    DarwinNotificationCenter.post(ScreenShareSignal.started)
    connect(to: path)
  }

  override func broadcastFinished() {
    DarwinNotificationCenter.post(ScreenShareSignal.finished)
    tearDown()
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
    guard type == .video else { return }
    uploader?.send(sample: sampleBuffer)
  }

  /// Retries for a few seconds: the app has to publish its screen track
  /// (which creates the socket server) after hearing the broadcast started.
  private func connect(to path: String) {
    var attempts = 0
    let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] timer in
      guard let self else { return timer.invalidate() }
      attempts += 1
      let connection = SocketConnection(filePath: path)
      if let connection, connection.open() {
        timer.invalidate()
        connection.didClose = { [weak self] in
          self?.finish("You stopped sharing your screen.")
        }
        self.connection = connection
        self.uploader = SampleUploader(connection: connection)
      } else if attempts > 50 {
        timer.invalidate()
        self.finish("Could not share your screen. Start sharing again from the call.")
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    connectTimer = timer
  }

  private func finish(_ message: String) {
    tearDown()
    finishBroadcastWithError(NSError(
      domain: RPRecordingErrorDomain,
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: message]
    ))
  }

  private func tearDown() {
    connectTimer?.invalidate()
    connectTimer = nil
    DarwinNotificationCenter.removeAll()
    connection?.didClose = nil
    connection?.close()
    connection = nil
    uploader = nil
  }
}
