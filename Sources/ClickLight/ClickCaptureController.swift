import Foundation

protocol ClickEventCapturing: AnyObject {
    var statusLabel: String { get }
    var usesEventTap: Bool { get }

    func start(mouseMovedEnabled: Bool, liveKeyboardShortcutsEnabled: Bool)
    func stop()
}

@MainActor
final class ClickCaptureController {
    private let settingsStore: SettingsStore
    private let eventTap: ClickEventCapturing

    init(settingsStore: SettingsStore, eventTap: ClickEventCapturing) {
        self.settingsStore = settingsStore
        self.eventTap = eventTap
    }

    var statusLabel: String {
        eventTap.statusLabel
    }

    var usesEventTap: Bool {
        eventTap.usesEventTap
    }

    /// `mouseMoved` is expensive to capture and is only needed when the laser
    /// dot follows the pointer. Drag strokes work off `*MouseDragged` events,
    /// which are always captured while the laser pointer mode is on.
    private var mouseMovedEnabled: Bool {
        let settings = settingsStore.settings
        return settings.showLaserPointer && settings.laserCursorVisible
    }

    func startIfEnabled() {
        guard settingsStore.settings.isEnabled else { return }
        eventTap.start(
            mouseMovedEnabled: mouseMovedEnabled,
            liveKeyboardShortcutsEnabled: settingsStore.settings.showLiveKeyboardShortcuts
        )
    }

    func refreshEnabledState() {
        if settingsStore.settings.isEnabled {
            eventTap.start(
                mouseMovedEnabled: mouseMovedEnabled,
                liveKeyboardShortcutsEnabled: settingsStore.settings.showLiveKeyboardShortcuts
            )
        } else {
            eventTap.stop()
        }
    }

    func stop() {
        eventTap.stop()
    }
}
