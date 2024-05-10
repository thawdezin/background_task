import UIKit
import Flutter
import background_task // 👈 Add
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        // 👇 Add
        BackgroundTaskPlugin.onRegisterDispatchEngine = {
            GeneratedPluginRegistrant.register(with: BackgroundTaskPlugin.dispatchEngine)
        }
        if #available(iOS 10.0, *) {
                    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
                }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
