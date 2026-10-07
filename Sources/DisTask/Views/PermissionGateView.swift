import SwiftUI
import AppKit

public struct PermissionGateView: View {
    @ObservedObject var permissionService: PermissionService
    @State private var isPulsing: Bool = false

    public init(permissionService: PermissionService = .shared) {
        self.permissionService = permissionService
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Content
            ScrollView {
                VStack(spacing: 16) {
                    // Hero Banner
                    heroBanner

                    // Permission Cards
                    VStack(spacing: 10) {
                        accessibilityCard
                        notificationCard
                    }
                    .padding(.horizontal, 14)

                    // Real-time detector status
                    detectorStatus
                }
                .padding(.vertical, 16)
            }

            Divider()

            // Footer Actions
            footerActions
        }
        .frame(width: 380, height: 490)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            permissionService.checkAll()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 8) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.20, green: 0.25, blue: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 22, height: 22)
            .cornerRadius(6)

            Text("Setup & Permissions")
                .font(.system(size: 13, weight: .bold))

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Quit DisTask")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    private var heroBanner: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 15,
                            endRadius: 40
                        )
                    )
                    .frame(width: 76, height: 76)
                    .scaleEffect(isPulsing ? 1.08 : 0.96)

                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.28, green: 0.32, blue: 0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .cornerRadius(14)
                .shadow(color: Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.35), radius: 8, y: 3)
            }

            Text("Permissions Required")
                .font(.system(size: 16, weight: .bold))

            Text("DisTask needs macOS permissions to deliver scheduled reminders and push alerts.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var accessibilityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "computermouse.fill")
                        .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                        .font(.system(size: 13))

                    Text("Accessibility Access")
                        .font(.system(size: 12, weight: .bold))
                }

                Spacer()

                if permissionService.isAccessibilityGranted {
                    statusBadge(text: "Granted", icon: "checkmark.circle.fill", color: .green)
                } else {
                    statusBadge(text: "Required", icon: "exclamationmark.circle.fill", color: .red)
                }
            }

            Text("Allows DisTask to provide enhanced system integration and push alerts.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !permissionService.isAccessibilityGranted {
                Button {
                    permissionService.requestAccessibilityPermission()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Grant Accessibility Access")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.28, green: 0.32, blue: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(permissionService.isAccessibilityGranted ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))

                    Text("System Notifications")
                        .font(.system(size: 12, weight: .bold))
                }

                Spacer()

                if permissionService.isNotificationGranted {
                    statusBadge(text: "Granted", icon: "checkmark.circle.fill", color: .green)
                } else {
                    statusBadge(text: "Recommended", icon: "bell.fill", color: .orange)
                }
            }

            Text("Provides alert banners when tasks are automatically pushed at your scheduled daily time.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !permissionService.isNotificationGranted {
                HStack(spacing: 8) {
                    Button {
                        permissionService.requestNotificationPermission()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 11))
                            Text("Allow Notifications")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        permissionService.bypassNotificationsForTesting = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(permissionService.isNotificationGranted ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var detectorStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(permissionService.isAccessibilityGranted ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing ? 1.2 : 0.8)

            Text(permissionService.isAccessibilityGranted ?
                 "Permissions granted! Unlocking app..." :
                 "Listening for changes in System Settings...")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    private var footerActions: some View {
        HStack {
            Button {
                permissionService.checkAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10.5))
                    Text("Check Permissions Now")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Quit App") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func statusBadge(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(5)
    }
}
