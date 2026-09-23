import Foundation
import Testing

@testable import GlimCore

struct JSONValueTests {
    func encodedText(_ value: JSONValue) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test func literalsEncodeAsJSON() throws {
        let schema: JSONValue = [
            "type": "object",
            "required": ["kind"],
            "properties": ["count": ["type": "integer", "minimum": 1]],
            "strict": true,
            "nothing": nil,
        ]

        #expect(
            try encodedText(schema)
                == #"{"nothing":null,"properties":{"count":{"minimum":1,"type":"integer"}},"required":["kind"],"strict":true,"type":"object"}"#
        )
    }
}
