#if os(macOS)
import DirectGTDCore
import Cocoa
import CloudKit

/// macOS AppDelegate handles push notifications for CloudKit sync.
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var syncEngine: SyncEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("AppDelegate: Application did finish launching")

        // Register for remote notifications
        NSApp.registerForRemoteNotifications()
        NSLog("AppDelegate: Registered for remote notifications")
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NSLog("AppDelegate: Registered for remote notifications with token: \(tokenString.prefix(8))...")
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Handle remote notifications from CloudKit.
    /// On macOS, silent push notifications (shouldSendContentAvailable = true) are delivered
    /// through this method while the app is running. Unlike iOS, macOS does not have a
    /// fetchCompletionHandler variant - the app must be running to receive notifications.
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        NSLog("AppDelegate: Received remote notification")

        guard let syncEngine = syncEngine else {
            NSLog("AppDelegate: No sync engine available to handle notification")
            return
        }

        Task {
            let hasChanges = await syncEngine.handleRemoteNotification(userInfo: userInfo)
            NSLog("AppDelegate: Remote notification handled, hasChanges: \(hasChanges)")
        }
    }
}
#endif
