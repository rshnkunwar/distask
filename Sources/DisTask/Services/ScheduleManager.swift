import Foundation
import Combine

@MainActor
public final class ScheduleManager: ObservableObject {
    @Published public private(set) var nextPushDescription: String = "Calculating..."
    @Published public private(set) var timeRemainingString: String = ""

    private var timer: AnyCancellable?
    private var onTrigger: (() -> Void)?

    public init() {}

    public func start(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        timer?.cancel()
        timer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        tick()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func update(settings: AppSettings, lastPushedDate: Date?) {
        updateDescriptions(settings: settings, lastPushedDate: lastPushedDate)
    }

    public func checkAndTriggerIfNeeded(settings: AppSettings, hasCheckedTasks: Bool, lastPushedDate: Date?) -> Bool {
        guard settings.isScheduleEnabled else {
            updateDescriptions(settings: settings, lastPushedDate: lastPushedDate)
            return false
        }

        let calendar = Calendar.current
        let now = Date()

        // Check weekday condition
        if settings.scheduleDays == .weekdaysOnly {
            let weekday = calendar.component(.weekday, from: now)
            // 1 is Sunday, 7 is Saturday in standard Gregorian calendar
            if weekday == 1 || weekday == 7 {
                updateDescriptions(settings: settings, lastPushedDate: lastPushedDate)
                return false
            }
        }

        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        let isTargetTime = (currentHour == settings.scheduledHour && currentMinute == settings.scheduledMinute)

        // Prevent multiple fires on the same calendar day
        var alreadyPushedToday = false
        if let lastPush = lastPushedDate {
            alreadyPushedToday = calendar.isDate(lastPush, inSameDayAs: now)
        }

        if isTargetTime && !alreadyPushedToday {
            onTrigger?()
            updateDescriptions(settings: settings, lastPushedDate: now)
            return true
        }

        updateDescriptions(settings: settings, lastPushedDate: lastPushedDate)
        return false
    }

    private func tick() {
        // Will be triggered by TaskStore passing latest settings
    }

    public func updateDescriptions(settings: AppSettings, lastPushedDate: Date?) {
        guard settings.isScheduleEnabled else {
            nextPushDescription = "Scheduled push is paused"
            timeRemainingString = "Disabled"
            return
        }

        let calendar = Calendar.current
        let now = Date()

        var targetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        targetComponents.hour = settings.scheduledHour
        targetComponents.minute = settings.scheduledMinute
        targetComponents.second = 0

        guard var nextDate = calendar.date(from: targetComponents) else {
            nextPushDescription = "Invalid schedule time"
            timeRemainingString = ""
            return
        }

        // If today's target time has already passed, target tomorrow
        if nextDate <= now {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: nextDate) {
                nextDate = tomorrow
            }
        }

        // If weekdays only, skip Saturday (7) and Sunday (1)
        if settings.scheduleDays == .weekdaysOnly {
            while true {
                let weekday = calendar.component(.weekday, from: nextDate)
                if weekday != 1 && weekday != 7 {
                    break
                }
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: nextDate) {
                    nextDate = nextDay
                } else {
                    break
                }
            }
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dayLabel: String
        if calendar.isDateInToday(nextDate) {
            dayLabel = "Today"
        } else if calendar.isDateInTomorrow(nextDate) {
            dayLabel = "Tomorrow"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            dayLabel = dayFormatter.string(from: nextDate)
        }

        let diff = calendar.dateComponents([.day, .hour, .minute], from: now, to: nextDate)
        let days = diff.day ?? 0
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0

        var remainingParts: [String] = []
        if days > 0 { remainingParts.append("\(days)d") }
        if hours > 0 { remainingParts.append("\(hours)h") }
        remainingParts.append("\(max(1, minutes))m")

        let remainingStr = remainingParts.joined(separator: " ")
        timeRemainingString = remainingStr
        nextPushDescription = "\(dayLabel) at \(timeFormatter.string(from: nextDate)) (\(remainingStr))"
    }
}
