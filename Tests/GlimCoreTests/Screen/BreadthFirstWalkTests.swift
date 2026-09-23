import Testing

@testable import GlimCore

struct BreadthFirstWalkTests {
    /// A tree of names: "window" has a deep list first and a toolbar button last.
    let childrenByName: [String: [String]] = [
        "window": ["list", "toolbar"],
        "list": ["row1", "row2", "row3"],
        "row1": ["cell1a", "cell1b"],
        "row2": ["cell2a", "cell2b"],
        "row3": ["cell3a", "cell3b"],
        "toolbar": ["New Note"],
    ]

    func walk(maximumNodes: Int, maximumDepth: Int = 10) -> BreadthFirstWalk.Result<String, Int> {
        BreadthFirstWalk.walk(
            from: "window", maximumDepth: maximumDepth,
            shouldContinue: { visitedCount in visitedCount < maximumNodes },
            visit: { name in (details: name.count, children: childrenByName[name] ?? []) })
    }

    /// Shallow controls such as a toolbar button are reached before deep rows use up the budget.
    @Test func shallowNodesComeBeforeDeepOnesWhenTheBudgetRunsOut() {
        // Window, its two children, then the four second-level nodes: 7 fit before any cell.
        let result = walk(maximumNodes: 7)

        #expect(result.elements.contains("New Note"))
        #expect(!result.elements.contains("cell1a"))
        #expect(result.elements.count == 7)
    }

    @Test func childrenKeepTheirOrderUnderTheirParent() {
        let result = walk(maximumNodes: 100)
        let listIndex = result.elements.firstIndex(of: "list")
        let rowNames = result.childIndices[listIndex ?? 0].map { result.elements[$0] }

        #expect(rowNames == ["row1", "row2", "row3"])
        #expect(result.elements.first == "window")
        #expect(result.elements.count == 13)
        #expect(result.details.first == "window".count)
    }

    @Test func depthLimitStopsDescending() {
        let result = walk(maximumNodes: 100, maximumDepth: 1)

        #expect(result.elements == ["window", "list", "toolbar"])
    }
}
