//
//  WindowActionService.swift
//  vyra
//
//  Created by Codex on 27/03/26.
//

import AppKit
import ApplicationServices
import Foundation

enum WindowAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf:
            return "Move Window Left"
        case .rightHalf:
            return "Move Window Right"
        case .topHalf:
            return "Move Window Top"
        case .bottomHalf:
            return "Move Window Bottom"
        case .maximize:
            return "Maximize Window"
        case .center:
            return "Center Window"
        }
    }

    var subtitle: String {
        switch self {
        case .leftHalf:
            return "Snap the focused window to the left half of the active screen."
        case .rightHalf:
            return "Snap the focused window to the right half of the active screen."
        case .topHalf:
            return "Snap the focused window to the top half of the active screen."
        case .bottomHalf:
            return "Snap the focused window to the bottom half of the active screen."
        case .maximize:
            return "Fill the usable visible frame of the active screen."
        case .center:
            return "Center the focused window while keeping a comfortable working size."
        }
    }

    var systemImage: String {
        switch self {
        case .leftHalf:
            return "rectangle.lefthalf.inset.filled.arrow.left"
        case .rightHalf:
            return "rectangle.righthalf.inset.filled.arrow.right"
        case .topHalf:
            return "rectangle.tophalf.inset.filled"
        case .bottomHalf:
            return "rectangle.bottomhalf.inset.filled"
        case .maximize:
            return "macwindow.badge.plus"
        case .center:
            return "plus.rectangle.on.rectangle"
        }
    }

    var searchTerms: [String] {
        switch self {
        case .leftHalf:
            return ["left", "snap left", "half left", "tile left"]
        case .rightHalf:
            return ["right", "snap right", "half right", "tile right"]
        case .topHalf:
            return ["top", "upper", "snap top"]
        case .bottomHalf:
            return ["bottom", "lower", "snap bottom"]
        case .maximize:
            return ["maximize", "fullscreen", "full", "fill"]
        case .center:
            return ["center", "middle", "focus"]
        }
    }

    func matchScore(for query: String) -> Int? {
        let normalizedQuery = Self.normalize(query)

        if normalizedQuery.isEmpty {
            switch self {
            case .maximize:
                return 2_100
            case .leftHalf, .rightHalf:
                return 2_000
            case .center:
                return 1_900
            case .topHalf, .bottomHalf:
                return 1_800
            }
        }

        let tokens = [title, subtitle] + searchTerms

        for token in tokens {
            let normalizedToken = Self.normalize(token)
            if normalizedToken == normalizedQuery {
                return 10_000
            }

            if normalizedToken.hasPrefix(normalizedQuery) {
                return 8_000
            }

            if normalizedToken.contains(normalizedQuery) {
                return 6_500
            }
        }

        return nil
    }

    func targetFrame(current: CGRect, visibleFrame: CGRect) -> CGRect {
        switch self {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .topHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.midY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
        case .bottomHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
        case .maximize:
            return visibleFrame
        case .center:
            let width = min(max(current.width, visibleFrame.width * 0.45), visibleFrame.width * 0.8)
            let height = min(max(current.height, visibleFrame.height * 0.45), visibleFrame.height * 0.8)

            return CGRect(
                x: visibleFrame.midX - (width / 2),
                y: visibleFrame.midY - (height / 2),
                width: width,
                height: height
            )
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

enum WindowActionError: LocalizedError {
    case accessibilityDenied
    case noFocusedApplication
    case noFocusedWindow
    case unableToReadWindowFrame
    case unableToResizeWindow

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Enable Accessibility access for Vyra to move and resize other app windows."
        case .noFocusedApplication:
            return "No focused app was found to target with a window action."
        case .noFocusedWindow:
            return "The focused app does not currently expose a focused window."
        case .unableToReadWindowFrame:
            return "Vyra could not read the focused window frame."
        case .unableToResizeWindow:
            return "Vyra could not move or resize the focused window."
        }
    }
}

@MainActor
final class WindowActionService {
    func perform(_ action: WindowAction) throws {
        guard checkAccessibility(prompt: true) else {
            throw WindowActionError.accessibilityDenied
        }

        let window = try focusedWindow()
        let currentFrame = try frame(for: window)
        let visibleFrame = visibleFrame(for: currentFrame)
        let targetFrame = action.targetFrame(current: currentFrame, visibleFrame: visibleFrame)
        try setFrame(targetFrame, for: window)
    }

    func accessibilityStatusText() -> String {
        checkAccessibility(prompt: false)
            ? "Accessibility ready for window actions"
            : "Accessibility needed for window actions"
    }

    /// Check if Accessibility is enabled. If `prompt` is true, show the system dialog.
    func checkAccessibility(prompt: Bool) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request Accessibility permission and open System Settings to the Accessibility pane.
    @discardableResult
    func requestAccessibility() -> Bool {
        // Trigger the system prompt (only works once per app lifecycle).
        let trusted = checkAccessibility(prompt: true)

        if !trusted {
            // Open System Settings directly to the Accessibility pane so the user can toggle it.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        return trusted
    }

    private func focusedWindow() throws -> AXUIElement {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            throw WindowActionError.noFocusedApplication
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success, let focusedWindow else {
            throw WindowActionError.noFocusedWindow
        }

        return focusedWindow as! AXUIElement
    }

    private func frame(for window: AXUIElement) throws -> CGRect {
        let position = try pointValue(for: kAXPositionAttribute as CFString, on: window)
        let size = try sizeValue(for: kAXSizeAttribute as CFString, on: window)
        return CGRect(origin: position, size: size)
    }

    private func visibleFrame(for frame: CGRect) -> CGRect {
        let midpoint = CGPoint(x: frame.midX, y: frame.midY)

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(midpoint) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? frame
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) throws {
        var origin = frame.origin
        var size = frame.size

        guard
            let originValue = AXValueCreate(.cgPoint, &origin),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            throw WindowActionError.unableToResizeWindow
        }

        let setPositionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            originValue
        )
        let setSizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard setPositionResult == .success, setSizeResult == .success else {
            throw WindowActionError.unableToResizeWindow
        }
    }

    private func pointValue(for attribute: CFString, on element: AXUIElement) throws -> CGPoint {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success, let value else {
            throw WindowActionError.unableToReadWindowFrame
        }
        let axValue = value as! AXValue

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            throw WindowActionError.unableToReadWindowFrame
        }

        return point
    }

    private func sizeValue(for attribute: CFString, on element: AXUIElement) throws -> CGSize {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success, let value else {
            throw WindowActionError.unableToReadWindowFrame
        }
        let axValue = value as! AXValue

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            throw WindowActionError.unableToReadWindowFrame
        }

        return size
    }
}
