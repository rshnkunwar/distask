import Foundation

public enum ScheduleFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case everyday = "Every Day"
    case weekdaysOnly = "Weekdays Only"

    public var id: String { rawValue }
}

public enum MessageFormatPreset: String, CaseIterable, Identifiable, Sendable {
    case codeBlock = "Code Block"
    case codeBlockMd = "Code Block (md)"
    case bulletList = "Markdown List"
    case checklist = "Checklist"
    case custom = "Custom"

    public var id: String { rawValue }

    public var template: String {
        switch self {
        case .codeBlock:
            return "```\n{date}\n{tasks}\n```"
        case .codeBlockMd:
            return "```md\n# {date}\n{tasks}\n```"
        case .bulletList:
            return "**Completed Tasks ({date}):**\n{tasks}"
        case .checklist:
            return "**{date} Updates ({count} tasks):**\n{tasks}"
        case .custom:
            return ""
        }
    }

    public var defaultTaskFormat: String {
        switch self {
        case .checklist:
            return "- [x] {title}"
        default:
            return "- {title}"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var discordWebhookUrl: String
    public var botUsername: String
    public var avatarUrl: String
    public var scheduledHour: Int
    public var scheduledMinute: Int
    public var isScheduleEnabled: Bool
    public var scheduleDays: ScheduleFrequency
    public var includeNotesInDiscord: Bool
    public var clearTasksAfterPush: Bool
    public var notifyOnPush: Bool
    public var showCompletedCountInMenuBar: Bool
    public var lastPushedDate: Date?

    // Format customization
    public var messageTemplate: String
    public var taskLineFormat: String
    public var dateFormat: String

    public init(
        discordWebhookUrl: String = "",
        botUsername: String = "DisTask Bot",
        avatarUrl: String = "",
        scheduledHour: Int = 17,
        scheduledMinute: Int = 0,
        isScheduleEnabled: Bool = true,
        scheduleDays: ScheduleFrequency = .everyday,
        includeNotesInDiscord: Bool = true,
        clearTasksAfterPush: Bool = false,
        notifyOnPush: Bool = true,
        showCompletedCountInMenuBar: Bool = true,
        lastPushedDate: Date? = nil,
        messageTemplate: String = "```\n{date}\n{tasks}\n```",
        taskLineFormat: String = "- {title}",
        dateFormat: String = "MMM d"
    ) {
        self.discordWebhookUrl = discordWebhookUrl
        self.botUsername = botUsername
        self.avatarUrl = avatarUrl
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.isScheduleEnabled = isScheduleEnabled
        self.scheduleDays = scheduleDays
        self.includeNotesInDiscord = includeNotesInDiscord
        self.clearTasksAfterPush = clearTasksAfterPush
        self.notifyOnPush = notifyOnPush
        self.showCompletedCountInMenuBar = showCompletedCountInMenuBar
        self.lastPushedDate = lastPushedDate
        self.messageTemplate = messageTemplate
        self.taskLineFormat = taskLineFormat
        self.dateFormat = dateFormat
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.discordWebhookUrl = try container.decodeIfPresent(String.self, forKey: .discordWebhookUrl) ?? ""
        self.botUsername = try container.decodeIfPresent(String.self, forKey: .botUsername) ?? "DisTask Bot"
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl) ?? ""
        self.scheduledHour = try container.decodeIfPresent(Int.self, forKey: .scheduledHour) ?? 17
        self.scheduledMinute = try container.decodeIfPresent(Int.self, forKey: .scheduledMinute) ?? 0
        self.isScheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .isScheduleEnabled) ?? true
        self.scheduleDays = try container.decodeIfPresent(ScheduleFrequency.self, forKey: .scheduleDays) ?? .everyday
        self.includeNotesInDiscord = try container.decodeIfPresent(Bool.self, forKey: .includeNotesInDiscord) ?? true
        self.clearTasksAfterPush = try container.decodeIfPresent(Bool.self, forKey: .clearTasksAfterPush) ?? false
        self.notifyOnPush = try container.decodeIfPresent(Bool.self, forKey: .notifyOnPush) ?? true
        self.showCompletedCountInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showCompletedCountInMenuBar) ?? true
        self.lastPushedDate = try container.decodeIfPresent(Date.self, forKey: .lastPushedDate)

        self.messageTemplate = try container.decodeIfPresent(String.self, forKey: .messageTemplate) ?? "```\n{date}\n{tasks}\n```"
        self.taskLineFormat = try container.decodeIfPresent(String.self, forKey: .taskLineFormat) ?? "- {title}"
        self.dateFormat = try container.decodeIfPresent(String.self, forKey: .dateFormat) ?? "MMM d"
    }

    public var formattedScheduledTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = scheduledHour
        components.minute = scheduledMinute
        let calendar = Calendar.current
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return String(format: "%02d:%02d", scheduledHour, scheduledMinute)
    }

    public var scheduledDate: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = scheduledHour
        components.minute = scheduledMinute
        return Calendar.current.date(from: components) ?? Date()
    }
}
