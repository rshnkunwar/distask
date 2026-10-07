import SwiftUI

public struct TaskItemRow: View {
    @ObservedObject var taskStore: TaskStore
    let task: TaskItem

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editTitle: String = ""
    @State private var editNotes: String = ""
    @State private var editPriority: Priority = .medium

    public init(taskStore: TaskStore, task: TaskItem) {
        self.taskStore = taskStore
        self.task = task
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    taskStore.toggleTaskCompletion(id: task.id)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 13, weight: task.isCompleted ? .regular : .medium))
                        .strikethrough(task.isCompleted, color: .secondary.opacity(0.8))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .lineLimit(2)

                    Spacer(minLength: 4)

                    // Priority Tag
                    priorityBadge(task.priority)
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Status info tags
                HStack(spacing: 8) {
                    if task.isCompleted {
                        if let doneAt = task.completedAt {
                            Label("Done at \(timeString(doneAt))", systemImage: "clock")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }

                        if task.isPushed {
                            let pushText = task.pushedAt != nil ? "Pushed at \(timeString(task.pushedAt!))" : "Pushed"
                            Label(pushText, systemImage: "checkmark.seal.fill")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.12))
                                .cornerRadius(4)
                        } else {
                            Label("In Push Queue", systemImage: "tray.and.arrow.up.fill")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Hover Action Buttons
            if isHovered {
                HStack(spacing: 4) {
                    if task.isPushed {
                        Button {
                            withAnimation {
                                taskStore.requeueTask(id: task.id)
                            }
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Move back to Push Queue")
                    }

                    Button {
                        editTitle = task.title
                        editNotes = task.notes
                        editPriority = task.priority
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isEditing, arrowEdge: .trailing) {
                        editPopoverView
                    }

                    Button {
                        withAnimation {
                            taskStore.deleteTask(id: task.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func priorityBadge(_ priority: Priority) -> some View {
        HStack(spacing: 2) {
            Image(systemName: priority.iconName)
                .font(.system(size: 8, weight: .bold))
            Text(priority.rawValue)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(priority.color.opacity(0.15))
        .foregroundColor(priority.color)
        .cornerRadius(4)
    }

    private var editPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit Task")
                .font(.system(size: 12, weight: .bold))

            TextField("Task title", text: $editTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Notes (optional)", text: $editNotes)
                .textFieldStyle(.roundedBorder)

            Picker("Priority", selection: $editPriority) {
                ForEach(Priority.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Save") {
                    taskStore.updateTask(
                        id: task.id,
                        title: editTitle,
                        notes: editNotes,
                        priority: editPriority
                    )
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
