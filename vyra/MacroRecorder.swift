//
//  MacroRecorder.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import Combine
import Foundation

enum MacroRecorderState {
    case idle
    case recording(startedAt: Date)
}

@MainActor
final class MacroRecorder: ObservableObject {
    @Published private(set) var state: MacroRecorderState = .idle
    @Published private(set) var recordedSteps: [MacroStep] = []
    @Published private(set) var stepCount: Int = 0

    private var lastStepTime: Date?
    private let minimumDelayMs = 200

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var recordingDuration: TimeInterval {
        if case .recording(let startedAt) = state {
            return Date.now.timeIntervalSince(startedAt)
        }
        return 0
    }

    func startRecording() {
        recordedSteps = []
        stepCount = 0
        lastStepTime = nil
        state = .recording(startedAt: .now)
    }

    func stopRecording() -> [MacroStep] {
        let steps = recordedSteps
        state = .idle
        recordedSteps = []
        stepCount = 0
        lastStepTime = nil
        return steps
    }

    func cancelRecording() {
        state = .idle
        recordedSteps = []
        stepCount = 0
        lastStepTime = nil
    }

    func recordAppLaunch(displayName: String, bundleIdentifier: String?, path: String) {
        guard isRecording else { return }

        let delay = calculateDelay()
        let step = MacroStep.launchApplication(
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            path: path,
            delayAfterMilliseconds: delay
        )
        appendStep(step)
    }

    func recordFileOpen(displayName: String, path: String) {
        guard isRecording else { return }

        let delay = calculateDelay()
        let step = MacroStep.openFile(
            displayName: displayName,
            path: path,
            delayAfterMilliseconds: delay
        )
        appendStep(step)
    }

    func recordWindowAction(_ action: WindowAction) {
        guard isRecording else { return }

        let delay = calculateDelay()
        let step = MacroStep.windowAction(
            action,
            delayAfterMilliseconds: delay
        )
        appendStep(step)
    }

    private func appendStep(_ step: MacroStep) {
        recordedSteps.append(step)
        stepCount = recordedSteps.count
        lastStepTime = .now
    }

    private func calculateDelay() -> Int {
        guard let lastStepTime else { return 0 }
        let elapsed = Int(Date.now.timeIntervalSince(lastStepTime) * 1000)
        return max(elapsed, minimumDelayMs)
    }
}
