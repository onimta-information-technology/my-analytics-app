import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Set notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    GeneratedPluginRegistrant.register(with: self)

    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        print("Notification permission granted: \(granted)")
        if let error = error {
          print("Notification permission error: \(error.localizedDescription)")
        }
      }
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    // --- Developer Mode MethodChannel ---
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "developer_mode",
                                         binaryMessenger: controller.binaryMessenger)

      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "isDeveloperMode" {
          #if targetEnvironment(simulator)
            // Simulator: treat as developer-like
            result(true)
          #else
            // iOS: there's no public API; many apps read a system key that reflects Developer Mode state.
            // This is not an official public API. Use with caution.
            let devMode = UserDefaults.standard.bool(forKey: "com.apple.DeveloperModeStatus")
            result(devMode)
          #endif
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Register APNS token with Firebase
  override func application(_ application: UIApplication, 
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    print("APNS Token registered with Firebase")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle registration failure
  override func application(_ application: UIApplication, 
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  // Handle remote notifications
  override func application(_ application: UIApplication, 
                            didReceiveRemoteNotification userInfo: [AnyHashable : Any], 
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("Received remote notification: \(userInfo)")
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    completionHandler(.newData)
  }
  
  // CRITICAL FIX: Don't show notification when app is in foreground
  // Let Flutter handle it with Awesome Notifications
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("Will present notification: \(userInfo)")
    
    // ✅ CRITICAL: Return empty options to prevent iOS from showing the notification
    // Your Flutter code will show the custom Awesome Notification instead
    completionHandler([])
    
    // Note: The notification data will still be delivered to your Flutter app
    // via FirebaseMessaging.onMessage listener, where you show the custom notification
  }

  // Called when user taps the notification
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("User tapped notification: \(userInfo)")
    
    // This will trigger your onMessageOpenedApp listener in Flutter
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    
    completionHandler()
  }
}