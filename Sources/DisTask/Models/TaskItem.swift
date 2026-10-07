import Foundation
import SwiftUI

public enum Priority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    public var iconName: String {
        switch self {
        case .low:
            return "arrow.down"
        case .medium:
            return "minus"
        case .high:
            return "exclamationmark"
        }
    }
}

public struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var isPushed: Bool
    public var pushedAt: Date?
    public var createdAt: Date
    public var priority: Priority

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isPushed: Bool = false,
        pushedAt: Date? = nil,
        createdAt: Date = Date(),
        priority: Priority = .medium
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isPushed = isPushed
        self.pushedAt = pushedAt
        self.createdAt = createdAt
        self.priority = priority
    }
}
