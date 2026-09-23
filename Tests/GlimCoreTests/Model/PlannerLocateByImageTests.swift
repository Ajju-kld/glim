import Foundation
import Testing

@testable import GlimCore

struct PlannerLocateByImageTests {
    let screenshot = Data([0x89, 0x50, 0x4E, 0x47, 0x01])
    let clickPlay = StepAction.click(appName: "Spotify", target: "Play")

    func locate(answer: String) async throws(PlannerError) -> (VisualLocation, FakeLanguageModel) {
        let model = FakeLanguageModel(answer: answer)
        let location = try await Planner(languageModel: model).locateByImage(
            for: clickPlay, goal: "play music", screenshotPNG: screenshot)
        return (location, model)
    }

    @Test func sendsTheScreenshotAndTheStep() async throws {
        let (_, model) = try await locate(
            answer: #"{"description":"Play button","found":true,"x":480,"y":910}"#)

        let request = try #require(model.requests.first)
        #expect(request.imagesPNG == [screenshot])
        #expect(request.userPrompt.contains("Click “Play” in Spotify"))
        #expect(request.userPrompt.contains("play music"))
        #expect(request.maximumAnswerTokens == Planner.locateAnswerTokenLimit)
    }

    @Test func foundPointIsReturnedOnTheGrid() async throws {
        let (location, _) = try await locate(
            answer: #"{"description":"Play button","found":true,"x":480,"y":910}"#)

        #expect(location == .found(gridX: 480, gridY: 910, description: "Play button"))
    }

    @Test func modelCanReportNothingOnScreen() async throws {
        let (location, _) = try await locate(
            answer:
                #"{"description":"","found":false,"x":0,"y":0,"reason":"No play button visible"}"#)

        #expect(location == .notFound(reason: "No play button visible"))
    }

    @Test(arguments: [
        #"{"description":"Play","found":true,"x":1000,"y":10}"#,
        #"{"description":"Play","found":true,"x":10,"y":-1}"#,
    ])
    func pointOffTheGridIsAModelError(answer: String) async {
        await #expect(throws: PlannerError.self) {
            _ = try await locate(answer: answer)
        }
    }

    /// The description is what the person checks in the confirmation panel, so it can't be
    /// left out.
    @Test func foundPointWithoutADescriptionIsAModelError() async {
        await #expect(throws: PlannerError.self) {
            _ = try await locate(answer: #"{"description":"  ","found":true,"x":10,"y":10}"#)
        }
    }

    /// Ollama writes fields in schema order, so the model names what it is looking at before
    /// committing to a point.
    @Test func schemaAsksForTheDescriptionBeforeThePoint() throws {
        guard case .object(let schemaMembers) = PlannerSchemas.visualTarget,
            case .object(let propertyMembers) = schemaMembers.first(where: {
                $0.key == "properties"
            })?.value
        else {
            Issue.record("The schema has no properties object.")
            return
        }
        #expect(propertyMembers.map(\.key) == ["description", "found", "x", "y", "reason"])
    }
}
