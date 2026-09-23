import CryptoKit
import Synchronization

@testable import GlimCore

struct FixedSealKeyProvider: SealKeyProviding {
    let key: SymmetricKey

    func sealKey() throws -> SymmetricKey {
        key
    }
}

/// Answers every owner-confirmation request with a fixed answer and records the reasons asked.
final class ScriptedOwnerAuthenticator: OwnerAuthenticating {
    private let answer: Bool
    private let requestedReasons = Mutex<[String]>([])

    init(answer: Bool) {
        self.answer = answer
    }

    var reasons: [String] {
        requestedReasons.withLock { $0 }
    }

    func confirmOwner(reason: String) async -> Bool {
        requestedReasons.withLock { $0.append(reason) }
        return answer
    }
}
