//
//  OnboardingView.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var stepIndex = 0
    @State private var accessibilityGranted = false
    @State private var isRecordingHotkey = false
    @State private var paletteWasOpened = false

    /// Timer that polls accessibility status for page 2.
    @State private var accessibilityTimer: Timer?
    /// Observer for palette-opened notification on page 4.
    @State private var paletteObserver: NSObjectProtocol?

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // ── Page content ──
            Group {
                switch stepIndex {
                case 0: introPage
                case 1: permissionsPage
                case 2: hotkeyPage
                case 3: verifyPage
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // ── Bottom navigation ──
            HStack {
                if stepIndex > 0 {
                    Button("Previous") {
                        withAnimation { stepIndex -= 1 }
                    }
                }

                Spacer()

                // Step indicator
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == stepIndex ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if stepIndex < totalSteps - 1 {
                    Button("Next") {
                        advanceNext()
                    }
                    .disabled(!canAdvance)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Finish") {
                        finishOnboarding()
                    }
                    .disabled(!canAdvance)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 460)
        .background(
            // Cmd+Enter to advance
            Button("") { advanceNext() }
                .keyboardShortcut(.return, modifiers: .command)
                .hidden()
        )
        .onDisappear {
            accessibilityTimer?.invalidate()
            if let observer = paletteObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // MARK: - Navigation helpers

    private var canAdvance: Bool {
        switch stepIndex {
        case 0: return true
        case 1: return accessibilityGranted
        case 2: return true // Hotkey always has a default
        case 3: return paletteWasOpened
        default: return false
        }
    }

    private func advanceNext() {
        guard canAdvance else { return }
        if stepIndex < totalSteps - 1 {
            withAnimation { stepIndex += 1 }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        guard canAdvance else { return }
        viewModel.settingsStore.hasCompletedOnboarding = true
        dismiss()
        // Also close the window directly
        NSApp.keyWindow?.close()
    }

    // MARK: - Page 1: Intro

    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "command.square")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Welcome to Vyra")
                .font(.largeTitle.weight(.bold))

            Text("A fast command palette for your Mac.\nLaunch apps, manage windows, record macros, and more—all from one place.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            Spacer()
        }
        .padding()
    }

    // MARK: - Page 2: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(accessibilityGranted ? .green : .orange)

            Text("Accessibility Permission")
                .font(.title2.weight(.semibold))

            Text("Vyra needs Accessibility access to move and resize windows and respond to global hotkeys.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Circle()
                    .fill(accessibilityGranted ? .green : .red)
                    .frame(width: 10, height: 10)

                Text(accessibilityGranted ? "Accessibility enabled" : "Accessibility not enabled")
                    .font(.callout.weight(.medium))
            }
            .padding(.top, 4)

            if !accessibilityGranted {
                Button("Request Permission") {
                    accessibilityGranted = viewModel.requestAccessibilityPermission()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Text("After granting, you may need to wait a moment for macOS to reflect the change.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            accessibilityGranted = viewModel.isAccessibilityEnabled
            // Poll accessibility status while on this page
            accessibilityTimer?.invalidate()
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    accessibilityGranted = viewModel.isAccessibilityEnabled
                }
            }
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
        }
    }

    // MARK: - Page 3: Hotkey selection

    private var hotkeyPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Set Your Hotkey")
                .font(.title2.weight(.semibold))

            Text("Use a global shortcut to summon Vyra from anywhere.\nThe default is **⌃Space** (Control + Space).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            // Current hotkey display
            let currentShortcut = viewModel.settingsStore.hotkeyAssignments["vyra:openPalette"]
            let displayText = currentShortcut != nil
                ? shortcutDisplayString(currentShortcut)
                : "⌃Space (default)"

            Text(displayText)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            Button("Change Hotkey") {
                isRecordingHotkey = true
            }
            .controlSize(.large)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $isRecordingHotkey) {
            HotkeyRecorderSheet(
                title: "Record Hotkey for Open Palette",
                onCancel: {
                    isRecordingHotkey = false
                },
                onRecorded: { shortcut in
                    var assignments = viewModel.settingsStore.hotkeyAssignments
                    assignments["vyra:openPalette"] = shortcut
                    viewModel.settingsStore.hotkeyAssignments = assignments
                    AppModel.shared.registerPaletteHotkeyFromSettings()
                    isRecordingHotkey = false
                }
            )
            .frame(width: 420, height: 200)
        }
    }

    // MARK: - Page 4: Verify hotkey

    private var verifyPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: paletteWasOpened ? "checkmark.circle.fill" : "hand.tap")
                .font(.system(size: 48))
                .foregroundStyle(paletteWasOpened ? .green : Color.accentColor)

            Text(paletteWasOpened ? "You're All Set!" : "Try Your Hotkey")
                .font(.title2.weight(.semibold))

            if paletteWasOpened {
                Text("Vyra opened successfully. You're ready to go!")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            } else {
                let currentShortcut = viewModel.settingsStore.hotkeyAssignments["vyra:openPalette"]
                let hotkeyText = currentShortcut != nil
                    ? shortcutDisplayString(currentShortcut)
                    : "⌃Space"

                Text("Press **\(hotkeyText)** now to open the palette and verify everything works.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)

                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)

                Text("Waiting for hotkey…")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            paletteWasOpened = false
            // Listen for palette-opened notification
            paletteObserver = NotificationCenter.default.addObserver(
                forName: .vyraCommandPaletteDidOpen,
                object: nil,
                queue: .main
            ) { _ in
                paletteWasOpened = true
            }
        }
        .onDisappear {
            if let observer = paletteObserver {
                NotificationCenter.default.removeObserver(observer)
                paletteObserver = nil
            }
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let vyraCommandPaletteDidOpen = Notification.Name("vyraCommandPaletteDidOpen")
}
