import Foundation
import Combine
import SwiftUI

public enum TaskFilter: String, CaseIterable, Identifiable {
    case active = "Active"
    case queue = "Queue"
    case pushed = "Pushed"
    case all = "All"

    public var id: String { rawValue }
}

public struct StatusBanner: Equatable {
    public let message: String
    public let isError: Bool
    public let timestamp: Date = Date()
}

@MainActor
public final class TaskStore: ObservableObject {
    @Published public var tasks: [TaskItem] = [] {
        didSet {
            saveTasks()
        }
    }

    @Published public var settings: AppSettings = AppSettings() {
        didSet {
            saveSettings()
            scheduleManager.update(settings: settings, lastPushedDate: settings.lastPushedDate)
        }
    }

    @Published public var selectedFilter: TaskFilter = .active
    @Published public var searchText: String = ""
    @Published public var isPushing: Bool = false
    @Published public var statusBanner: StatusBanner? = nil
    @Published public var isSettingsOpen: Bool = false

    public let scheduleManager = ScheduleManager()
    private var scheduleCancellable: AnyCancellable?

    private var storageDirectory: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DisTask", isDirectory: true)
        let legacyDir = appSupport.appendingPathComponent("DiscordTaskBar", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            if fileManager.fileExists(atPath: legacyDir.path) {
                try? fileManager.copyItem(at: legacyDir, to: dir)
            } else {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
        return dir
    }

    public var storageDirectoryPath: String {
        storageDirectory.path
    }

    public func openStorageInFinder() {
        NSWorkspace.shared.open(storageDirectory)
    }

    private var tasksFileURL: URL {
        storageDirectory.appendingPathComponent("tasks.json")
    }

    private var settingsFileURL: URL {
        storageDirectory.appendingPathComponent("settings.json")
    }

    public init() {
        loadSettings()
        loadTasks()

        scheduleManager.update(settings: settings, lastPushedDate: settings.lastPushedDate)

        // Set up the schedule polling timer
        scheduleCancellable = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.checkScheduledPush()
            }
    }

    // MARK: - Computed Properties

    public var filteredTasks: [TaskItem] {
        var result = tasks

        switch selectedFilter {
        case .active:
            result = result.filter { !$0.isCompleted }
        case .queue:
            result = result.filter { $0.isCompleted && !$0.isPushed }
        case .pushed:
            result = result.filter { $0.isCompleted && $0.isPushed }
        case .all:
            break
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) || $0.notes.lowercased().contains(query)
            }
        }

        // Sort: active first, then queue, then pushed; then priority; then creation date
        return result.sorted { t1, t2 in
            if t1.isCompleted != t2.isCompleted {
                return !t1.isCompleted && t2.isCompleted
            }
            if t1.isPushed != t2.isPushed {
                return !t1.isPushed && t2.isPushed
            }
            if t1.priority != t2.priority {
                let pOrder: [Priority: Int] = [.high: 3, .medium: 2, .low: 1]
                return (pOrder[t1.priority] ?? 0) > (pOrder[t2.priority] ?? 0)
            }
            return t1.createdAt > t2.createdAt
        }
    }

    public var activeCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    public var queueCount: Int {
        tasks.filter { $0.isCompleted && !$0.isPushed }.count
    }

    public var pushedCount: Int {
        tasks.filter { $0.isCompleted && $0.isPushed }.count
    }

    public var checkedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    public var checkedPendingPushCount: Int {
        queueCount
    }

    public var menuBarBadgeText: String? {
        guard settings.showCompletedCountInMenuBar else { return nil }
        let queue = queueCount
        return queue > 0 ? "\(queue)" : nil
    }

    // MARK: - Task Actions

    public func addTask(title: String, notes: String = "", priority: Priority = .medium) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newTask = TaskItem(
            title: trimmed,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority
        )
        tasks.insert(newTask, at: 0)
    }

    public func toggleTaskCompletion(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted.toggle()
        if tasks[index].isCompleted {
            tasks[index].completedAt = Date()
            tasks[index].isPushed = false
            tasks[index].pushedAt = nil
        } else {
            tasks[index].completedAt = nil
            tasks[index].isPushed = false
            tasks[index].pushedAt = nil
        }
    }

    public func requeueTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted = true
        tasks[index].isPushed = false
        tasks[index].pushedAt = nil
        showBanner(message: "Task moved back to Push Queue", isError: false)
    }

    public func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    public func updateTask(id: UUID, title: String, notes: String, priority: Priority) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].priority = priority
    }

    public func clearAllChecked() {
        tasks.removeAll { $0.isCompleted }
    }

    public func clearAlreadyPushed() {
        tasks.removeAll { $0.isCompleted && $0.isPushed }
    }

    public func clearPushQueue() {
        // Unchecks tasks in the push queue
        for i in 0..<tasks.count {
            if tasks[i].isCompleted && !tasks[i].isPushed {
                tasks[i].isCompleted = false
                tasks[i].completedAt = nil
            }
        }
    }

    // MARK: - Push Logic

    public func pushCheckedTasks(manual: Bool = false) {
        guard !isPushing else { return }

        // STRICT: Only push tasks that are completed and NOT yet pushed (the queue)
        let targetTasks = tasks.filter { $0.isCompleted && !$0.isPushed }

        guard !targetTasks.isEmpty else {
            showBanner(message: "Push queue is empty. Check (✓) active tasks to queue them!", isError: false)
            return
        }

        let validation = DiscordService.shared.validateWebhookUrl(settings.discordWebhookUrl)
        guard validation.isValid else {
            showBanner(message: validation.error ?? "Please configure Discord Webhook in Settings.", isError: true)
            isSettingsOpen = true
            return
        }

        isPushing = true

        Task {
            do {
                let result = try await DiscordService.shared.sendTasks(
                    tasks: targetTasks,
                    totalActiveCount: self.activeCount,
                    settings: self.settings,
                    isAutomated: !manual
                )
                let successMessage = result.message

                // Move tasks to status "Pushed" and clear the push queue
                let now = Date()
                let targetIds = Set(targetTasks.map { $0.id })
                for i in 0..<self.tasks.count {
                    if targetIds.contains(self.tasks[i].id) {
                        self.tasks[i].isPushed = true
                        self.tasks[i].pushedAt = now
                    }
                }

                if self.settings.clearTasksAfterPush {
                    self.tasks.removeAll { targetIds.contains($0.id) }
                }

                self.settings.lastPushedDate = now
                self.isPushing = false
                self.showBanner(message: "\(successMessage) Moved to Pushed.", isError: false)

                if self.settings.notifyOnPush {
                    NotificationService.shared.postNotification(
                        title: "DisTask",
                        body: successMessage
                    )
                }
            } catch {
                self.isPushing = false
                self.showBanner(message: "Push failed: \(error.localizedDescription)", isError: true)
                if self.settings.notifyOnPush {
                    NotificationService.shared.postNotification(
                        title: "DisTask - Push Failed",
                        body: error.localizedDescription
                    )
                }
            }
        }
    }

    private func checkScheduledPush() {
        let hasPendingQueue = tasks.contains { $0.isCompleted && !$0.isPushed }
        let shouldTrigger = scheduleManager.checkAndTriggerIfNeeded(
            settings: settings,
            hasCheckedTasks: hasPendingQueue,
            lastPushedDate: settings.lastPushedDate
        )

        if shouldTrigger {
            if hasPendingQueue {
                pushCheckedTasks(manual: false)
            } else {
                settings.lastPushedDate = Date()
            }
        }
    }

    public func testConnection() async -> (success: Bool, message: String) {
        do {
            let ok = try await DiscordService.shared.sendTestMessage(settings: settings)
            if ok {
                showBanner(message: "Webhook connected! Check Discord.", isError: false)
                return (true, "Connected successfully!")
            }
            return (false, "Test failed.")
        } catch {
            showBanner(message: error.localizedDescription, isError: true)
            return (false, error.localizedDescription)
        }
    }

    public func testWebhook() async -> (success: Bool, message: String) {
        return await testConnection()
    }

    public func showBanner(message: String, isError: Bool) {
        self.statusBanner = StatusBanner(message: message, isError: isError)
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.statusBanner?.message == message {
                self.statusBanner = nil
            }
        }
    }

    // MARK: - Persistence

    private func loadTasks() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: tasksFileURL.path),
           let data = try? Data(contentsOf: tasksFileURL),
           let loaded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            self.tasks = loaded
        } else {
            self.tasks = [
                TaskItem(title: "New designed category", isCompleted: true, completedAt: Date(), isPushed: false, priority: .high),
                TaskItem(title: "LR fixes", isCompleted: true, completedAt: Date(), isPushed: false, priority: .medium),
                TaskItem(title: "Meeting with Vibhor & Himanshu", isCompleted: true, completedAt: Date(), isPushed: false, priority: .medium),
                TaskItem(title: "Bug fixes", isCompleted: true, completedAt: Date(), isPushed: false, priority: .low)
            ]
        }
    }

    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: tasksFileURL, options: .atomic)
        } catch {
            print("Failed to save tasks: \(error.localizedDescription)")
        }
    }

    private func loadSettings() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: settingsFileURL.path),
           let data = try? Data(contentsOf: settingsFileURL),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = loaded
        } else {
            self.settings = AppSettings()
        }
    }

    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error.localizedDescription)")
        }
    }
}
