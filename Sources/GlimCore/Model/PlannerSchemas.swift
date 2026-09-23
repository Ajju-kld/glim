/// JSON schemas that constrain the model's answers. Ollama enforces them while generating,
/// and the planner validates the result again in code.
public enum PlannerSchemas {
    /// Tunable: the longest app name or control description the model may write. Real names
    /// are far shorter; a model stuck repeating itself stops here.
    public static let maximumNameLength = 200

    /// A question, or a task with steps. Each step is one of the per-action variants below, so
    /// the model can't leave out a field its action needs (a click without a target, a window
    /// move without a preset).
    ///
    /// The step count and typed text are bounded by `limits`, so a model stuck repeating steps
    /// stops at the action limit instead of generating until the request times out.
    ///
    /// Field order matters: Ollama makes the model write fields in schema order. `kind` comes
    /// before `steps`, and every step starts with `action`; the other way round, qwen3-vl
    /// commits to steps before choosing what they do and loops until the token cap.
    public static func plan(limits: SafetyLimits) -> JSONValue {
        let stepVariants = ActionKind.allCases.map { kind in
            stepVariant(for: kind, limits: limits)
        }
        return [
            "type": "object",
            "properties": [
                "kind": ["type": "string", "enum": ["question", "task"]],
                "steps": [
                    "type": "array",
                    "items": ["anyOf": .array(stepVariants)],
                    "maxItems": .integer(limits.maximumActionsPerTask),
                ],
            ],
            "required": ["kind", "steps"],
        ]
    }

    /// One element number, or blocked with a reason.
    public static let target: JSONValue = [
        "type": "object",
        "properties": [
            "elementNumber": ["type": "integer"],
            "blocked": ["type": "boolean"],
            "reason": ["type": "string"],
        ],
        "required": ["elementNumber", "blocked"],
    ]

    /// Tunable: the longest description of what the model sees at a point. It is shown in the
    /// confirmation panel, so it stays a few words.
    public static let maximumVisualDescriptionLength = 80

    /// A point on a window screenshot, or not found with a reason.
    ///
    /// The description comes first, so the model names what it is looking at before it commits
    /// to a point (Ollama makes the model write fields in schema order).
    public static let visualTarget: JSONValue = [
        "type": "object",
        "properties": [
            "description": [
                "type": "string", "maxLength": .integer(maximumVisualDescriptionLength),
            ],
            "found": ["type": "boolean"],
            "x": ["type": "integer", "minimum": 0, "maximum": .integer(VisualTarget.gridSize - 1)],
            "y": ["type": "integer", "minimum": 0, "maximum": .integer(VisualTarget.gridSize - 1)],
            "reason": ["type": "string", "maxLength": .integer(maximumNameLength)],
        ],
        "required": ["description", "found", "x", "y"],
    ]

    /// A short spoken answer.
    public static let answer: JSONValue = [
        "type": "object",
        "properties": ["answer": ["type": "string"]],
        "required": ["answer"],
    ]

    /// The fields each action needs besides `action` itself.
    static func requiredFields(of kind: ActionKind) -> [String] {
        switch kind {
        case .openApp, .switchApp, .quitApp, .minimizeWindow, .restoreWindow: ["app"]
        case .click: ["app", "target"]
        case .typeText: ["app", "target", "text"]
        case .pressKey: ["app", "key"]
        case .scroll: ["app", "direction"]
        case .moveWindow: ["app", "preset"]
        case .speak: ["text"]
        }
    }

    private static func stepVariant(for kind: ActionKind, limits: SafetyLimits) -> JSONValue {
        let fields = requiredFields(of: kind)
        // `action` must come first: the model writes fields in this order (see `plan`).
        var properties: JSONValue = [
            "action": ["type": "string", "enum": [.string(kind.rawValue)]]
        ]
        for field in fields {
            properties = properties.setting(field, to: fieldSchema(named: field, limits: limits))
        }
        return [
            "type": "object",
            "properties": properties,
            "required": .array((["action"] + fields).map { .string($0) }),
            "additionalProperties": false,
        ]
    }

    private static func fieldSchema(named field: String, limits: SafetyLimits) -> JSONValue {
        switch field {
        case "key":
            ["type": "string", "enum": .array(AllowedKey.allCases.map { .string($0.rawValue) })]
        case "direction":
            [
                "type": "string",
                "enum": .array(ScrollDirection.allCases.map { .string($0.rawValue) }),
            ]
        case "preset":
            ["type": "string", "enum": .array(WindowPreset.allCases.map { .string($0.rawValue) })]
        case "text":
            ["type": "string", "maxLength": .integer(limits.maximumTypedTextLength)]
        default: ["type": "string", "maxLength": .integer(maximumNameLength)]
        }
    }
}
