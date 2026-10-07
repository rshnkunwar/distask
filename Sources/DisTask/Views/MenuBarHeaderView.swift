import SwiftUI
import AppKit

public struct MenuBarHeaderView: View {
    @ObservedObject var taskStore: TaskStore

    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    public var body: some View {
        HStack(spacing: 8) {
            // App branding
            HStack(spacing: 6) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.20, green: 0.25, blue: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 22, height: 22)
                .cornerRadius(6)

                Text("DisTask")
                    .font(.system(size: 13, weight: .bold))
            }

            Spacer()

            // Schedule status badge
            schedulePill

            // Quick Push Button
            pushButton

            // Settings button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    taskStore.isSettingsOpen.toggle()
                }
            } label: {
                Image(systemName: taskStore.isSettingsOpen ? "xmark.circle.fill" : "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(taskStore.isSettingsOpen ? Color(red: 0.35, green: 0.40, blue: 0.95) : .secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help(taskStore.isSettingsOpen ? "Close settings" : "Open settings")

            // Quit App Button
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    private var schedulePill: some View {
        HStack(spacing: 3) {
            Image(systemName: taskStore.settings.isScheduleEnabled ? "clock.fill" : "clock.badge.xmark")
                .font(.system(size: 9))
            Text(taskStore.scheduleManager.timeRemainingString.isEmpty ? taskStore.settings.formattedScheduledTime : taskStore.scheduleManager.timeRemainingString)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(taskStore.settings.isScheduleEnabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
        .foregroundColor(taskStore.settings.isScheduleEnabled ? .green : .secondary)
        .cornerRadius(5)
        .help(taskStore.scheduleManager.nextPushDescription)
    }

    private var pushButton: some View {
        let pending = taskStore.checkedPendingPushCount
        return Button {
            taskStore.pushCheckedTasks(manual: true)
        } label: {
            HStack(spacing: 4) {
                if taskStore.isPushing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 9.5))
                }

                Text(pending > 0 ? "Push (\(pending))" : "Push Now")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.28, green: 0.32, blue: 0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(taskStore.isPushing || pending == 0)
        .opacity(pending == 0 ? 0.45 : 1.0)
        .help(pending > 0 ? "Push \(pending) queued task\(pending == 1 ? "" : "s") to Discord" : "Push queue is empty")
    }
}
