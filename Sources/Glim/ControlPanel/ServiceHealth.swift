import Foundation
import GlimCore

/// Checks whether Ollama (with the chosen model) and the Laya service are reachable.
enum ServiceHealth {
    enum Status: Equatable {
        case checking
        case healthy(String)
        case unhealthy(String)

        var isHealthy: Bool? {
            switch self {
            case .checking: nil
            case .healthy: true
            case .unhealthy: false
            }
        }

        var detail: String {
            switch self {
            case .checking: "Checking…"
            case .healthy(let detail), .unhealthy(let detail): detail
            }
        }
    }

    private static let healthyStatusCode = 200

    static func ollamaStatus(modelName: String, transport: URLSessionTransport) async -> Status {
        let client = OllamaClient(
            transport: PolicyEnforcingTransport(
                base: transport, policy: NetworkPolicy(isJevEnabled: false)),
            modelName: modelName)
        do {
            let installedModels = try await client.installedModelNames()
            guard installedModels.contains(modelName) else {
                return .unhealthy("Run: ollama pull \(modelName)")
            }
            return .healthy("\(modelName) ready")
        } catch {
            return .unhealthy(error.explanation)
        }
    }

    static func layaStatus(transport: URLSessionTransport) async -> Status {
        let policyTransport = PolicyEnforcingTransport(
            base: transport, policy: NetworkPolicy(isJevEnabled: false))
        do {
            let request = URLRequest(url: try NetworkEndpoint.layaService.url(path: "/healthz"))
            let (_, response) = try await policyTransport.send(request)
            return response.statusCode == healthyStatusCode
                ? .healthy("Running on 127.0.0.1:8791") : .unhealthy("HTTP \(response.statusCode)")
        } catch {
            return .unhealthy("Not running — start with scripts/start-laya.sh")
        }
    }
}
