import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case discord = "Discord"
    case format = "Format"
    case schedule = "Schedule"
    case general = "General"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .discord: return "paperplane.fill"
        case .format: return "curlybraces"
        case .schedule: return "alarm.fill"
        case .general: return "slider.horizontal.3"
        }
    }
}

public struct SettingsSheetView: View {
    @ObservedObject var taskStore: TaskStore

    @State private var selectedTab: SettingsTab = .discord

    // Settings fields
    @State private var webhookUrl: String = ""
    @State private var botUsername: String = "DisTask Bot"
    @State private var avatarUrl: String = ""
    @State private var scheduledHour: Int = 17
    @State private var scheduledMinute: Int = 0
    @State private var isScheduleEnabled: Bool = true
    @State private var scheduleDays: ScheduleFrequency = .everyday
    @State private var includeNotes: Bool = true
    @State private var clearAfterPush: Bool = false
    @State private var notifyOnPush: Bool = true
    @State private var showBadgeInMenuBar: Bool = true

    // Format customization fields
    @State private var messageTemplate: String = "```\n{date}\n{tasks}\n```"
    @State private var taskLineFormat: String = "- {title}"
    @State private var dateFormat: String = "MMM d"
    @State private var selectedPreset: MessageFormatPreset = .codeBlock

    // Testing state
    @State private var isTesting: Bool = false
    @State private var testResult: (success: Bool, message: String)? = nil

    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Tab Selector Bar
            tabSelectorBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            // Tab Content
            ScrollView {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .discord:
                        discordTabContent
                    case .format:
                        formatTabContent
                    case .schedule:
                        scheduleTabContent
                    case .general:
                        generalTabContent
                    }
                }
                .padding(14)
            }
        }
        .onAppear {
            loadFromSettings()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                    .font(.system(size: 13))
                Text("DisTask Settings")
                    .font(.system(size: 13, weight: .bold))
            }

            Spacer()

            Button {
                saveAndClose()
            } label: {
                Text("Done")
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.35, green: 0.40, blue: 0.95))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Tab Selector Bar

    private var tabSelectorBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.28, green: 0.32, blue: 0.88)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.3), radius: 2, y: 1)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Card Helper

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color = Color(red: 0.35, green: 0.40, blue: 0.95),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }

            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab 1: Discord

    private var discordTabContent: some View {
        VStack(spacing: 12) {
            // Webhook URL Card
            settingsCard(title: "Webhook Connection", icon: "link", iconColor: Color(red: 0.35, green: 0.40, blue: 0.95)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Webhook URL")
                            .font(.system(size: 11, weight: .medium))

                        Spacer()

                        let validation = DiscordService.shared.validateWebhookUrl(webhookUrl)
                        if webhookUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            badge(text: "Not Configured", color: .secondary)
                        } else if validation.isValid {
                            badge(text: "Ready", color: .green)
                        } else {
                            badge(text: "Invalid URL", color: .red)
                        }
                    }

                    HStack(spacing: 6) {
                        TextField("https://discord.com/api/webhooks/...", text: $webhookUrl)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onChange(of: webhookUrl) { _ in saveCurrentValues() }

                        Button("Paste") {
                            if let clipboard = NSPasteboard.general.string(forType: .string) {
                                webhookUrl = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                                saveCurrentValues()
                            }
                        }
                        .font(.system(size: 10.5))
                    }

                    Text("💡 Create a webhook in Discord: Channel Settings > Integrations > Webhooks.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }

            // Bot Customization Card
            settingsCard(title: "Bot Appearance", icon: "person.crop.circle.badge.checkmark", iconColor: .purple) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Display Name:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 85, alignment: .leading)
                        TextField("DisTask Bot", text: $botUsername)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onChange(of: botUsername) { _ in saveCurrentValues() }
                    }

                    HStack(spacing: 8) {
                        Text("Avatar URL:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 85, alignment: .leading)
                        TextField("https://... (Optional)", text: $avatarUrl)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onChange(of: avatarUrl) { _ in saveCurrentValues() }
                    }
                }
            }

            // Connection Testing Card
            settingsCard(title: "Connection Verification", icon: "network", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            runTest()
                        } label: {
                            HStack(spacing: 5) {
                                if isTesting {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "paperplane.circle.fill")
                                }
                                Text(isTesting ? "Testing..." : "Send Test Webhook")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .disabled(isTesting)

                        Spacer()
                    }

                    if let result = testResult {
                        HStack(spacing: 6) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                                .font(.system(size: 11))

                            Text(result.message)
                                .font(.system(size: 10.5))
                                .foregroundColor(result.success ? .green : .red)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((result.success ? Color.green : Color.red).opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }

            // Shortcut to Format Tab
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pushed Message Format")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Customize code blocks, headers, bullets & timestamps.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedTab = .format
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Customize Format")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            .cornerRadius(8)
        }
    }

    // MARK: - Tab 2: Format & Code Block Customization

    private var formatTabContent: some View {
        VStack(spacing: 12) {
            // Presets Card
            settingsCard(title: "Format Presets", icon: "sparkles", iconColor: .purple) {
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(MessageFormatPreset.allCases) { preset in
                                let isSelected = selectedPreset == preset
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Text(preset.rawValue)
                                        .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(
                                            isSelected ?
                                                Color(red: 0.35, green: 0.40, blue: 0.95) :
                                                Color.primary.opacity(0.07)
                                        )
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Choose a pre-configured template or freely customize below.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }

            // Template Editor Card
            settingsCard(title: "Message & Code Block Template", icon: "curlybraces", iconColor: Color(red: 0.35, green: 0.40, blue: 0.95)) {
                VStack(alignment: .leading, spacing: 8) {
                    // Quick placeholder chips
                    HStack(spacing: 5) {
                        Text("Insert:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        placeholderChip(tag: "{date}", label: "Date")
                        placeholderChip(tag: "{tasks}", label: "Tasks")
                        placeholderChip(tag: "{time}", label: "Time")
                        placeholderChip(tag: "{count}", label: "Count")
                    }

                    // Multi-line editor
                    TextEditor(text: $messageTemplate)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 75)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .onChange(of: messageTemplate) { _ in
                            checkAndUpdatePreset()
                            saveCurrentValues()
                        }

                    Text("Enclose in ``` for Discord code block. {tasks} will be replaced with your list.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }

            // Line Format & Date Options
            settingsCard(title: "Task Line & Date Settings", icon: "text.alignleft", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 10) {
                    // Task item line format
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Task Line Format:")
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            HStack(spacing: 4) {
                                lineFormatChip("- {title}", label: "- Title")
                                lineFormatChip("• {title}", label: "• Title")
                                lineFormatChip("- [x] {title}", label: "[x] Title")
                            }
                        }

                        TextField("- {title}", text: $taskLineFormat)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .onChange(of: taskLineFormat) { _ in
                                checkAndUpdatePreset()
                                saveCurrentValues()
                            }

                        Text("Tags: {title}, {notes}, {priority}, {index}")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Date format pattern
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Date Format Pattern:")
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            HStack(spacing: 4) {
                                dateFormatChip("MMM d", label: "Oct 7")
                                dateFormatChip("yyyy-MM-dd", label: "2026-10-07")
                                dateFormatChip("EEEE, MMM d", label: "Full")
                            }
                        }

                        TextField("MMM d", text: $dateFormat)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .onChange(of: dateFormat) { _ in saveCurrentValues() }
                    }
                }
            }

            // Live Output Preview
            settingsCard(title: "Live Discord Output Preview", icon: "eye.fill", iconColor: .green) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        badge(text: "Live Preview", color: .green)
                        Spacer()
                        Button("Reset to Default") {
                            resetToDefaultFormat()
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                    }

                    Text(renderedPreview)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Tab 3: Schedule

    private var scheduleTabContent: some View {
        VStack(spacing: 12) {
            // Master Schedule Toggle
            settingsCard(title: "Automated Daily Push", icon: "alarm.fill", iconColor: .orange) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Enable Scheduled Auto-Push", isOn: $isScheduleEnabled)
                        .font(.system(size: 12, weight: .semibold))
                        .onChange(of: isScheduleEnabled) { _ in saveCurrentValues() }

                    Text("When enabled, DisTask pushes your completed tasks automatically at the given time.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }

            if isScheduleEnabled {
                // Time Selection
                settingsCard(title: "Target Delivery Time", icon: "clock.fill", iconColor: .blue) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text("Time:")
                                .font(.system(size: 11, weight: .medium))

                            HStack(spacing: 6) {
                                Picker("Hour", selection: $scheduledHour) {
                                    ForEach(0..<24) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .frame(width: 65)

                                Text(":")
                                    .font(.system(size: 13, weight: .bold))

                                Picker("Minute", selection: $scheduledMinute) {
                                    ForEach(0..<60) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .frame(width: 65)
                            }
                            .onChange(of: scheduledHour) { _ in saveCurrentValues() }
                            .onChange(of: scheduledMinute) { _ in saveCurrentValues() }

                            Spacer()

                            Text(formattedTime(hour: scheduledHour, minute: scheduledMinute))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.12))
                                .cornerRadius(5)
                        }
                    }
                }

                // Days Frequency
                settingsCard(title: "Schedule Frequency", icon: "calendar", iconColor: .green) {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $scheduleDays) {
                            ForEach(ScheduleFrequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: scheduleDays) { _ in saveCurrentValues() }

                        Text(scheduleDays == .weekdaysOnly ? "Skipping Saturday and Sunday." : "Triggers every day of the week.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                // Live Status Banner
                settingsCard(title: "Next Scheduled Push", icon: "calendar.badge.clock", iconColor: .green) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)

                        Text(taskStore.scheduleManager.nextPushDescription)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(6)

                    Text("⚠️ Only queued completed tasks will be sent. If the queue is empty at push time, no message is sent.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Tab 4: General & Maintenance

    private var generalTabContent: some View {
        VStack(spacing: 12) {
            // Task Delivery Behavior
            settingsCard(title: "Task Delivery Behavior", icon: "paperplane", iconColor: Color(red: 0.35, green: 0.40, blue: 0.95)) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle("Include notes in Discord message", isOn: $includeNotes)
                            .font(.system(size: 11.5, weight: .medium))
                            .onChange(of: includeNotes) { _ in saveCurrentValues() }
                        Text("Appends optional notes directly below task titles.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 3) {
                        Toggle("Auto-delete tasks after pushing", isOn: $clearAfterPush)
                            .font(.system(size: 11.5, weight: .medium))
                            .onChange(of: clearAfterPush) { _ in saveCurrentValues() }
                        Text("When disabled, tasks move to the Pushed archive instead of deleting.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Menu Bar & Alerts
            settingsCard(title: "Menu Bar & Alerts", icon: "bell.badge.fill", iconColor: .orange) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle("Show pending queue badge in Menu Bar", isOn: $showBadgeInMenuBar)
                            .font(.system(size: 11.5, weight: .medium))
                            .onChange(of: showBadgeInMenuBar) { _ in saveCurrentValues() }
                        Text("Shows the count of checked tasks waiting to be pushed (e.g. [3]).")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 3) {
                        Toggle("Send macOS push notification", isOn: $notifyOnPush)
                            .font(.system(size: 11.5, weight: .medium))
                            .onChange(of: notifyOnPush) { _ in saveCurrentValues() }
                        Text("Displays a system notification banner whenever tasks are pushed.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Queue & Archive Actions
            settingsCard(title: "Queue & Archive Actions", icon: "arrow.triangle.2.circlepath", iconColor: .indigo) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation {
                                taskStore.clearPushQueue()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Clear Push Queue")
                            }
                            .font(.system(size: 11))
                        }

                        Button {
                            withAnimation {
                                taskStore.clearAlreadyPushed()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Clear Pushed Archive")
                            }
                            .font(.system(size: 11))
                        }
                    }

                    Text("Reset your push queue or clean up older archived tasks from the database.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Local Storage
            settingsCard(title: "Local Database Storage", icon: "internaldrive.fill", iconColor: .teal) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Application Support Folder")
                                .font(.system(size: 11, weight: .medium))
                            Text(taskStore.storageDirectoryPath)
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button("Reveal in Finder") {
                            taskStore.openStorageInFinder()
                        }
                        .font(.system(size: 10.5))
                    }

                    HStack(spacing: 16) {
                        Label("tasks.json", systemImage: "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Label("settings.json", systemImage: "gearshape")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // About DisTask
            settingsCard(title: "About DisTask", icon: "info.circle.fill", iconColor: .secondary) {
                HStack(spacing: 10) {
                    ZStack {
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.40, blue: 0.95), Color(red: 0.20, green: 0.25, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "checklist")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DisTask for macOS")
                            .font(.system(size: 11.5, weight: .bold))
                        Text("Version 1.0.0 (Native Menu Bar)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers & Format Chips

    private func placeholderChip(tag: String, label: String) -> some View {
        Button {
            messageTemplate += (messageTemplate.hasSuffix("\n") ? "" : "\n") + tag
            saveCurrentValues()
        } label: {
            Text("+\(label)")
                .font(.system(size: 9.5, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .foregroundColor(.primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func lineFormatChip(_ format: String, label: String) -> some View {
        Button {
            taskLineFormat = format
            saveCurrentValues()
        } label: {
            Text(label)
                .font(.system(size: 9.5))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(taskLineFormat == format ? Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.15) : Color.primary.opacity(0.06))
                .foregroundColor(taskLineFormat == format ? Color(red: 0.35, green: 0.40, blue: 0.95) : .secondary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func dateFormatChip(_ pattern: String, label: String) -> some View {
        Button {
            dateFormat = pattern
            saveCurrentValues()
        } label: {
            Text(label)
                .font(.system(size: 9.5))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(dateFormat == pattern ? Color.blue.opacity(0.15) : Color.primary.opacity(0.06))
                .foregroundColor(dateFormat == pattern ? .blue : .secondary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var renderedPreview: String {
        let sampleTasks = [
            TaskItem(title: "New designed category", isCompleted: true, priority: .high),
            TaskItem(title: "LR fixes", isCompleted: true, priority: .medium),
            TaskItem(title: "Meeting with team", notes: "Discuss roadmap", isCompleted: true, priority: .low)
        ]
        let previewSettings = AppSettings(
            discordWebhookUrl: webhookUrl,
            botUsername: botUsername,
            avatarUrl: avatarUrl,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            isScheduleEnabled: isScheduleEnabled,
            scheduleDays: scheduleDays,
            includeNotesInDiscord: includeNotes,
            clearTasksAfterPush: clearAfterPush,
            notifyOnPush: notifyOnPush,
            showCompletedCountInMenuBar: showBadgeInMenuBar,
            messageTemplate: messageTemplate,
            taskLineFormat: taskLineFormat,
            dateFormat: dateFormat
        )
        return DiscordService.shared.formatTasksMessage(
            tasks: sampleTasks,
            includeNotes: includeNotes,
            settings: previewSettings
        )
    }

    private func applyPreset(_ preset: MessageFormatPreset) {
        selectedPreset = preset
        if preset != .custom {
            messageTemplate = preset.template
            taskLineFormat = preset.defaultTaskFormat
        }
        saveCurrentValues()
    }

    private func checkAndUpdatePreset() {
        for preset in MessageFormatPreset.allCases where preset != .custom {
            if messageTemplate == preset.template && taskLineFormat == preset.defaultTaskFormat {
                selectedPreset = preset
                return
            }
        }
        selectedPreset = .custom
    }

    private func resetToDefaultFormat() {
        applyPreset(.codeBlock)
        dateFormat = "MMM d"
        saveCurrentValues()
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func loadFromSettings() {
        let s = taskStore.settings
        webhookUrl = s.discordWebhookUrl
        botUsername = s.botUsername
        avatarUrl = s.avatarUrl
        scheduledHour = s.scheduledHour
        scheduledMinute = s.scheduledMinute
        isScheduleEnabled = s.isScheduleEnabled
        scheduleDays = s.scheduleDays
        includeNotes = s.includeNotesInDiscord
        clearAfterPush = s.clearTasksAfterPush
        notifyOnPush = s.notifyOnPush
        showBadgeInMenuBar = s.showCompletedCountInMenuBar
        messageTemplate = s.messageTemplate
        taskLineFormat = s.taskLineFormat
        dateFormat = s.dateFormat

        checkAndUpdatePreset()
    }

    private func saveCurrentValues() {
        taskStore.settings.discordWebhookUrl = webhookUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        taskStore.settings.botUsername = botUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        taskStore.settings.avatarUrl = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        taskStore.settings.scheduledHour = scheduledHour
        taskStore.settings.scheduledMinute = scheduledMinute
        taskStore.settings.isScheduleEnabled = isScheduleEnabled
        taskStore.settings.scheduleDays = scheduleDays
        taskStore.settings.includeNotesInDiscord = includeNotes
        taskStore.settings.clearTasksAfterPush = clearAfterPush
        taskStore.settings.notifyOnPush = notifyOnPush
        taskStore.settings.showCompletedCountInMenuBar = showBadgeInMenuBar
        taskStore.settings.messageTemplate = messageTemplate
        taskStore.settings.taskLineFormat = taskLineFormat
        taskStore.settings.dateFormat = dateFormat
    }

    private func saveAndClose() {
        saveCurrentValues()
        withAnimation(.easeInOut(duration: 0.2)) {
            taskStore.isSettingsOpen = false
        }
    }

    private func runTest() {
        saveCurrentValues()
        isTesting = true
        testResult = nil

        Task {
            let result = await taskStore.testConnection()
            await MainActor.run {
                self.isTesting = false
                self.testResult = result
            }
        }
    }
}
