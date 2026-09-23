/// The model's plan answer as decoded JSON, before validation. Unknown fields are ignored.
struct PlanAnswer: Decodable {
    struct Step: Decodable {
        let action: String
        let app: String?
        let target: String?
        let text: String?
        let key: String?
        let direction: String?
        let preset: String?
    }

    let kind: String
    let steps: [Step]
}

extension PlanAnswer.Step {
    /// Converts the decoded step into a typed action, checking every field the action needs.
    func stepAction(number stepNumber: Int) throws(PlannerError) -> StepAction {
        guard let kind = ActionKind(rawValue: action) else {
            throw .invalidStep(stepNumber: stepNumber, reason: "Unknown action “\(action)”.")
        }
        if kind == .speak {
            return .speak(text: try required(text, "text", stepNumber))
        }
        let appName = try required(app, "app", stepNumber)
        switch kind {
        case .openApp:
            return .openApp(appName: appName)
        case .switchApp:
            return .switchApp(appName: appName)
        case .quitApp:
            return .quitApp(appName: appName)
        case .minimizeWindow:
            return .minimizeWindow(appName: appName)
        case .restoreWindow:
            return .restoreWindow(appName: appName)
        case .click:
            return .click(appName: appName, target: try required(target, "target", stepNumber))
        case .typeText:
            return .typeText(
                appName: appName,
                target: try required(target, "target", stepNumber),
                text: try required(text, "text", stepNumber))
        case .pressKey:
            return .pressKey(appName: appName, key: try parsed(key, "key", stepNumber))
        case .scroll:
            return .scroll(
                appName: appName, direction: try parsed(direction, "direction", stepNumber))
        case .moveWindow:
            return .moveWindow(appName: appName, preset: try parsed(preset, "preset", stepNumber))
        case .speak:
            return .speak(text: try required(text, "text", stepNumber))
        }
    }

    private func required(
        _ value: String?, _ fieldName: String, _ stepNumber: Int
    ) throws(PlannerError) -> String {
        guard let value, value.contains(where: { !$0.isWhitespace }) else {
            throw .invalidStep(stepNumber: stepNumber, reason: "Missing “\(fieldName)”.")
        }
        return value
    }

    private func parsed<Value: RawRepresentable<String>>(
        _ value: String?, _ fieldName: String, _ stepNumber: Int
    ) throws(PlannerError) -> Value {
        let rawValue = try required(value, fieldName, stepNumber)
        guard let parsedValue = Value(rawValue: rawValue) else {
            throw .invalidStep(
                stepNumber: stepNumber, reason: "“\(rawValue)” is not an allowed \(fieldName).")
        }
        return parsedValue
    }
}
