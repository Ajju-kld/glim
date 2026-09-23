/// JSON schemas that constrain the model's answers. Ollama enforces them while generating,
/// and the planner validates the result again in code.
public enum PlannerSchemas {
    /// A question, or a task with steps.
    public static let plan: JSONValue = [
        "type": "object",
        "properties": [
            "kind": ["type": "string", "enum": ["question", "task"]],
            "steps": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": .array(ActionKind.allCases.map { .string($0.rawValue) }),
                        ],
                        "app": ["type": "string"],
                        "target": ["type": "string"],
                        "text": ["type": "string"],
                        "key": [
                            "type": "string",
                            "enum": .array(AllowedKey.allCases.map { .string($0.rawValue) }),
                        ],
                        "direction": [
                            "type": "string",
                            "enum": .array(ScrollDirection.allCases.map { .string($0.rawValue) }),
                        ],
                        "preset": [
                            "type": "string",
                            "enum": .array(WindowPreset.allCases.map { .string($0.rawValue) }),
                        ],
                    ],
                    "required": ["action"],
                ],
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
}
