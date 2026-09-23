@preconcurrency import AVFoundation
import Speech
import os

/// Converts microphone buffers to the analyzer's format and reports the level.
///
/// `@unchecked Sendable` because the audio engine calls ``process(_:)`` from its tap thread
/// one buffer at a time; the converter is only ever touched there.
final class AudioTapProcessor: @unchecked Sendable {
    private static let logger = Logger(subsystem: "dev.straxs.Glim", category: "Voice")

    private let converter: AVAudioConverter
    private let analyzerFormat: AVAudioFormat
    private let inputContinuation: AsyncStream<AnalyzerInput>.Continuation
    private let eventContinuation: AsyncStream<VoiceEvent>.Continuation

    init(
        inputFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat,
        inputContinuation: AsyncStream<AnalyzerInput>.Continuation,
        eventContinuation: AsyncStream<VoiceEvent>.Continuation
    ) throws(VoiceInputError) {
        guard let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
            throw .audioEngineFailed(
                reason: "The microphone format can't be converted for speech recognition.")
        }
        self.converter = converter
        self.analyzerFormat = analyzerFormat
        self.inputContinuation = inputContinuation
        self.eventContinuation = eventContinuation
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        eventContinuation.yield(.level(Self.level(of: buffer)))
        let sampleRateRatio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let convertedCapacity =
            AVAudioFrameCount((Double(buffer.frameLength) * sampleRateRatio).rounded(.up)) + 1
        guard
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: analyzerFormat, frameCapacity: convertedCapacity)
        else {
            Self.logger.error("Could not allocate a converted audio buffer.")
            return
        }
        let bufferSupplier = OneShotBufferSupplier(buffer: buffer)
        var conversionError: NSError?
        converter.convert(to: convertedBuffer, error: &conversionError) { _, inputStatus in
            guard let nextBuffer = bufferSupplier.takeBuffer() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return nextBuffer
        }
        if let conversionError {
            Self.logger.error(
                "Audio conversion failed: \(conversionError.localizedDescription, privacy: .public)"
            )
            return
        }
        inputContinuation.yield(AnalyzerInput(buffer: convertedBuffer))
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }
        let samples = Array(
            UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        return AudioLevel.normalizedLevel(ofSamples: samples)
    }
}

/// Hands the converter one microphone buffer, then reports "no data" until the next tap.
///
/// `@unchecked Sendable` because the converter calls the input block synchronously inside
/// `convert(to:error:withInputFrom:)` on the tap thread; nothing else touches this object.
private final class OneShotBufferSupplier: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func takeBuffer() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
