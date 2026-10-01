import CoreImage
import Foundation
import ReplayKit

/// Sends screen frames to the app in the framing flutter_webrtc's
/// FlutterSocketConnectionFrameReader expects: an HTTP-style message with
/// `Content-Length`, `Buffer-Width`, `Buffer-Height` and `Buffer-Orientation`
/// headers and a JPEG body. A frame that arrives while the previous one is
/// still going out is dropped, so a slow link never builds up a backlog.
final class SampleUploader {
  /// Half-size JPEGs keep the extension well inside its 50 MB memory limit
  /// and are still sharp enough to read text on.
  private static let scale: CGFloat = 0.5
  private static let imageContext = CIContext(options: nil)

  private let connection: SocketConnection
  private let queue = DispatchQueue(label: "ScreenShareUploader")
  // Ready from the start: a write before the stream has opened just leaves
  // the frame pending until hasSpaceAvailable picks it up.
  private var isReady = true
  private var dataToSend: Data?
  private var byteIndex = 0

  init(connection: SocketConnection) {
    self.connection = connection
    connection.didOpen = { [weak self] in self?.queue.async { self?.isReady = true } }
    connection.streamHasSpaceAvailable = { [weak self] in
      self?.queue.async {
        guard let self else { return }
        self.isReady = !self.sendDataChunk()
      }
    }
  }

  @discardableResult
  func send(sample buffer: CMSampleBuffer) -> Bool {
    var sent = false
    queue.sync {
      guard isReady, let data = prepare(sample: buffer) else { return }
      isReady = false
      dataToSend = data
      byteIndex = 0
      isReady = !sendDataChunk()
      sent = true
    }
    return sent
  }

  /// Writes as much as the stream takes. True while bytes are left over.
  private func sendDataChunk() -> Bool {
    guard let data = dataToSend else { return false }
    var length = data.count - byteIndex
    length = min(length, 10 * 1024)
    let written = data.withUnsafeBytes { raw -> Int in
      guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
      return connection.writeToStream(buffer: base.advanced(by: byteIndex), maxLength: length)
    }
    if written > 0 { byteIndex += written }
    if byteIndex >= data.count {
      dataToSend = nil
      byteIndex = 0
      return false
    }
    return true
  }

  private func prepare(sample buffer: CMSampleBuffer) -> Data? {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

    let scale = Self.scale
    let width = CGFloat(CVPixelBufferGetWidth(imageBuffer)) * scale
    let height = CGFloat(CVPixelBufferGetHeight(imageBuffer)) * scale
    let orientation = CMGetAttachment(
      buffer,
      key: RPVideoSampleOrientationKey as CFString,
      attachmentModeOut: nil
    )?.uintValue ?? 0

    let image = CIImage(cvPixelBuffer: imageBuffer)
      .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let jpeg = Self.imageContext.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 1.0]
          ) else { return nil }

    let message = CFHTTPMessageCreateResponse(nil, 200, nil, kCFHTTPVersion1_1).takeRetainedValue()
    CFHTTPMessageSetHeaderFieldValue(message, "Content-Length" as CFString, String(jpeg.count) as CFString)
    CFHTTPMessageSetHeaderFieldValue(message, "Buffer-Width" as CFString, String(Int(width)) as CFString)
    CFHTTPMessageSetHeaderFieldValue(message, "Buffer-Height" as CFString, String(Int(height)) as CFString)
    CFHTTPMessageSetHeaderFieldValue(message, "Buffer-Orientation" as CFString, String(orientation) as CFString)
    CFHTTPMessageSetBody(message, jpeg as CFData)

    return CFHTTPMessageCopySerializedMessage(message)?.takeRetainedValue() as Data?
  }
}
