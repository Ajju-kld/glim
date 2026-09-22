/// Picks the candidates a checker sees: those sharing the most meaningful words with the
/// approved target, in table order among ties.
enum CandidateShortlist {
    static func shortlist(
        _ candidates: [UIElementSnapshot], targetDescription: String, limit: Int
    ) -> [UIElementSnapshot] {
        guard candidates.count > limit else {
            return candidates
        }
        let targetWords = PlanMatcher.meaningfulWords(in: targetDescription)
        let scoredCandidates = candidates.enumerated().map { offset, candidate in
            let candidateText = [candidate.label, candidate.title, candidate.elementDescription]
                .compactMap { $0 }
                .joined(separator: " ")
            let sharedWordCount = PlanMatcher.meaningfulWords(in: candidateText)
                .intersection(targetWords).count
            return (candidate: candidate, sharedWordCount: sharedWordCount, tableOrder: offset)
        }
        return
            scoredCandidates
            .sorted { first, second in
                first.sharedWordCount != second.sharedWordCount
                    ? first.sharedWordCount > second.sharedWordCount
                    : first.tableOrder < second.tableOrder
            }
            .prefix(limit)
            .map(\.candidate)
    }
}
