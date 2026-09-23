import Foundation

/// Why the example file could not be read or written.
public enum LayaExampleStoreError: Error, Sendable, Equatable {
    case unreadable(reason: String)
    case unwritable(reason: String)
    case unknownExample

    /// One sentence for the control panel.
    public var explanation: String {
        switch self {
        case .unreadable(let reason): "The Laya examples could not be read: \(reason)"
        case .unwritable(let reason): "The Laya examples could not be saved: \(reason)"
        case .unknownExample: "That example is no longer saved."
        }
    }
}

/// Laya training examples as JSON Lines in one file on this Mac. Nothing here is uploaded.
public actor LayaExampleStore {
    /// The file's name inside the store's directory; the training scripts read it.
    public static let fileName = "examples.jsonl"

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a store that keeps its file in `directory`, created on first save.
    public init(directory: URL) {
        fileURL = directory.appending(path: Self.fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Adds one example at the end of the file.
    public func append(_ example: LayaExample) throws(LayaExampleStoreError) {
        var examples = try allExamples()
        examples.append(example)
        try write(examples)
    }

    /// Every saved example, oldest first.
    public func allExamples() throws(LayaExampleStoreError) -> [LayaExample] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return []
        }
        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return try text.split(separator: "\n").map { line in
                try decoder.decode(LayaExample.self, from: Data(line.utf8))
            }
        } catch {
            throw .unreadable(reason: error.localizedDescription)
        }
    }

    /// Stores the owner's review of one example.
    public func saveReview(_ review: LayaReview, forExampleID exampleID: UUID)
        throws(LayaExampleStoreError)
    {
        var examples = try allExamples()
        guard let index = examples.firstIndex(where: { $0.id == exampleID }) else {
            throw .unknownExample
        }
        examples[index] = examples[index].reviewed(review)
        try write(examples)
    }

    /// Removes every example.
    public func deleteAll() throws(LayaExampleStoreError) {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw .unwritable(reason: error.localizedDescription)
        }
    }

    private func write(_ examples: [LayaExample]) throws(LayaExampleStoreError) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let lines = try examples.map { example in
                String(decoding: try encoder.encode(example), as: UTF8.self)
            }
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(
                to: fileURL, options: .atomic)
        } catch {
            throw .unwritable(reason: error.localizedDescription)
        }
    }
}
