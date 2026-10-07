import SwiftUI

public struct TaskFilterBar: View {
    @ObservedObject var taskStore: TaskStore
    @State private var showSearch: Bool = false

    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                // Segmented tab controls
                HStack(spacing: 2) {
                    filterTab(title: "Active", count: taskStore.activeCount, filter: .active)
                    filterTab(title: "Queue", count: taskStore.queueCount, filter: .queue)
                    filterTab(title: "Pushed", count: taskStore.pushedCount, filter: .pushed)
                    filterTab(title: "All", count: taskStore.tasks.count, filter: .all)
                }
                .padding(2)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(7)

                Spacer()

                // Search toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showSearch.toggle()
                        if !showSearch {
                            taskStore.searchText = ""
                        }
                    }
                } label: {
                    Image(systemName: showSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(showSearch ? Color(red: 0.35, green: 0.40, blue: 0.95) : .secondary)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .help("Search tasks")

                // More actions menu
                if (taskStore.selectedFilter == .pushed && taskStore.pushedCount > 0) ||
                   (taskStore.selectedFilter == .queue && taskStore.queueCount > 0) {
                    Menu {
                        if taskStore.selectedFilter == .pushed {
                            Button("Clear All Pushed Tasks") {
                                withAnimation {
                                    taskStore.clearAlreadyPushed()
                                }
                            }
                        }
                        if taskStore.selectedFilter == .queue {
                            Button("Clear Push Queue (Uncheck All)") {
                                withAnimation {
                                    taskStore.clearPushQueue()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            // Search textfield if toggled
            if showSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    TextField("Search tasks...", text: $taskStore.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !taskStore.searchText.isEmpty {
                        Button {
                            taskStore.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func filterTab(title: String, count: Int, filter: TaskFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                taskStore.selectedFilter = filter
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10.5, weight: taskStore.selectedFilter == filter ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(taskStore.selectedFilter == filter ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
                    )
            }
            .foregroundColor(taskStore.selectedFilter == filter ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(taskStore.selectedFilter == filter ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                    .shadow(color: taskStore.selectedFilter == filter ? Color.black.opacity(0.06) : Color.clear, radius: 1, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
