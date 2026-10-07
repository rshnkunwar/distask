import Foundation

public struct DiscordPushResult: Sendable {
    public let success: Bool
    public let message: String
    public let taskCount: Int
}

public final class DiscordService: Sendable {
    public static let shared = DiscordService()

    private init() {}

    public func validateWebhookUrl(_ urlString: String) -> (isValid: Bool, error: String?) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, "Webhook URL cannot be empty.")
        }
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return (false, "Invalid URL format.")
        }
        guard host.contains("discord.com") || host.contains("discordapp.com") else {
            return (false, "URL must be a valid Discord webhook URL (discord.com).")
        }
        guard url.path.contains("/api/webhooks/") else {
            return (false, "URL must follow Discord webhook format: /api/webhooks/<id>/<token>")
        }
        return (true, nil)
    }

    private func sanitizedUsername(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "TaskBar Bot"
        }
        // Discord API strictly forbids "discord" in webhook usernames
        if name.lowercased().contains("discord") {
            name = name.replacingOccurrences(of: "discord", with: "Task", options: .caseInsensitive)
        }
        name = name.replacingOccurrences(of: "@everyone", with: "everyone")
        name = name.replacingOccurrences(of: "@here", with: "here")
        let result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "TaskBar Bot" : result
    }

    private func sanitizedAvatarUrl(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.hasPrefix("https://") else { return nil }
        if trimmed.hasSuffix(".png") || trimmed.hasSuffix(".jpg") || trimmed.hasSuffix(".jpeg") || trimmed.hasSuffix(".webp") {
            return trimmed
        }
        return nil
    }

    public func formatTasksMessage(
        tasks: [TaskItem],
        includeNotes: Bool = false,
        settings: AppSettings? = nil
    ) -> String {
        let appSettings = settings ?? AppSettings()
        let dateFormatPattern = appSettings.dateFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "MMM d" : appSettings.dateFormat

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormatPattern
        let dateString = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: Date())

        let rawTaskFormat = appSettings.taskLineFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskFormat = rawTaskFormat.isEmpty ? "- {title}" : rawTaskFormat

        var taskLines: [String] = []
        for (index, task) in tasks.enumerated() {
            var line = taskFormat
                .replacingOccurrences(of: "{title}", with: task.title)
                .replacingOccurrences(of: "{index}", with: "\(index + 1)")
                .replacingOccurrences(of: "{priority}", with: task.priority.rawValue)

            let cleanNotes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.contains("{notes}") {
                line = line.replacingOccurrences(of: "{notes}", with: cleanNotes)
            } else if includeNotes && !cleanNotes.isEmpty {
                line += " (\(cleanNotes))"
            }
            taskLines.append(line)
        }

        let tasksBlock = taskLines.joined(separator: "\n")

        var template = appSettings.messageTemplate
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            template = "```\n{date}\n{tasks}\n```"
        }

        let rendered = template
            .replacingOccurrences(of: "{date}", with: dateString)
            .replacingOccurrences(of: "{time}", with: timeString)
            .replacingOccurrences(of: "{tasks}", with: tasksBlock)
            .replacingOccurrences(of: "{count}", with: "\(tasks.count)")
            .replacingOccurrences(of: "{username}", with: appSettings.botUsername)

        return rendered
    }

    public func sendTasks(
        tasks: [TaskItem],
        totalActiveCount: Int,
        settings: AppSettings,
        isAutomated: Bool
    ) async throws -> DiscordPushResult {
        let validation = validateWebhookUrl(settings.discordWebhookUrl)
        guard validation.isValid else {
            throw NSError(domain: "DiscordService", code: 400, userInfo: [NSLocalizedDescriptionKey: validation.error ?? "Invalid Webhook URL"])
        }

        guard let url = URL(string: settings.discordWebhookUrl.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "DiscordService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Webhook URL"])
        }

        guard !tasks.isEmpty else {
            return DiscordPushResult(success: true, message: "No completed tasks to push.", taskCount: 0)
        }

        let messageContent = formatTasksMessage(
            tasks: tasks,
            includeNotes: settings.includeNotesInDiscord,
            settings: settings
        )

        var payload: [String: Any] = [
            "content": messageContent
        ]

        let username = sanitizedUsername(settings.botUsername)
        if !username.isEmpty {
            payload["username"] = username
        }
        if let avatar = sanitizedAvatarUrl(settings.avatarUrl) {
            payload["avatar_url"] = avatar
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DisTask/1.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DiscordService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid network response from Discord."])
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
            return DiscordPushResult(
                success: true,
                message: "Successfully pushed \(tasks.count) task\(tasks.count == 1 ? "" : "s") to Discord!",
                taskCount: tasks.count
            )
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown Discord error"
            let errorMsg = "Discord returned HTTP \(httpResponse.statusCode): \(errorBody)"
            throw NSError(domain: "DiscordService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    public func sendTestMessage(settings: AppSettings) async throws -> Bool {
        let validation = validateWebhookUrl(settings.discordWebhookUrl)
        guard validation.isValid else {
            throw NSError(domain: "DiscordService", code: 400, userInfo: [NSLocalizedDescriptionKey: validation.error ?? "Invalid Webhook URL"])
        }

        guard let url = URL(string: settings.discordWebhookUrl.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "DiscordService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Webhook URL"])
        }

        let sampleTasks = [
            TaskItem(title: "Discord connection verified", isCompleted: true),
            TaskItem(title: "Tasks will be pushed in this format", isCompleted: true)
        ]
        let testContent = formatTasksMessage(
            tasks: sampleTasks,
            includeNotes: settings.includeNotesInDiscord,
            settings: settings
        )

        var payload: [String: Any] = [
            "content": testContent
        ]

        let username = sanitizedUsername(settings.botUsername)
        if !username.isEmpty {
            payload["username"] = username
        }
        if let avatar = sanitizedAvatarUrl(settings.avatarUrl) {
            payload["avatar_url"] = avatar
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DisTask/1.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DiscordService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid network response from Discord."])
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
            return true
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown Discord error"
            throw NSError(domain: "DiscordService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Discord returned HTTP \(httpResponse.statusCode): \(errorBody)"])
        }
    }
}
