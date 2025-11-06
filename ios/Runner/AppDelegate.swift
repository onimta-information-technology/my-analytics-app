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
    // Configure Firebase
    FirebaseApp.configure()
    
    // Set FCM delegate
    Messaging.messaging().delegate = self

    // Set notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    GeneratedPluginRegistrant.register(with: self)

    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        print("✅ Notification permission granted: \(granted)")
        if let error = error {
          print("❌ Notification permission error: \(error.localizedDescription)")
        }
      }
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    // Developer Mode MethodChannel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "developer_mode",
                                         binaryMessenger: controller.binaryMessenger)

      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "isDeveloperMode" {
          #if targetEnvironment(simulator)
            result(true)
          #else
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
  
  // CRITICAL: Register APNS token with Firebase
  override func application(_ application: UIApplication, 
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("📱 Device registered for remote notifications")
    
    // Set APNs token for Firebase
    Messaging.messaging().apnsToken = deviceToken
    
    // Print token for debugging
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("📱 APNs Device Token: \(token)")
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle registration failure
  override func application(_ application: UIApplication, 
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  // Handle remote notifications in background
  override func application(_ application: UIApplication, 
                            didReceiveRemoteNotification userInfo: [AnyHashable : Any], 
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("📬 Received remote notification: \(userInfo)")
    completionHandler(.newData)
  }
  
  // ⭐ UPDATED: Show notification when app is in foreground WITH CHAT CHECK
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("========================================")
    print("🔔 iOS willPresent notification")
    print("UserInfo: \(userInfo)")
    
    // ⭐ Extract chatId from notification
    var notificationChatId: String?
    
    // Method 1: Try to parse from "Details" JSON string
    if let detailsString = userInfo["Details"] as? String {
      print("📦 Found Details string: \(detailsString)")
      if let detailsData = detailsString.data(using: .utf8) {
        do {
          if let details = try JSONSerialization.jsonObject(with: detailsData) as? [String: Any] {
            notificationChatId = details["chatId"] as? String
            print("✅ Parsed chatId from Details: \(notificationChatId ?? "nil")")
          }
        } catch {
          print("❌ Error parsing Details JSON: \(error)")
        }
      }
    }
    
    // Method 2: Check direct fields if Details parsing failed
    if notificationChatId == nil {
      notificationChatId = userInfo["chatId"] as? String ?? 
                          userInfo["chat_id"] as? String ?? 
                          userInfo["ChatId"] as? String
      if notificationChatId != nil {
        print("✅ Found chatId in direct fields: \(notificationChatId ?? "nil")")
      }
    }
    
    // ⭐ Get current open chat from SharedPreferences (UserDefaults on iOS)
    let currentChatId = UserDefaults.standard.string(forKey: "flutter.current_chat_id")
    print("📱 Current open chat: \(currentChatId ?? "nil")")
    print("📬 Notification chat: \(notificationChatId ?? "nil")")
    
    // ⭐ Decision: Suppress or show?
    if let notificationChat = notificationChatId, 
       let currentChat = currentChatId, 
       notificationChat == currentChat {
      print("🔇 SUPPRESSING - Notification is for currently open chat")
      print("========================================")
      // Only update badge, NO banner or sound
      completionHandler([.badge])
    } else {
      print("🔔 SHOWING - Notification is for different chat or no chat open")
      print("========================================")
      // Show full notification with banner, sound, and badge
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound, .badge])
      } else {
        completionHandler([.alert, .sound, .badge])
      }
    }
  }

  // Handle notification tap
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("👆 User tapped notification: \(userInfo)")
    
    completionHandler()
  }
}

// CRITICAL: FCM Messaging Delegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔥 Firebase FCM Token: \(fcmToken ?? "nil")")
    
    // Send token to your server if needed
    if let token = fcmToken {
      // Post notification to Flutter side
      NotificationCenter.default.post(
        name: Notification.Name("FCMToken"),
        object: nil,
        userInfo: ["token": token]
      )
    }
  }
}