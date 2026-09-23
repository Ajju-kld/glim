import Foundation
import Testing

@testable import GlimCore

struct OllamaClientTests {
    let request = LanguageModelRequest(
        systemPrompt: "You plan.",
        userPrompt: "open notes",
        responseSchema: ["type": "object"],
        imagesPNG: [Data([0x89, 0x50])])

    func makeClient(replies: [FakeHTTPTransport.Reply]) -> (OllamaClient, FakeHTTPTransport) {
        let fakeTransport = FakeHTTPTransport(replies: replies)
        return (OllamaClient(transport: fakeTransport, modelName: "qwen3-vl:8b"), fakeTransport)
    }

    @Test func sendsADeterministicNonStreamingChatRequest() async throws {
        let (client, fakeTransport) = makeClient(replies: [
            .response(
                statusCode: 200,
                body: #"{"message":{"role":"assistant","content":"{}"},"done":true}"#)
        ])

        _ = try await client.respond(to: request)

        let sentRequest = try #require(fakeTransport.sentRequests.first)
        #expect(sentRequest.url?.absoluteString == "http://127.0.0.1:11434/api/chat")
        #expect(sentRequest.httpMethod == "POST")
        #expect(sentRequest.timeoutInterval == OllamaClient.requestTimeoutSeconds)
        let body = try jsonObject(of: sentRequest)
        #expect(body["model"] as? String == "qwen3-vl:8b")
        #expect(body["stream"] as? Bool == false)
        #expect(body["think"] as? Bool == false)
        #expect((body["format"] as? [String: Any])?["type"] as? String == "object")
        #expect((body["options"] as? [String: Any])?["temperature"] as? Double == 0)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["system", "user"])
        #expect(messages.last?["content"] as? String == "open notes")
        #expect(
            messages.last?["images"] as? [String] == [Data([0x89, 0x50]).base64EncodedString()])
        #expect(messages.first?["images"] == nil)
    }

    @Test func returnsTheAssistantContent() async throws {
        let (client, _) = makeClient(replies: [
            .response(
                statusCode: 200,
                body:
                    #"{"message":{"role":"assistant","content":"{\"kind\":\"task\"}"},"done":true}"#
            )
        ])

        #expect(try await client.respond(to: request) == #"{"kind":"task"}"#)
    }

    @Test func missingModelIsReportedByName() async {
        let (client, _) = makeClient(replies: [
            .response(statusCode: 404, body: #"{"error":"model 'qwen3-vl:8b' not found"}"#)
        ])

        await #expect(throws: LanguageModelError.modelNotInstalled(modelName: "qwen3-vl:8b")) {
            _ = try await client.respond(to: request)
        }
    }

    @Test func stoppedServerIsReportedAsUnreachable() async {
        let (client, _) = makeClient(replies: [.failure(.cannotConnectToHost)])

        await #expect(throws: LanguageModelError.self) {
            _ = try await client.respond(to: request)
        }
        do {
            _ = try await client.respond(to: request)
        } catch {
            guard case .serverUnreachable = error else {
                Issue.record("Expected serverUnreachable, got \(error)")
                return
            }
        }
    }

    @Test func timeoutIsReported() async {
        let (client, _) = makeClient(replies: [.failure(.timedOut)])

        await #expect(throws: LanguageModelError.timedOut) {
            _ = try await client.respond(to: request)
        }
    }

    @Test func garbageResponseIsMalformed() async {
        let (client, _) = makeClient(replies: [.response(statusCode: 200, body: "not json")])

        await #expect(throws: LanguageModelError.self) {
            _ = try await client.respond(to: request)
        }
    }

    @Test func listsInstalledModels() async throws {
        let (client, fakeTransport) = makeClient(replies: [
            .response(
                statusCode: 200,
                body: #"{"models":[{"name":"qwen3-vl:8b"},{"name":"nomic-embed-text:latest"}]}"#)
        ])

        let modelNames = try await client.installedModelNames()

        #expect(modelNames == ["qwen3-vl:8b", "nomic-embed-text:latest"])
        #expect(
            fakeTransport.sentRequests.first?.url?.absoluteString
                == "http://127.0.0.1:11434/api/tags")
    }
}

struct OllamaThinkingModelTests {
    let request = LanguageModelRequest(
        systemPrompt: "s", userPrompt: "u", responseSchema: ["type": "object"])

    @Test func answerPlacedInTheThinkingFieldIsStillRead() async throws {
        let fakeTransport = FakeHTTPTransport(replies: [
            .response(
                statusCode: 200,
                body:
                    #"{"message":{"role":"assistant","content":"","thinking":"{\"kind\":\"task\",\"steps\":[]}"},"done":true}"#
            )
        ])
        let client = OllamaClient(transport: fakeTransport, modelName: "qwen3-vl:8b")

        #expect(try await client.respond(to: request) == #"{"kind":"task","steps":[]}"#)
    }

    @Test func emptyAnswerEverywhereIsAnError() async {
        let fakeTransport = FakeHTTPTransport(replies: [
            .response(
                statusCode: 200,
                body: #"{"message":{"role":"assistant","content":"","thinking":""},"done":true}"#)
        ])
        let client = OllamaClient(transport: fakeTransport, modelName: "qwen3-vl:8b")

        await #expect(throws: LanguageModelError.self) {
            _ = try await client.respond(to: request)
        }
    }

    @Test func generationLengthIsCapped() async throws {
        let fakeTransport = FakeHTTPTransport(replies: [
            .response(
                statusCode: 200,
                body: #"{"message":{"role":"assistant","content":"{}"},"done":true}"#)
        ])
        let client = OllamaClient(transport: fakeTransport, modelName: "qwen3-vl:8b")

        _ = try await client.respond(to: request)

        let body = try jsonObject(of: try #require(fakeTransport.sentRequests.first))
        #expect(
            (body["options"] as? [String: Any])?["num_predict"] as? Int
                == OllamaClient.maximumAnswerTokens)
    }
}
