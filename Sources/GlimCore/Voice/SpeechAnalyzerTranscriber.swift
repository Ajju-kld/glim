@preconcurrency import AVFoundation
import Foundation
import Speech

/// Push-to-talk speech recognition that runs entirely on this Mac, using macOS 26's
/// `SpeechAnalyzer`. The microphone is on only between `startListening` and `stopListening`.
public actor SpeechAnalyzerTranscriber: PushToTalkTranscribing {
    private static let preferredLocale = Locale(identifier: "en-US")
    private static let inputBus: AVAudioNodeBus = 0
    /// Tunable: microphone buffer size in frames.
    private static let tapBufferSize: AVAudioFrameCount = 4_096

    private var sessionGate = ListeningSessionGate()
    private var audioEngine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var eventContinuation: AsyncStream<VoiceEvent>.Continuation?
    private var resultsTask: Task<String, any Error>?

    /// Creates a transcriber.
    public init() {}

    /// Starts the microphone and recognition. If the talk key is released while this is still
    /// starting, it throws ``VoiceInputError/cancelledBeforeReady`` and the microphone stays off.
    public func startListening() async throws(VoiceInputError) -> AsyncStream<VoiceEvent> {
        await cancelListening()
        let session = sessionGate.beginStarting()
        try await Self.ensurePermissions()
        try ensureStillStarting(session)
        guard
            let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Self.preferredLocale)
        else {
            throw .localeNotSupported
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        try await Self.installSpeechAssetsIfNeeded(for: transcriber)
        try ensureStillStarting(session)
        guard
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [
                transcriber
            ])
        else {
            throw .speechUnavailable(reason: "No audio format is available for recognition.")
        }
        try ensureStillStarting(session)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        let (events, eventContinuation) = AsyncStream<VoiceEvent>.makeStream()
        do {
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            throw .speechUnavailable(reason: error.localizedDescription)
        }
        guard sessionGate.shouldContinueStarting(session) else {
            inputContinuation.finish()
            eventContinuation.finish()
            await analyzer.cancelAndFinishNow()
            throw .cancelledBeforeReady
        }
        resultsTask = Self.collectTranscript(
            from: transcriber.results, reportingTo: eventContinuation)

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: Self.inputBus)
        let tapProcessor = try AudioTapProcessor(
            inputFormat: inputFormat, analyzerFormat: analyzerFormat,
            inputContinuation: inputContinuation, eventContinuation: eventContinuation)
        engine.inputNode.installTap(
            onBus: Self.inputBus, bufferSize: Self.tapBufferSize, format: inputFormat
        ) {
            buffer, _ in
            tapProcessor.process(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: Self.inputBus)
            throw .audioEngineFailed(reason: error.localizedDescription)
        }
        self.audioEngine = engine
        self.analyzer = analyzer
        self.inputContinuation = inputContinuation
        self.eventContinuation = eventContinuation
        guard sessionGate.finishStarting(session) else {
            await cancelListening()
            throw .cancelledBeforeReady
        }
        return events
    }

    /// Stops the microphone, lets recognition finish, and returns the transcript. A release
    /// that arrives while the microphone is still starting returns an empty transcript.
    public func stopListening() async throws(VoiceInputError) -> String {
        switch sessionGate.requestStop() {
        case .cancelStart:
            return ""
        case .nothingToStop:
            throw .notListening
        case .stopListening:
            break
        }
        guard let analyzer, let resultsTask else {
            throw .notListening
        }
        stopMicrophone()
        inputContinuation?.finish()
        let transcript: String
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            transcript = try await resultsTask.value
        } catch {
            finishSession()
            throw .speechUnavailable(reason: error.localizedDescription)
        }
        finishSession()
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stops immediately and discards everything heard, including a start in progress.
    public func cancelListening() async {
        sessionGate.reset()
        stopMicrophone()
        inputContinuation?.finish()
        await analyzer?.cancelAndFinishNow()
        resultsTask?.cancel()
        finishSession()
    }

    private func ensureStillStarting(_ session: Int) throws(VoiceInputError) {
        guard sessionGate.shouldContinueStarting(session) else {
            throw .cancelledBeforeReady
        }
    }

    // MARK: - Helpers

    private func stopMicrophone() {
        audioEngine?.inputNode.removeTap(onBus: Self.inputBus)
        audioEngine?.stop()
        audioEngine = nil
    }

    private func finishSession() {
        eventContinuation?.finish()
        analyzer = nil
        inputContinuation = nil
        eventContinuation = nil
        resultsTask = nil
    }

    /// Builds the transcript from finalized results, reporting finalized plus in-progress text
    /// after every update.
    private static func collectTranscript<Results: AsyncSequence & Sendable>(
        from results: Results, reportingTo eventContinuation: AsyncStream<VoiceEvent>.Continuation
    ) -> Task<String, any Error> where Results.Element == SpeechTranscriber.Result {
        Task {
            var finalizedText = ""
            for try await result in results {
                let resultText = String(result.text.characters)
                if result.isFinal {
                    finalizedText += resultText
                    eventContinuation.yield(.transcript(finalizedText))
                } else {
                    eventContinuation.yield(.transcript(finalizedText + resultText))
                }
            }
            return finalizedText
        }
    }

    private static func ensurePermissions() async throws(VoiceInputError) {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw .microphoneNotAllowed
        }
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw .speechRecognitionNotAllowed
        }
    }

    /// The first use downloads Apple's on-device English model (macOS does this, not Glim).
    private static func installSpeechAssetsIfNeeded(for transcriber: SpeechTranscriber)
        async throws(VoiceInputError)
    {
        do {
            if let installationRequest = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber])
            {
                try await installationRequest.downloadAndInstall()
            }
        } catch {
            throw .speechUnavailable(reason: error.localizedDescription)
        }
    }
}
