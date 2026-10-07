import SwiftUI

public struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore

    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    public var body: some View {
        let tasks = taskStore.filteredTasks

        if tasks.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(tasks) { task in
                        TaskItemRow(taskStore: taskStore, task: task)

                        if task.id != tasks.last?.id {
                            Divider()
                                .opacity(0.4)
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()

            if !taskStore.searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("No tasks found")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Try searching with different terms")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            } else {
                switch taskStore.selectedFilter {
                case .active:
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green.opacity(0.8))
                    Text("All Caught Up!")
                        .font(.system(size: 14, weight: .semibold))
                    Text("No pending active tasks. Add one using the bar above.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                case .queue:
                    Image(systemName: "tray.and.arrow.up")
                        .font(.system(size: 32))
                        .foregroundColor(.orange.opacity(0.8))
                    Text("Push Queue is Empty")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Check off (✓) tasks to add them to the queue. They will be pushed to Discord at \(taskStore.settings.formattedScheduledTime).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                case .pushed:
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.8))
                    Text("No Pushed Tasks Yet")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tasks that have been pushed to Discord will be archived here.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                case .all:
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Your Task List is Empty")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Type a task above and press Return to get started.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
