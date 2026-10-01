import Foundation

/// The extension's end of the Unix socket the app listens on, written to as
/// an output stream.
final class SocketConnection: NSObject, StreamDelegate {
  var didOpen: (() -> Void)?
  var didClose: (() -> Void)?
  var streamHasSpaceAvailable: (() -> Void)?

  private let filePath: String
  private var socketHandle: Int32 = -1
  private var address: sockaddr_un?

  private var inputStream: InputStream?
  private var outputStream: OutputStream?

  private var networkThread: Thread?

  init?(filePath path: String) {
    filePath = path
    socketHandle = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    super.init()
    guard socketHandle != -1 else { return nil }
  }

  /// Connects and starts the streams; false while the app isn't listening yet.
  func open() -> Bool {
    guard FileManager.default.fileExists(atPath: filePath), connectSocket() else {
      Darwin.close(socketHandle)
      return false
    }
    setupStreams()
    inputStream?.open()
    outputStream?.open()
    return true
  }

  func close() {
    unscheduleStreams()
    inputStream?.delegate = nil
    outputStream?.delegate = nil
    inputStream?.close()
    outputStream?.close()
    inputStream = nil
    outputStream = nil
  }

  func writeToStream(buffer: UnsafePointer<UInt8>, maxLength length: Int) -> Int {
    outputStream?.write(buffer, maxLength: length) ?? 0
  }

  func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case .openCompleted:
      if aStream == outputStream { didOpen?() }
    case .hasBytesAvailable:
      // The app closing its end shows up as a read of zero bytes.
      if aStream == inputStream {
        var buffer: UInt8 = 0
        let read = inputStream?.read(&buffer, maxLength: 1) ?? 0
        if read == 0 { notifyClosed() }
      }
    case .hasSpaceAvailable:
      if aStream == outputStream { streamHasSpaceAvailable?() }
    case .endEncountered, .errorOccurred:
      notifyClosed()
    default:
      break
    }
  }

  private func notifyClosed() {
    let handler = didClose
    didClose = nil
    close()
    handler?()
  }

  private func connectSocket() -> Bool {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let maxLength = MemoryLayout.size(ofValue: addr.sun_path)
    guard filePath.utf8.count < maxLength else { return false }
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
      filePath.withCString { strncpy(ptr, $0, maxLength) }
    }
    let status = withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(socketHandle, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    address = addr
    return status == 0
  }

  private func setupStreams() {
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketHandle, &readStream, &writeStream)

    inputStream = readStream?.takeRetainedValue()
    inputStream?.delegate = self
    inputStream?.setProperty(kCFBooleanTrue, forKey: Stream.PropertyKey(kCFStreamPropertyShouldCloseNativeSocket as String))

    outputStream = writeStream?.takeRetainedValue()
    outputStream?.delegate = self
    outputStream?.setProperty(kCFBooleanTrue, forKey: Stream.PropertyKey(kCFStreamPropertyShouldCloseNativeSocket as String))

    scheduleStreams()
  }

  /// The streams get a run loop of their own so a busy main thread in the
  /// extension never stalls frames.
  private func scheduleStreams() {
    let thread = Thread { [weak self] in
      self?.inputStream?.schedule(in: .current, forMode: .common)
      self?.outputStream?.schedule(in: .current, forMode: .common)
      RunLoop.current.run()
    }
    thread.name = "ScreenShareSocket"
    networkThread = thread
    thread.start()
  }

  private func unscheduleStreams() {
    networkThread?.cancel()
    networkThread = nil
  }
}
