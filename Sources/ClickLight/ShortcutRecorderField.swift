import AppKit
import Carbon.HIToolbox
import SwiftUI

extension Notification.Name {
    static let shortcutRecordingDidBegin = Notification.Name("ClickLightShortcutRecordingDidBegin")
    static let shortcutRecordingDidEnd = Notification.Name("ClickLightShortcutRecordingDidEnd")
}

struct ShortcutRecorderField: View {
    let label: String
    let currentBinding: HotKeyBinding?
    let defaultBinding: HotKeyBinding?
    let errorMessage: String?
    let onRecord: (HotKeyBinding) -> Bool
    let onReset: () -> Void
    let onClear: () -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var isCustom: Bool {
        currentBinding != defaultBinding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isRecording {
                    Text(L10n.t("Press shortcut...", "请按下快捷键…"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 112, alignment: .trailing)
                        .accessibilityLabel(L10n.t("Waiting for shortcut input", "等待快捷键输入"))

                    Button(L10n.t("Cancel", "取消")) {
                        stopRecording()
                    }
                    .buttonStyle(.bordered)
                    .help(L10n.t("Cancel shortcut recording.", "取消快捷键录制。"))
                } else {
                    Text(currentBinding?.displayString ?? L10n.t("None", "无"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(currentBinding == nil ? .secondary : .primary)
                        .frame(width: 112, alignment: .trailing)
                        .lineLimit(1)
                        .accessibilityLabel(currentBinding.map { L10n.t("Current shortcut: ", "当前快捷键：") + $0.descriptiveString } ?? L10n.t("No shortcut assigned", "未指定快捷键"))
                        .help(currentBinding?.descriptiveString ?? L10n.t("No shortcut configured.", "未配置快捷键。"))

                    Button(L10n.t("Record", "录制")) {
                        startRecording()
                    }
                    .buttonStyle(.bordered)
                    .help(L10n.t("Record a new shortcut.", "录制新快捷键。"))

                    if currentBinding != nil {
                        Button(L10n.t("Clear", "清除")) {
                            onClear()
                        }
                        .buttonStyle(.bordered)
                        .help(L10n.t("Remove this shortcut.", "移除此快捷键。"))
                    }

                    if isCustom, defaultBinding != nil {
                        Button(L10n.t("Reset", "还原")) {
                            onReset()
                        }
                        .buttonStyle(.bordered)
                        .help(L10n.t("Reset this shortcut to default.", "将此快捷键还原为默认。"))
                    }
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(errorMessage)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        NotificationCenter.default.post(name: .shortcutRecordingDidBegin, object: nil)

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let code = Int(event.keyCode)

            if code == kVK_Escape {
                stopRecording()
                return nil
            }

            let modifierOnlyCodes: Set<Int> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierOnlyCodes.contains(code) else {
                return event
            }

            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !flags.isEmpty else {
                NSSound.beep()
                stopRecording()
                return nil
            }

            let accepted = onRecord(HotKeyBinding(
                keyCode: code,
                carbonModifiers: HotKeyBinding.carbonModifiers(from: flags)
            ))
            if !accepted {
                NSSound.beep()
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording || eventMonitor != nil else { return }
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        NotificationCenter.default.post(name: .shortcutRecordingDidEnd, object: nil)
    }
}
