import Foundation

/// Talks to the local Ollama server at `127.0.0.1:11434`.
public struct OllamaClient: LanguageModel {
    /// Tunable: the first request loads the model into memory, which can take a while.
    public static let requestTimeoutSeconds: TimeInterval = 60
    /// Tunable: temperature 0 makes plans repeatable for the same request and screen.
    public static let planningTemperature = 0.0
    /// Tunable: the longest answer the model may write — a 20-step plan fits well inside it,
    /// and a runaway generation stops instead of hanging the task.
    public static let maximumAnswerTokens = 1_024
    private static let notFoundStatusCode = 404
    private static let successStatusCodes = 200..<300

    private struct ChatRequest: Encodable {
        let model: String
        let stream: Bool
        let think: Bool
        let format: JSONValue
        let messages: [ChatMessage]
        let options: ChatOptions
    }

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
        let images: [String]?
    }

    private struct ChatOptions: Encodable {
        enum CodingKeys: String, CodingKey {
            case temperature
            case maximumAnswerTokens = "num_predict"
        }

        let temperature: Double
        let maximumAnswerTokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Message: Decodable {
            let content: String
            let thinking: String?
        }
        let message: Message
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }

    private struct TagsResponse: Decodable {
        struct Model: Decodable {
            let name: String
        }
        let models: [Model]
    }

    private let transport: any HTTPTransport
    private let modelName: String

    /// Creates a client that uses `modelName` through `transport`.
    public init(transport: any HTTPTransport, modelName: String) {
        self.transport = transport
        self.modelName = modelName
    }

    /// Sends a chat request constrained to the request's JSON schema and returns the answer.
    public func respond(to request: LanguageModelRequest) async throws(LanguageModelError) -> String
    {
        let userImages = request.imagesPNG.map { $0.base64EncodedString() }
        let chatRequest = ChatRequest(
            model: modelName,
            stream: false,
            think: false,
            format: request.responseSchema,
            messages: [
                ChatMessage(role: "system", content: request.systemPrompt, images: nil),
                ChatMessage(
                    role: "user", content: request.userPrompt,
                    images: userImages.isEmpty ? nil : userImages),
            ],
            options: ChatOptions(
                temperature: Self.planningTemperature, maximumAnswerTokens: Self.maximumAnswerTokens
            ))
        let body: Data
        do {
            body = try JSONEncoder().encode(chatRequest)
        } catch {
            throw .malformedResponse(
                reason: "Could not encode the request: \(error.localizedDescription)")
        }
        let data = try await send(path: "/api/chat", method: "POST", body: body)
        return try Self.answer(in: decode(ChatResponse.self, from: data).message)
    }

    /// The answer text. Thinking models such as `qwen3-vl` can put their schema-constrained
    /// answer in `thinking` and leave `content` empty, even with `think: false`; either field is
    /// accepted, and the planner validates the JSON strictly afterwards.
    private static func answer(in message: ChatResponse.Message) throws(LanguageModelError)
        -> String
    {
        let answer = message.content.isEmpty ? (message.thinking ?? "") : message.content
        guard answer.contains(where: { !$0.isWhitespace }) else {
            throw .malformedResponse(reason: "The model returned an empty answer.")
        }
        return answer
    }

    /// Names of the models Ollama has installed, for the setup check.
    public func installedModelNames() async throws(LanguageModelError) -> [String] {
        let data = try await send(path: "/api/tags", method: "GET", body: nil)
        return try decode(TagsResponse.self, from: data).models.map(\.name)
    }

    private func send(path: String, method: String, body: Data?) async throws(LanguageModelError)
        -> Data
    {
        guard PlannerModelPolicy.isLocalModelName(modelName) else {
            throw .modelNotAllowed(modelName: modelName)
        }
        let url: URL
        do {
            url = try NetworkEndpoint.ollama.url(path: path)
        } catch {
            throw .blockedByNetworkPolicy(error)
        }
        var urlRequest = URLRequest(url: url, timeoutInterval: Self.requestTimeoutSeconds)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(urlRequest)
        } catch let urlError as URLError {
            throw urlError.code == .timedOut
                ? .timedOut : .serverUnreachable(reason: urlError.localizedDescription)
        } catch let policyError as NetworkPolicyError {
            throw .blockedByNetworkPolicy(policyError)
        } catch {
            throw .serverUnreachable(reason: error.localizedDescription)
        }
        guard Self.successStatusCodes.contains(response.statusCode) else {
            if response.statusCode == Self.notFoundStatusCode {
                throw .modelNotInstalled(modelName: modelName)
            }
            throw .badResponse(
                statusCode: response.statusCode, message: Self.errorMessage(from: data))
        }
        return data
    }

    /// Ollama's `{"error": …}` text, or the raw body when it isn't in that shape.
    private static func errorMessage(from data: Data) -> String {
        do {
            return try JSONDecoder().decode(ErrorResponse.self, from: data).error
        } catch {
            return String(decoding: data, as: UTF8.self)
        }
    }

    private func decode<Decoded: Decodable>(
        _ type: Decoded.Type, from data: Data
    ) throws(LanguageModelError) -> Decoded {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .malformedResponse(reason: error.localizedDescription)
        }
    }
}
