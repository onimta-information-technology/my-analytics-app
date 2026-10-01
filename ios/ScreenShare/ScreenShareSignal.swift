import Foundation

/// Names shared by the app and the extension. The App Group must match
/// `RTCAppGroupIdentifier` in Runner/Info.plist and both targets'
/// entitlements.
enum ScreenShareSignal {
  static let appGroup = "group.com.app.ballysReservationApp"

  /// Extension → app: the user started the broadcast.
  static let started = "com.app.ballysReservationApp.screenShare.started"
  /// Extension → app: the broadcast is over (stopped from the status bar or
  /// Control Center, or it failed).
  static let finished = "com.app.ballysReservationApp.screenShare.finished"
  /// App → extension: stop sharing — the button in the call, or the call
  /// ended.
  static let stopRequested = "com.app.ballysReservationApp.screenShare.stop"

  /// Where flutter_webrtc listens for frames (`kRTCScreensharingSocketFD`).
  static var socketPath: String? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent("rtc_SSFD")
      .path
  }
}

/// Darwin notifications: the only signal that crosses from an extension to
/// its app with no payload and no IPC setup.
enum DarwinNotificationCenter {
  private static var handlers: [String: () -> Void] = [:]

  static func post(_ name: String) {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(name as CFString),
      nil, nil, true
    )
  }

  /// Calls [handler] on the main queue each time [name] is posted.
  static func observe(_ name: String, handler: @escaping () -> Void) {
    handlers[name] = handler
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      nil,
      { _, _, cfName, _, _ in
        guard let name = cfName?.rawValue as String? else { return }
        DispatchQueue.main.async { DarwinNotificationCenter.handlers[name]?() }
      },
      name as CFString,
      nil,
      .deliverImmediately
    )
  }

  static func removeAll() {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil)
    handlers.removeAll()
  }
}
