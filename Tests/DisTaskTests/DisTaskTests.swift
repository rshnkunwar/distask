import Testing
import Foundation
@testable import DisTask

@Suite("DisTask End-To-End Test Suite")
struct DisTaskTests {

    let sampleWebhookUrl = "https://discord.com/api/webhooks/123456789012345678/sample_token_abcdefghijklmnopqrstuvwxyz"

    // MARK: - 1. Discord URL & Validation Tests

    @Test("Discord Webhook URL validation")
    func testWebhookValidation() {
        let service = DiscordService.shared

        #expect(!service.validateWebhookUrl("").isValid)
        #expect(!service.validateWebhookUrl("   ").isValid)
        #expect(!service.validateWebhookUrl("https://example.com/api/webhooks/123/abc").isValid)
        #expect(!service.validateWebhookUrl("https://discord.com/channels/123/456").isValid)
        #expect(service.validateWebhookUrl("https://discord.com/api/webhooks/123456789/abcdefghijk").isValid)
        #expect(service.validateWebhookUrl("https://discordapp.com/api/webhooks/123456789/abcdefghijk").isValid)
        #expect(service.validateWebhookUrl(sampleWebhookUrl).isValid)
    }

    // MARK: - 2. Task Model & Serialization

    @Test("TaskItem JSON Encoding, Decoding, and Equality")
    func testTaskSerialization() throws {
        let original = TaskItem(
            title: "Ship macOS Menu Bar App",
            notes: "Ensure LSUIElement and Discord automation work",
            isCompleted: true,
            completedAt: Date(),
            isPushed: false,
            priority: .high
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskItem.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.notes == original.notes)
        #expect(decoded.isCompleted == original.isCompleted)
        #expect(decoded.isPushed == original.isPushed)
        #expect(decoded.priority == original.priority)
    }

    // MARK: - 3. End-To-End Task Lifecycle

    @Test("TaskStore End-To-End Lifecycle (Add, Edit, Complete, Filter, Delete)")
    @MainActor
    func testTaskStoreLifecycle() {
        let store = TaskStore()
        store.tasks.removeAll()

        // 1. Add tasks with various priorities
        store.addTask(title: "New designed category", notes: "UI revamp", priority: .high)
        store.addTask(title: "LR fixes", notes: "", priority: .medium)
        store.addTask(title: "Meeting with team", notes: "Sync at 4pm", priority: .medium)
        store.addTask(title: "Bug fixes", notes: "Resolve crash on launch", priority: .low)

        #expect(store.tasks.count == 4)
        #expect(store.activeCount == 4)
        #expect(store.checkedCount == 0)
        #expect(store.checkedPendingPushCount == 0)

        // 2. Check 3 tasks
        guard let task1 = store.tasks.first(where: { $0.title == "New designed category" }),
              let task2 = store.tasks.first(where: { $0.title == "LR fixes" }),
              let task3 = store.tasks.first(where: { $0.title == "Bug fixes" }) else {
            Issue.record("Failed to find added tasks")
            return
        }

        store.toggleTaskCompletion(id: task1.id)
        store.toggleTaskCompletion(id: task2.id)
        store.toggleTaskCompletion(id: task3.id)

        #expect(store.checkedCount == 3)
        #expect(store.activeCount == 1)
        #expect(store.checkedPendingPushCount == 3)
        #expect(store.menuBarBadgeText == "3")

        // 3. Filtering
        store.selectedFilter = .active
        #expect(store.filteredTasks.count == 1)
        #expect(store.filteredTasks.first?.title == "Meeting with team")

        store.selectedFilter = .queue
        #expect(store.filteredTasks.count == 3)

        store.selectedFilter = .pushed
        #expect(store.filteredTasks.count == 0)

        store.selectedFilter = .all
        #expect(store.filteredTasks.count == 4)

        // 4. Searching
        store.searchText = "team"
        #expect(store.filteredTasks.count == 1)
        #expect(store.filteredTasks.first?.title.contains("team") == true)
        store.searchText = ""

        // 5. Edit task
        store.updateTask(id: task2.id, title: "LR fixes updated", notes: "Added notes", priority: .high)
        let updatedTask2 = store.tasks.first(where: { $0.id == task2.id })
        #expect(updatedTask2?.title == "LR fixes updated")
        #expect(updatedTask2?.notes == "Added notes")
        #expect(updatedTask2?.priority == .high)

        // 6. Delete task
        store.deleteTask(id: task3.id)
        #expect(store.tasks.count == 3)
        #expect(store.checkedCount == 2)
    }

    // MARK: - 4. Message Formatting (Code Block & Plain)

    @Test("Tasks formatted in exact code block format requested by user")
    func testFormatTasksCodeBlock() {
        let tasks = [
            TaskItem(title: "New designed category", isCompleted: true),
            TaskItem(title: "LR fixes", isCompleted: true),
            TaskItem(title: "Meeting with team", isCompleted: true),
            TaskItem(title: "Bug fixes", isCompleted: true)
        ]

        let message = DiscordService.shared.formatTasksMessage(tasks: tasks)

        let lines = message.components(separatedBy: "\n")
        #expect(lines.first == "```")
        #expect(lines.last == "```")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let expectedDate = dateFormatter.string(from: Date())
        #expect(lines[1] == expectedDate)

        #expect(lines.contains("- New designed category"))
        #expect(lines.contains("- LR fixes"))
        #expect(lines.contains("- Meeting with team"))
        #expect(lines.contains("- Bug fixes"))
    }

    @Test("Custom code block template and task line formatting")
    func testCustomCodeBlockFormatting() {
        let tasks = [
            TaskItem(title: "Design System Refactor", notes: "Use glassmorphism", isCompleted: true, priority: .high),
            TaskItem(title: "Fix Discord Push Bug", isCompleted: true, priority: .medium)
        ]

        var customSettings = AppSettings()
        customSettings.messageTemplate = "```md\n# {date} ({count} tasks)\n{tasks}\n```"
        customSettings.taskLineFormat = "- [x] {title}"
        customSettings.dateFormat = "yyyy-MM-dd"

        let message = DiscordService.shared.formatTasksMessage(tasks: tasks, includeNotes: true, settings: customSettings)

        let lines = message.components(separatedBy: "\n")
        #expect(lines.first == "```md")
        #expect(lines.last == "```")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = dateFormatter.string(from: Date())

        #expect(lines[1] == "# \(expectedDate) (2 tasks)")
        #expect(lines.contains("- [x] Design System Refactor (Use glassmorphism)"))
        #expect(lines.contains("- [x] Fix Discord Push Bug"))
    }

    @Test("Custom non-code-block Markdown list template")
    func testCustomMarkdownListTemplate() {
        let tasks = [
            TaskItem(title: "Sprint Planning", isCompleted: true)
        ]

        var customSettings = AppSettings()
        customSettings.messageTemplate = "**Daily Status - {date}**\n{tasks}"
        customSettings.taskLineFormat = "• {title}"

        let message = DiscordService.shared.formatTasksMessage(tasks: tasks, settings: customSettings)

        #expect(!message.contains("```"))
        #expect(message.contains("• Sprint Planning"))
        #expect(message.hasPrefix("**Daily Status - "))
    }

    // MARK: - 5. Schedule Engine & Anti-Duplicate Trigger

    @Test("ScheduleManager Next Push and Anti-Duplicate Trigger")
    @MainActor
    func testScheduleEngine() {
        let manager = ScheduleManager()
        var settings = AppSettings()

        // 1. Paused state
        settings.isScheduleEnabled = false
        manager.update(settings: settings, lastPushedDate: nil)
        #expect(manager.nextPushDescription.contains("paused"))
        #expect(manager.timeRemainingString == "Disabled")

        // 2. Active schedule
        settings.isScheduleEnabled = true
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        settings.scheduledHour = currentHour
        settings.scheduledMinute = currentMinute

        // Trigger should succeed when target time matches and not pushed today
        let triggered = manager.checkAndTriggerIfNeeded(settings: settings, hasCheckedTasks: true, lastPushedDate: nil)
        #expect(triggered == true)

        // Trigger should NOT re-fire on the same calendar day (anti-duplicate guard)
        let reTrigger = manager.checkAndTriggerIfNeeded(settings: settings, hasCheckedTasks: true, lastPushedDate: now)
        #expect(reTrigger == false)
    }

    // MARK: - 6. Webhook Payload & Validation

    @Test("Discord Webhook payload and URL validation")
    func testDiscordWebhookPayload() {
        var settings = AppSettings()
        settings.discordWebhookUrl = sampleWebhookUrl
        settings.botUsername = "TaskBar Bot"

        let validation = DiscordService.shared.validateWebhookUrl(settings.discordWebhookUrl)
        #expect(validation.isValid == true)

        let tasks = [
            TaskItem(title: "New designed category", isCompleted: true),
            TaskItem(title: "LR fixes", isCompleted: true)
        ]

        let message = DiscordService.shared.formatTasksMessage(tasks: tasks)
        #expect(message.hasPrefix("```"))
        #expect(message.hasSuffix("```"))
        #expect(message.contains("- New designed category"))
        #expect(message.contains("- LR fixes"))
    }

    // MARK: - 7. TaskStore Push & Queue Management

    @Test("TaskStore Push Queue and Status Transitions")
    @MainActor
    func testTaskStorePushFlowEndToEnd() {
        let store = TaskStore()
        store.tasks.removeAll()

        store.addTask(title: "New designed category", priority: .high)
        store.addTask(title: "LR fixes", priority: .medium)

        for task in store.tasks {
            store.toggleTaskCompletion(id: task.id)
        }

        #expect(store.checkedPendingPushCount == 2)
        #expect(store.queueCount == 2)
        #expect(store.pushedCount == 0)

        // Simulate successful push archive transition
        let now = Date()
        for i in 0..<store.tasks.count {
            store.tasks[i].isPushed = true
            store.tasks[i].pushedAt = now
        }

        #expect(store.checkedPendingPushCount == 0)
        #expect(store.queueCount == 0)
        #expect(store.pushedCount == 2)
        #expect(store.tasks.allSatisfy { $0.isPushed == true })

        // Test re-queueing
        let firstId = store.tasks[0].id
        store.requeueTask(id: firstId)
        #expect(store.queueCount == 1)
        #expect(store.pushedCount == 1)
    }

    // MARK: - 8. Permission Service State

    @Test("PermissionService initialization and checking")
    @MainActor
    func testPermissionService() {
        let perm = PermissionService.shared
        perm.checkAll()
        #expect(perm.hasCheckedInitially == true)
    }
}
