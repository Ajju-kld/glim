import Testing

@testable import GlimCore

struct ActionLimiterTests {
    let limits = SafetyLimits.safeDefaults
    let taskStart = ContinuousClock.now

    func makeLimiter() -> ActionLimiter {
        ActionLimiter(limits: limits, taskStartedAt: taskStart)
    }

    @Test func freshTaskHasNoViolation() {
        #expect(makeLimiter().violation(at: taskStart) == nil)
    }

    @Test func actionLimitIsEnforced() {
        var limiter = makeLimiter()
        var now = taskStart
        for _ in 0..<limits.maximumActionsPerTask {
            now += .seconds(1)
            limiter.recordAction(at: now, changedScreen: true)
        }

        #expect(
            limiter.violation(at: now + .seconds(1))
                == .tooManyActions(limit: limits.maximumActionsPerTask))
    }

    @Test func modelErrorsAreLimitedPerStep() {
        var limiter = makeLimiter()
        for _ in 0..<limits.maximumTriesPerStep {
            limiter.recordModelError()
        }

        #expect(
            limiter.violation(at: taskStart)
                == .tooManyTriesForStep(limit: limits.maximumTriesPerStep))
    }

    @Test func nextStepStartsWithFreshTries() {
        var limiter = makeLimiter()
        for _ in 0..<limits.maximumTriesPerStep {
            limiter.recordModelError()
        }
        limiter.beginNextStep()

        #expect(limiter.violation(at: taskStart) == nil)
    }

    @Test func actionsThatChangeNothingAreLimited() {
        var limiter = makeLimiter()
        var now = taskStart
        for _ in 0..<limits.maximumConsecutiveUnchangedActions {
            now += .seconds(1)
            limiter.recordAction(at: now, changedScreen: false)
        }

        #expect(
            limiter.violation(at: now + .seconds(1))
                == .noVisibleChange(limit: limits.maximumConsecutiveUnchangedActions))
    }

    @Test func aVisibleChangeResetsTheUnchangedStreak() {
        var limiter = makeLimiter()
        limiter.recordAction(at: taskStart + .seconds(1), changedScreen: false)
        limiter.recordAction(at: taskStart + .seconds(2), changedScreen: false)
        limiter.recordAction(at: taskStart + .seconds(3), changedScreen: true)

        #expect(limiter.consecutiveUnchangedActions == 0)
    }

    @Test func actionsTooCloseTogetherAreReportedWithTheWait() {
        var limiter = makeLimiter()
        let firstActionAt = taskStart + .seconds(1)
        limiter.recordAction(at: firstActionAt, changedScreen: true)
        let tooSoon = firstActionAt + .milliseconds(100)

        #expect(
            limiter.violation(at: tooSoon)
                == .actionsTooClose(minimumSeconds: limits.minimumSecondsBetweenActions))
        #expect(limiter.waitBeforeNextAction(at: tooSoon) == .milliseconds(150))
        #expect(limiter.violation(at: firstActionAt + .milliseconds(250)) == nil)
    }

    @Test func taskDeadlineIsEnforcedFirst() {
        var limiter = makeLimiter()
        for _ in 0..<limits.maximumTriesPerStep {
            limiter.recordModelError()
        }

        #expect(
            limiter.violation(at: taskStart + limits.taskTimeout)
                == .taskTimedOut(limitSeconds: limits.taskTimeoutSeconds))
    }
}
