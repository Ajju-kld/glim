/// A JSON value for building request bodies and schemas with Swift literals.
public enum JSONValue: Sendable, Equatable, Encodable {
    case string(String)
    case integer(Int)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    /// Encodes the value as plain JSON.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let text): try container.encode(text)
        case .integer(let integer): try container.encode(integer)
        case .number(let number): try container.encode(number)
        case .bool(let flag): try container.encode(flag)
        case .array(let elements): try container.encode(elements)
        case .object(let members): try container.encode(members)
        case .null: try container.encodeNil()
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    /// Creates a JSON string.
    public init(stringLiteral text: String) {
        self = .string(text)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    /// Creates a JSON integer.
    public init(integerLiteral integer: Int) {
        self = .integer(integer)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    /// Creates a JSON number.
    public init(floatLiteral number: Double) {
        self = .number(number)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    /// Creates a JSON boolean.
    public init(booleanLiteral flag: Bool) {
        self = .bool(flag)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    /// Creates a JSON array.
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    /// Creates a JSON object.
    public init(dictionaryLiteral members: (String, JSONValue)...) {
        self = .object(Dictionary(members) { _, latest in latest })
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    /// Creates JSON null.
    public init(nilLiteral: ()) {
        self = .null
    }
}
