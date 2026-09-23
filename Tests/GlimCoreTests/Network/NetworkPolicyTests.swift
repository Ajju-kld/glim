import Foundation
import Testing

@testable import GlimCore

struct NetworkPolicyTests {
    let localOnlyPolicy = NetworkPolicy(isJevEnabled: false)
    let policyWithJev = NetworkPolicy(isJevEnabled: true)

    @Test(arguments: [
        "http://127.0.0.1:11434/api/chat",
        "http://127.0.0.1:8791/v1/systemone",
    ])
    func localServicesAreAllowed(address: String) throws {
        let url = try #require(URL(string: address))

        try localOnlyPolicy.validate(url)
    }

    @Test func jevIsAllowedOnlyWhenEnabled() throws {
        let jevURL = try #require(URL(string: "https://api.typesafe.ai/v1/systemone"))

        try policyWithJev.validate(jevURL)
        #expect(throws: NetworkPolicyError.jevDisabled) {
            try localOnlyPolicy.validate(jevURL)
        }
    }

    @Test(arguments: [
        "http://localhost:11434/api/chat",
        "http://127.0.0.1:8080/api/chat",
        "https://127.0.0.1:11434/api/chat",
        "http://api.typesafe.ai/v1/systemone",
        "https://api.typesafe.ai.evil.example/v1/systemone",
        "https://evil.example/v1/systemone",
        "http://127.0.0.1:11434@evil.example/api/chat",
        "http://user:secret@127.0.0.1:11434/api/chat",
        "file:///etc/passwd",
    ])
    func everythingElseIsRejected(address: String) throws {
        let url = try #require(URL(string: address))

        #expect(throws: NetworkPolicyError.self) {
            try policyWithJev.validate(url)
        }
    }

    @Test func endpointBuildsValidatedURLs() throws {
        let url = try NetworkEndpoint.ollama.url(path: "/api/chat")

        #expect(url.absoluteString == "http://127.0.0.1:11434/api/chat")
        try localOnlyPolicy.validate(url)
    }

    @Test func pathWithoutLeadingSlashIsRejected() {
        #expect(throws: NetworkPolicyError.invalidURL(path: "api/chat")) {
            try NetworkEndpoint.ollama.url(path: "api/chat")
        }
    }
}
