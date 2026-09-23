/// Picks the candidates a model or checker sees: those closest in wording to the approved
/// target, in table order among ties.
///
/// A shared word counts for less the more candidates contain it: in Spotify every playlist row
/// says "songs", so "song" in a request says little, while "next" is in one control and decides.
enum CandidateShortlist {
    static func shortlist(
        _ candidates: [UIElementSnapshot], targetDescription: String, limit: Int
    ) -> [UIElementSnapshot] {
        guard candidates.count > limit else {
            return candidates
        }
        let candidateTexts = candidates.map { candidate in
            [candidate.label, candidate.title, candidate.elementDescription]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        let scores = relevanceScores(of: candidateTexts, to: targetDescription)
        return rankedIndices(by: scores).prefix(limit).map { candidates[$0] }
    }

    /// Up to `limit` of `labels` that share a meaningful word with `text`, most relevant first
    /// and in list order among ties; the first `limit` labels when none share a word.
    static func relevantLabels(_ labels: [String], to text: String, limit: Int) -> [String] {
        let scores = relevanceScores(of: labels, to: text)
        let relevantIndices = rankedIndices(by: scores).filter { scores[$0] > 0 }
        guard !relevantIndices.isEmpty else {
            return Array(labels.prefix(limit))
        }
        return relevantIndices.prefix(limit).map { labels[$0] }
    }

    /// Each text's score: for every word it shares with `text`, one divided by how many texts
    /// contain that word.
    private static func relevanceScores(of texts: [String], to text: String) -> [Double] {
        let wantedWords = PlanMatcher.meaningfulWords(in: text)
        let wordsPerText = texts.map {
            PlanMatcher.meaningfulWords(in: $0).intersection(wantedWords)
        }
        let textCountByWord = wordsPerText.reduce(into: [String: Int]()) { counts, words in
            for word in words {
                counts[word, default: 0] += 1
            }
        }
        return wordsPerText.map { words in
            words.reduce(0) { score, word in
                score + 1 / Double(textCountByWord[word] ?? 1)
            }
        }
    }

    /// Indices ordered by score, highest first, keeping list order among equal scores.
    private static func rankedIndices(by scores: [Double]) -> [Int] {
        scores.indices.sorted { first, second in
            scores[first] != scores[second] ? scores[first] > scores[second] : first < second
        }
    }
}
