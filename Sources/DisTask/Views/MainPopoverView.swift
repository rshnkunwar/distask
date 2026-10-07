import SwiftUI

public struct MainPopoverView: View {
    @ObservedObject var taskStore: TaskStore
    @StateObject private var permissionService = PermissionService.shared

    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    public var body: some View {
        Group {
            if !permissionService.isFullyAuthorized {
                PermissionGateView(permissionService: permissionService)
                    .transition(.opacity)
            } else {
                mainContentView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: permissionService.isFullyAuthorized)
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header
            MenuBarHeaderView(taskStore: taskStore)

            Divider()

            // Status Banner (Toast)
            if let banner = taskStore.statusBanner {
                HStack(spacing: 8) {
                    Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(banner.isError ? .red : .green)
                        .font(.system(size: 12))

                    Text(banner.message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(banner.isError ? .red : .green)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        taskStore.statusBanner = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((banner.isError ? Color.red : Color.green).opacity(0.12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if taskStore.isSettingsOpen {
                SettingsSheetView(taskStore: taskStore)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    // Quick Task Input
                    TaskInputBar(taskStore: taskStore)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    // Filters
                    TaskFilterBar(taskStore: taskStore)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)

                    Divider()

                    // Task List
                    TaskListView(taskStore: taskStore)
                        .frame(maxHeight: .infinity)

                    Divider()

                    // Footer Summary Bar
                    footerBar
                }
            }
        }
        .frame(width: 380, height: 490)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var footerBar: some View {
        HStack(spacing: 10) {
            // Progress Bar & Count
            let total = taskStore.tasks.count
            let completed = taskStore.checkedCount
            let percentage = total > 0 ? Double(completed) / Double(total) : 0.0

            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color.green, Color(red: 0.35, green: 0.85, blue: 0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(0, geo.size.width * CGFloat(percentage)), height: 5)
                    }
                }
                .frame(width: 60, height: 5)

                Text("\(completed)/\(total) done (\(Int(percentage * 100))%)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Pending push status
            let pendingCount = taskStore.checkedPendingPushCount
            if pendingCount > 0 {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(pendingCount) ready to push")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9))
                    Text("Up to date")
                        .font(.system(size: 10.5))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}
