/// Walks a tree level by level within a budget.
///
/// Apps like Notes and Spotify put long lists (every note, every track) deep in the tree and
/// the toolbar near the top. Walking depth-first spent the whole budget inside the list and never
/// reached the toolbar; level by level, the controls near the top are always read first.
enum BreadthFirstWalk {
    /// What was visited, in visit order: each element, what `visit` read from it, and its
    /// children as indices into these arrays, in their original order. Index 0 is the root.
    struct Result<Element, Details> {
        var elements: [Element] = []
        var details: [Details] = []
        var childIndices: [[Int]] = []
    }

    /// Visits `root` and its descendants breadth-first.
    ///
    /// - Parameters:
    ///   - root: Where the walk starts; it is always visited.
    ///   - maximumDepth: The deepest level whose children are still walked (the root is 0).
    ///   - shouldContinue: Given how many elements were visited so far, whether to visit another.
    ///   - visit: Reads an element: its details and its children.
    /// - Returns: What was visited, with the parent–child links between visited elements.
    static func walk<Element, Details>(
        from root: Element,
        maximumDepth: Int,
        shouldContinue: (_ visitedCount: Int) -> Bool,
        visit: (Element) -> (details: Details, children: [Element])
    ) -> Result<Element, Details> {
        var result = Result<Element, Details>()
        var queue: [(element: Element, parentIndex: Int?, depth: Int)] = [(root, nil, 0)]
        var queueHead = 0
        while queueHead < queue.count {
            guard result.elements.isEmpty || shouldContinue(result.elements.count) else {
                break
            }
            let (element, parentIndex, depth) = queue[queueHead]
            queueHead += 1
            let index = result.elements.count
            let (details, children) = visit(element)
            result.elements.append(element)
            result.details.append(details)
            result.childIndices.append([])
            if let parentIndex {
                result.childIndices[parentIndex].append(index)
            }
            if depth < maximumDepth {
                queue.append(contentsOf: children.map { ($0, index, depth + 1) })
            }
        }
        return result
    }
}
