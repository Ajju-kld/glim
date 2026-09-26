/// One exchange in screen chat: what the person said, and Glim's spoken answer if it was a
/// question.
public struct ScreenChatTurn: Sendable, Equatable {
    /// The person's words, as transcribed.
    public let request: String
    /// Glim's answer, built from the screen; nil for a task.
    public let reply: String?

    /// Creates a turn.
    public init(request: String, reply: String?) {
        self.request = request
        self.reply = reply
    }
}

/// The earlier turns of a screen chat, handed to one run.
public struct ScreenChatConversation: Sendable, Equatable {
    /// The turns so far, oldest first.
    public let earlierTurns: [ScreenChatTurn]

    /// Creates a conversation.
    public init(earlierTurns: [ScreenChatTurn]) {
        self.earlierTurns = earlierTurns
    }

    /// What the planner may see: the person's own earlier words, never Glim's answers, which
    /// are built from screen content (B-Q8).
    public var earlierRequests: [String] {
        earlierTurns.map(\.request)
    }
}

/// Screen chat ("screen bleed"): while it is on, the screen edge glows, questions see the whole
/// screen, and follow-ups remember the conversation. It ends when the person turns it off or
/// after a quiet spell.
public struct ScreenChatSession: Sendable {
    /// Tunable: quiet time after which screen chat turns itself off.
    public static let quietTimeout = Duration.seconds(60)
    /// Tunable: earlier turns kept for the model; older ones fall away so prompts stay short.
    public static let maximumRememberedTurns = 6

    /// Whether screen chat is on.
    public private(set) var isActive = false
    private var turns: [ScreenChatTurn] = []
    private var lastActivity: ContinuousClock.Instant?

    /// Creates a session that is off.
    public init() {}

    /// The conversation so far, or nil when screen chat is off.
    public var conversation: ScreenChatConversation? {
        isActive ? ScreenChatConversation(earlierTurns: turns) : nil
    }

    /// Turns screen chat on with an empty conversation.
    public mutating func start(at instant: ContinuousClock.Instant) {
        isActive = true
        turns = []
        lastActivity = instant
    }

    /// Turns screen chat off and forgets the conversation.
    public mutating func end() {
        isActive = false
        turns = []
        lastActivity = nil
    }

    /// Records that the person spoke or Glim worked, which postpones the quiet timeout.
    public mutating func noteActivity(at instant: ContinuousClock.Instant) {
        guard isActive else {
            return
        }
        lastActivity = instant
    }

    /// Remembers `turn`, keeping only the latest ones.
    public mutating func record(_ turn: ScreenChatTurn, at instant: ContinuousClock.Instant) {
        guard isActive else {
            return
        }
        turns.append(turn)
        turns = Array(turns.suffix(Self.maximumRememberedTurns))
        lastActivity = instant
    }

    /// Whether screen chat has been quiet long enough to turn itself off.
    public func hasGoneQuiet(at instant: ContinuousClock.Instant) -> Bool {
        guard isActive, let lastActivity else {
            return false
        }
        return instant - lastActivity >= Self.quietTimeout
    }
}
