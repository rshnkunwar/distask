import Foundation

public enum ScheduleFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case everyday = "Every Day"
    case weekdaysOnly = "Weekdays Only"

    public var id: String { rawValue }
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
        lastPushedDate: Date? = nil
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
