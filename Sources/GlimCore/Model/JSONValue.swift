import Foundation

/// A JSON value for building request bodies and schemas with Swift literals.
///
/// Objects keep the order their members were written in. Ollama generates a schema's fields in
/// that order, and the planner's answers depend on it (see `PlannerSchemas`). `JSONEncoder`
/// reorders object keys, so use ``jsonData()`` wherever the order must survive.
public enum JSONValue: Sendable, Equatable, Encodable {
    /// One key and value of an object.
    public struct Member: Sendable, Equatable {
        /// The member's name.
        public let key: String
        /// The member's value.
        public let value: JSONValue

        /// Creates a member.
        public init(key: String, value: JSONValue) {
            self.key = key
            self.value = value
        }
    }

    private struct MemberKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    case string(String)
    case integer(Int)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([Member])
    case null

    /// The value as JSON text with every object's members in order. Scalars are written by
    /// `JSONEncoder`, so strings are escaped exactly as it escapes them.
    public func jsonData() throws -> Data {
        let scalarEncoder = JSONEncoder()
        var output = Data()
        try write(into: &output, scalarEncoder: scalarEncoder)
        return output
    }

    private func write(into output: inout Data, scalarEncoder: JSONEncoder) throws {
        switch self {
        case .array(let elements):
            output.append(contentsOf: "[".utf8)
            for (index, element) in elements.enumerated() {
                if index > 0 {
                    output.append(contentsOf: ",".utf8)
                }
                try element.write(into: &output, scalarEncoder: scalarEncoder)
            }
            output.append(contentsOf: "]".utf8)
        case .object(let members):
            output.append(contentsOf: "{".utf8)
            for (index, member) in members.enumerated() {
                if index > 0 {
                    output.append(contentsOf: ",".utf8)
                }
                output.append(try scalarEncoder.encode(member.key))
                output.append(contentsOf: ":".utf8)
                try member.value.write(into: &output, scalarEncoder: scalarEncoder)
            }
            output.append(contentsOf: "}".utf8)
        case .string, .integer, .number, .bool, .null:
            output.append(try scalarEncoder.encode(self))
        }
    }

    /// Encodes the value as plain JSON. `JSONEncoder` may reorder object keys; use
    /// ``jsonData()`` when their order matters.
    public func encode(to encoder: any Encoder) throws {
        if case .object(let members) = self {
            var container = encoder.container(keyedBy: MemberKey.self)
            for member in members {
                try container.encode(member.value, forKey: MemberKey(stringValue: member.key))
            }
            return
        }
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let text): try container.encode(text)
        case .integer(let integer): try container.encode(integer)
        case .number(let number): try container.encode(number)
        case .bool(let flag): try container.encode(flag)
        case .array(let elements): try container.encode(elements)
        case .object: break
        case .null: try container.encodeNil()
        }
    }

    /// This object with `key` set to `value`: an existing key keeps its place, a new key goes
    /// last. Any other value is returned unchanged.
    public func setting(_ key: String, to value: JSONValue) -> JSONValue {
        guard case .object(var members) = self else {
            return self
        }
        if let existingIndex = members.firstIndex(where: { $0.key == key }) {
            members[existingIndex] = Member(key: key, value: value)
        } else {
            members.append(Member(key: key, value: value))
        }
        return .object(members)
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
    /// Creates a JSON object with the members in the order written.
    public init(dictionaryLiteral members: (String, JSONValue)...) {
        self = members.reduce(.object([])) { object, member in
            object.setting(member.0, to: member.1)
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    /// Creates JSON null.
    public init(nilLiteral: ()) {
        self = .null
    }
}
