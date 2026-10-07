import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run purely as an accessory (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct DisTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var taskStore = TaskStore()

    var body: some Scene {
        MenuBarExtra {
            MainPopoverView(taskStore: taskStore)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                if let badge = taskStore.menuBarBadgeText {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
