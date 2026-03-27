//
//  MacroReplayer.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import Combine
import Foundation

enum MacroReplayState: Equatable {
    case idle
    case running(stepIndex: Int, totalSteps: Int)
    case completed(successCount: Int, failureCount: Int)
    case failed(stepIndex: Int, error: String)
    case stopped(stepIndex: Int, totalSteps: Int)
}

struct MacroStepResult: Identifiable {
    let id = UUID()
    let stepIndex: Int
    let step: MacroStep
    let success: Bool
    let error: String?
    let duration: TimeInterval
}

@MainActor
final class MacroReplayer: ObservableObject {
    @Published private(set) var state: MacroReplayState = .idle
    @Published private(set) var stepResults: [MacroStepResult] = []
    @Published private(set) var currentStepIndex: Int = -1

    private var replayTask: Task<Void, Never>?
    private let windowActionService: WindowActionService

    init(windowActionService: WindowActionService) {
        self.windowActionService = windowActionService
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    func replay(macro: MacroDefinition) {
        guard !isRunning else { return }

        stepResults = []
        currentStepIndex = -1
        state = .running(stepIndex: 0, totalSteps: macro.steps.count)

        replayTask = Task { [weak self] in
            await self?.executeSteps(macro.steps)
        }
    }

    func stop() {
        replayTask?.cancel()
        replayTask = nil
        let stoppedAt = currentStepIndex
        let total = stepResults.count
        state = .stopped(stepIndex: stoppedAt, totalSteps: total)
    }

    func reset() {
        replayTask?.cancel()
        replayTask = nil
        state = .idle
        stepResults = []
        currentStepIndex = -1
    }

    private func executeSteps(_ steps: [MacroStep]) async {
        var successCount = 0
        var failureCount = 0

        for (index, step) in steps.enumerated() {
            guard !Task.isCancelled else {
                state = .stopped(stepIndex: index, totalSteps: steps.count)
                return
            }

            currentStepIndex = index
            state = .running(stepIndex: index, totalSteps: steps.count)

            if step.delayAfterMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(step.delayAfterMilliseconds) * 1_000_000)
            }

            guard !Task.isCancelled else {
                state = .stopped(stepIndex: index, totalSteps: steps.count)
                return
            }

            let startTime = Date.now
            let result = await executeStep(step, at: index)
            let duration = Date.now.timeIntervalSince(startTime)

            stepResults.append(MacroStepResult(
                stepIndex: index,
                step: step,
                success: result.success,
                error: result.error,
                duration: duration
            ))

            if result.success {
                successCount += 1
            } else {
                failureCount += 1
            }
        }

        if Task.isCancelled {
            state = .stopped(stepIndex: steps.count, totalSteps: steps.count)
        } else {
            state = .completed(successCount: successCount, failureCount: failureCount)
        }
    }

    private func executeStep(_ step: MacroStep, at index: Int) async -> (success: Bool, error: String?) {
        switch step.kind {
        case .launchApplication:
            return executeAppLaunch(step)
        case .openFile:
            return executeFileOpen(step)
        case .windowAction:
            return executeWindowAction(step)
        }
    }

    private func executeAppLaunch(_ step: MacroStep) -> (success: Bool, error: String?) {
        guard let path = step.applicationPath else {
            return (false, "No application path specified")
        }

        let url = URL(fileURLWithPath: path)
        let success = NSWorkspace.shared.open(url)
        if !success {
            return (false, "Failed to launch \(step.displayName)")
        }
        return (true, nil)
    }

    private func executeFileOpen(_ step: MacroStep) -> (success: Bool, error: String?) {
        guard let path = step.targetPath else {
            return (false, "No file path specified")
        }

        let url = URL(fileURLWithPath: path)
        let success = NSWorkspace.shared.open(url)
        if !success {
            return (false, "Failed to open \(step.displayName)")
        }
        return (true, nil)
    }

    private func executeWindowAction(_ step: MacroStep) -> (success: Bool, error: String?) {
        guard let action = step.windowAction else {
            return (false, "No window action specified")
        }

        do {
            try windowActionService.perform(action)
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
