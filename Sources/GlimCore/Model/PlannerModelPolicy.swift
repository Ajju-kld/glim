/// Which Ollama model names Glim may use. Newer Ollama versions can serve cloud-hosted models
/// through the same local address; those would send goals, screen text and screenshots off the
/// Mac while looking local, so they are refused (spec §3: cloud models are a non-goal).
public enum PlannerModelPolicy {
    /// Business rule: Ollama marks cloud-hosted models with "cloud" in the tag.
    static let cloudMarker = "cloud"

    /// Whether `modelName` names a local model: not empty, no whitespace, no URL, no cloud tag.
    public static func isLocalModelName(_ modelName: String) -> Bool {
        let hasContent = !modelName.isEmpty && !modelName.contains(where: \.isWhitespace)
        let isURL = modelName.contains("://")
        let isCloud = modelName.lowercased().contains(cloudMarker)
        return hasContent && !isURL && !isCloud
    }
}
