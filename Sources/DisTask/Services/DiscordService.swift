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

    public func formatTasksMessage(tasks: [TaskItem], includeNotes: Bool = false) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let header = dateFormatter.string(from: Date())

        var lines: [String] = ["```", header]
        for task in tasks {
            var line = "- \(task.title)"
            if includeNotes && !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                line += " (\(task.notes.trimmingCharacters(in: .whitespacesAndNewlines)))"
            }
            lines.append(line)
        }
        lines.append("```")
        return lines.joined(separator: "\n")
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

        let messageContent = formatTasksMessage(tasks: tasks, includeNotes: settings.includeNotesInDiscord)

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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let header = dateFormatter.string(from: Date())

        let testContent = """
```
\(header)
- Test task 1: Discord connection verified
- Test task 2: Checked tasks will be sent in this format
```
"""

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
