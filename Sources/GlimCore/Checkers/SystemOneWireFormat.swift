/// The System-One request and response shapes shared by Jev and the local Laya service
/// (`POST /v1/systemone`).
enum SystemOneWireFormat {
    struct Request: Encodable {
        let state: JSONValue
        let model: String?
        let questions: [String: Question]
    }

    struct Question: Encodable {
        let type: String
        let instructions: String
        let criteria: [String: String]
    }

    struct Response: Decodable {
        let answers: [String: Answer]
    }

    struct Answer: Decodable {
        let choice: String?
        let probabilities: [String: Double]?
        let confidence: Double?
    }

    static let choiceQuestionType = "choice"
    static let targetQuestionIdentifier = "target"
}
