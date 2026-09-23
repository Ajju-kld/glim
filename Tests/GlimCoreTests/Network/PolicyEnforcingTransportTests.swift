import Foundation
import Testing

@testable import GlimCore

struct PolicyEnforcingTransportTests {
    @Test func blockedAddressNeverReachesTheNetwork() async throws {
        let fakeTransport = FakeHTTPTransport(replies: [.response(statusCode: 200, body: "{}")])
        let transport = PolicyEnforcingTransport(
            base: fakeTransport, policy: NetworkPolicy(isJevEnabled: false))
        let request = URLRequest(url: try #require(URL(string: "https://evil.example/steal")))

        await #expect(throws: NetworkPolicyError.self) {
            _ = try await transport.send(request)
        }
        #expect(fakeTransport.sentRequests.isEmpty)
    }

    @Test func allowedAddressIsSent() async throws {
        let fakeTransport = FakeHTTPTransport(replies: [.response(statusCode: 200, body: "{}")])
        let transport = PolicyEnforcingTransport(
            base: fakeTransport, policy: NetworkPolicy(isJevEnabled: false))
        let request = URLRequest(url: try NetworkEndpoint.ollama.url(path: "/api/tags"))

        let (_, response) = try await transport.send(request)

        #expect(response.statusCode == 200)
        #expect(fakeTransport.sentRequests.count == 1)
    }

    @Test func responseFromAnotherAddressIsRejected() async throws {
        let fakeTransport = FakeHTTPTransport(replies: [
            .responseFrom(url: "https://evil.example/landing", statusCode: 200, body: "{}")
        ])
        let transport = PolicyEnforcingTransport(
            base: fakeTransport, policy: NetworkPolicy(isJevEnabled: false))
        let request = URLRequest(url: try NetworkEndpoint.ollama.url(path: "/api/tags"))

        await #expect(
            throws: HTTPTransportError.redirectRefused(to: "https://evil.example/landing")
        ) {
            _ = try await transport.send(request)
        }
    }
}
