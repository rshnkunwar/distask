import SwiftUI

public struct TaskInputBar: View {
    @ObservedObject var taskStore: TaskStore

    @State private var taskTitle: String = ""
    @State private var taskNotes: String = ""
    @State private var priority: Priority = .medium
    @State private var showNotesField: Bool = false
    @FocusState private var isTitleFocused: Bool

    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                    .font(.system(size: 16))

                TextField("Add a new task (press Return)...", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isTitleFocused)
                    .onSubmit {
                        submitTask()
                    }

                // Priority picker button
                Menu {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Label(p.rawValue, systemImage: p.iconName).tag(p)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: priority.iconName)
                            .font(.system(size: 9, weight: .bold))
                        Text(priority.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(priority.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(priority.color.opacity(0.12))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Toggle notes button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNotesField.toggle()
                    }
                } label: {
                    Image(systemName: showNotesField ? "note.text.badge.plus" : "note.text")
                        .font(.system(size: 12))
                        .foregroundColor(showNotesField ? Color(red: 0.35, green: 0.40, blue: 0.95) : .secondary)
                }
                .buttonStyle(.plain)
                .help("Add notes or details")

                // Add button
                Button {
                    submitTask()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary.opacity(0.4) : Color(red: 0.35, green: 0.40, blue: 0.95))
                }
                .buttonStyle(.plain)
                .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTitleFocused ? Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )

            // Optional notes expanded field
            if showNotesField {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    TextField("Optional notes or context for Discord...", text: $taskNotes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit {
                            submitTask()
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func submitTask() {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        taskStore.addTask(
            title: trimmed,
            notes: taskNotes,
            priority: priority
        )

        taskTitle = ""
        taskNotes = ""
        priority = .medium
        showNotesField = false
        isTitleFocused = true
    }
}
