import Foundation
import UserNotifications

public final class NotificationService: @unchecked Sendable {
    public static let shared = NotificationService()

    private var isSupported: Bool {
        // UNUserNotificationCenter requires a valid bundle identifier;
        // command line processes or SPM test runners do not have one and will crash.
        return Bundle.main.bundleIdentifier != nil
    }

    private init() {
        if isSupported {
            requestAuthorization()
        }
    }

    public func checkAuthorizationStatus(completion: @escaping @Sendable (Bool) -> Void) {
        guard isSupported else {
            completion(true)
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = (settings.authorizationStatus == .authorized)
            DispatchQueue.main.async {
                completion(isAuthorized)
            }
        }
    }

    public func requestAuthorization(completion: (@Sendable (Bool) -> Void)? = nil) {
        guard isSupported else {
            completion?(true)
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    public func postNotification(title: String, body: String) {
        guard isSupported else {
            print("Local notification [\(title)]: \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // delivers immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
}
