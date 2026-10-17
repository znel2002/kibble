import Foundation
import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Codable {
    case claude, codex

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    var tint: Color {
        switch self {
        case .claude: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex: Color(red: 0.06, green: 0.64, blue: 0.50)
        }
    }
}

/// One rate-limit window, e.g. Claude's rolling 5 hours or Codex's week.
struct UsageWindow: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let usedPercent: Double
    let resetsAt: Date?

    var leftPercent: Double { max(0, 100 - usedPercent) }

    /// A window whose reset time has passed is effectively empty again.
    func normalized(now: Date = .now) -> UsageWindow {
        guard let resetsAt, resetsAt < now else { return self }
        return UsageWindow(label: label, usedPercent: 0, resetsAt: nil)
    }

    static func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 300: "5-hour"
        case 10080: "Weekly"
        case 1440: "Daily"
        default: minutes % 60 == 0 ? "\(minutes / 60)-hour" : "\(minutes)-min"
        }
    }
}

struct ProviderUsage: Equatable {
    let provider: Provider
    var windows: [UsageWindow] = []
    /// When the numbers were true. Codex numbers come from the last session
    /// log, so they can be older than the fetch.
    var asOf: Date?
    var error: String?

    /// The tightest window is the one that decides how much is left.
    var tightest: UsageWindow? { windows.max { $0.usedPercent < $1.usedPercent } }
}

struct Agent: Identifiable, Equatable {
    let id: String
    let provider: Provider
    /// What the agent is working on: the session or thread title.
    let title: String
    let project: String
    let busy: Bool
    /// When the current task started (busy) or the agent last changed state.
    let since: Date
    /// Where the task runs, for jumping to it from the card.
    var origin = AgentOrigin()
    /// Blocked on the user: a permission prompt, or a question it asked.
    var waiting = false

    /// Tools fall back to ids like "cfd8eb08" or "vault-22" before a session is named.
    static func isPlaceholder(_ name: String) -> Bool {
        name.isEmpty
            || name.range(of: #"^[0-9a-f]{6,}$"#, options: .regularExpression) != nil
            || name.range(of: #"^[a-z]+-\d+$"#, options: .regularExpression) != nil
    }
}
