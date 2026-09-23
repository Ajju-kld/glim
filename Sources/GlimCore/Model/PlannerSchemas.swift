/// JSON schemas that constrain the model's answers. Ollama enforces them while generating,
/// and the planner validates the result again in code.
public enum PlannerSchemas {
    /// A question, or a task with steps. Each step is one of the per-action variants below, so
    /// the model can't leave out a field its action needs (a click without a target, a window
    /// move without a preset).
    public static let plan: JSONValue = [
        "type": "object",
        "properties": [
            "kind": ["type": "string", "enum": ["question", "task"]],
            "steps": [
                "type": "array", "items": ["anyOf": .array(ActionKind.allCases.map(stepVariant))],
            ],
        ],
        "required": ["kind", "steps"],
    ]

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

    private static func stepVariant(for kind: ActionKind) -> JSONValue {
        let fields = requiredFields(of: kind)
        var properties: [String: JSONValue] = [
            "action": ["type": "string", "enum": [.string(kind.rawValue)]]
        ]
        for field in fields {
            properties[field] = fieldSchema(named: field)
        }
        return [
            "type": "object",
            "properties": .object(properties),
            "required": .array((["action"] + fields).map { .string($0) }),
            "additionalProperties": false,
        ]
    }

    private static func fieldSchema(named field: String) -> JSONValue {
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
        default: ["type": "string"]
        }
    }
}
