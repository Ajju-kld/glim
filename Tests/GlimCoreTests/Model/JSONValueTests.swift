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

    /// Ollama generates fields in the order a schema lists them, so the order must survive.
    @Test func objectsKeepTheOrderTheyWereWrittenIn() throws {
        let schema: JSONValue = ["type": "object", "zebra": 1, "apple": ["second": 2, "first": 1]]

        let text = String(decoding: try schema.jsonData(), as: UTF8.self)

        #expect(text == #"{"type":"object","zebra":1,"apple":{"second":2,"first":1}}"#)
    }

    @Test func repeatedKeyKeepsItsFirstPlaceAndLastValue() throws {
        let object = JSONValue.object([
            JSONValue.Member(key: "a", value: 1), JSONValue.Member(key: "b", value: 2),
        ]).setting("a", to: 3)

        let text = String(decoding: try object.jsonData(), as: UTF8.self)

        #expect(text == #"{"a":3,"b":2}"#)
    }

    @Test func orderedTextEscapesStringsAndWritesEveryScalar() throws {
        let value: JSONValue = [
            "quote \"here\"": "line\nbreak", "list": [1, 2.5, true, nil], "empty": [:],
        ]

        let text = String(decoding: try value.jsonData(), as: UTF8.self)

        #expect(
            text == #"{"quote \"here\"":"line\nbreak","list":[1,2.5,true,null],"empty":{}}"#)
    }
}
