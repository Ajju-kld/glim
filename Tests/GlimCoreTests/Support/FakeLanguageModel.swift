import Synchronization

@testable import GlimCore

/// Answers with scripted replies and records every request.
final class FakeLanguageModel: LanguageModel {
    private let scriptedAnswers: Mutex<[Result<String, LanguageModelError>]>
    private let recordedRequests = Mutex<[LanguageModelRequest]>([])

    init(answers: [Result<String, LanguageModelError>]) {
        scriptedAnswers = Mutex(answers)
    }

    convenience init(answer: String) {
        self.init(answers: [.success(answer)])
    }

    var requests: [LanguageModelRequest] {
        recordedRequests.withLock { $0 }
    }

    func respond(to request: LanguageModelRequest) async throws(LanguageModelError) -> String {
        recordedRequests.withLock { $0.append(request) }
        let answer = scriptedAnswers.withLock { answers in
            answers.isEmpty ? nil : answers.removeFirst()
        }
        switch answer {
        case .success(let text): return text
        case .failure(let error): throw error
        case nil: throw .malformedResponse(reason: "No answer scripted")
        }
    }
}
