import Foundation
import AppKit
import ApplicationServices
import Combine

@MainActor
public final class PermissionService: ObservableObject {
    public static let shared = PermissionService()

    @Published public var isAccessibilityGranted: Bool = false
    @Published public var isNotificationGranted: Bool = false
    @Published public var hasCheckedInitially: Bool = false
    @Published public var bypassNotificationsForTesting: Bool = false

    private var pollTimer: AnyCancellable?

    public init() {
        checkAll()
        startPolling()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAll()
            }
        }
    }

    public var isFullyAuthorized: Bool {
        // Webhook mode operates purely over HTTP and does not require macOS Accessibility permissions.
        return true
    }

    public func checkAll() {
        checkAccessibility()
        checkNotification()
        hasCheckedInitially = true
    }

    public func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if isAccessibilityGranted != trusted {
            isAccessibilityGranted = trusted
        }
    }

    public func checkNotification() {
        NotificationService.shared.checkAuthorizationStatus { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isNotificationGranted != granted {
                    self.isNotificationGranted = granted
                }
            }
        }
    }

    public func startPolling() {
        pollTimer?.cancel()
        pollTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.checkAccessibility()
                self.checkNotification()
            }
    }

    public func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    public func requestAccessibilityPermission() {
        // Trigger macOS system accessibility prompt using the standard string key
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Open macOS System Settings directly to Privacy & Security > Accessibility
        openAccessibilitySettings()
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func requestNotificationPermission() {
        NotificationService.shared.requestAuthorization { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isNotificationGranted = granted
                if !granted {
                    self.openNotificationSettings()
                }
            }
        }
    }

    public func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
