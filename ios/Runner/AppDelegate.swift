import Flutter
import UIKit
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Under the implicit-engine lifecycle, plugins are created here — AFTER
    // UIApplicationDidFinishLaunchingNotification has already fired. That is the
    // notification firebase_messaging observes to auto-call
    // registerForRemoteNotifications() and to install its UNUserNotificationCenter
    // delegate. Both therefore never happen, APNs never issues a device token,
    // getAPNSToken() stays nil and getToken() throws apns-token-not-set — silently.
    // Do both by hand, in the same order the plugin would have.

    // 1. FlutterAppDelegate's UNUserNotificationCenterDelegate conformance is
    //    nominal — it does not forward willPresent/didReceive to plugins. Hand the
    //    delegate to the messaging plugin itself or foreground pushes never arrive.
    if let messagingPlugin = engineBridge.pluginRegistry.valuePublished(
      byPlugin: "FLTFirebaseMessagingPlugin"
    ) as? UNUserNotificationCenterDelegate {
      UNUserNotificationCenter.current().delegate = messagingPlugin
    }

    // 2. Ask iOS to register with APNs. Safe to call every launch; iOS dedupes
    //    and re-delivers the cached token to didRegisterForRemoteNotifications.
    UIApplication.shared.registerForRemoteNotifications()
  }
}
