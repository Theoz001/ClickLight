import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClickLightSettingsView: View {
    @ObservedObject var viewModel: ClickLightSettingsViewModel
    @ObservedObject var profileStore: ClickProfileStore
    @ObservedObject var activityStore: ClickActivityStore
    @State private var showResetConfirmation = false
    @State private var showShortcutResetConfirmation = false
    @State private var showActivityResetConfirmation = false
    @State private var profileName = ""
    @State private var profileStatusMessage: String?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(SettingsPane.allCases, id: \.self, selection: $viewModel.selectedPane) { pane in
                    Label {
                        Text(pane.title)
                            .font(.system(size: 13, weight: .medium))
                    } icon: {
                        Image(systemName: pane.icon)
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 2)
                    .tag(pane)
                }
                .listStyle(.sidebar)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.t("Preview Pad", "预览区"), systemImage: "cursorarrow.click.2")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ClickPreviewPad(settings: viewModel.settings)
                        .frame(height: 116)
                        .accessibilityLabel(L10n.t("Preview Pad", "预览区"))

                    Button {
                        viewModel.randomizeStyle()
                    } label: {
                        Label(L10n.t("Randomize", "随机"), systemImage: "die.face.5.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint(L10n.t("Choose random visual presets", "随机选择视觉预设"))
                }
                .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    paneHeader

                    Group {
                        switch viewModel.selectedPane {
                        case .general:
                            generalPane
                        case .style:
                            stylePane
                        case .shortcuts:
                            shortcutsPane
                        case .profiles:
                            profilesPane
                        case .events:
                            eventsPane
                        case .activity:
                            activityPane
                        case .menu:
                            MenuLayoutPane(viewModel: viewModel)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func customColorRow(title: String, subtitle: String, color: Binding<Color>) -> some View {
        ModernRow(title: title, subtitle: subtitle) {
            ColorPicker(
                "",
                selection: color,
                supportsOpacity: false
            )
            .labelsHidden()
            .accessibilityLabel(title)
        }
    }

    private func customClickColorBinding(_ target: CustomClickColorTarget) -> Binding<Color> {
        Binding(
            get: {
                switch target {
                case .left:
                    return Color(nsColor: viewModel.settings.customLeftColor)
                case .right:
                    return Color(nsColor: viewModel.settings.customRightColor)
                case .middle:
                    return Color(nsColor: viewModel.settings.customMiddleColor)
                case .drag:
                    return Color(nsColor: viewModel.settings.customDragColor)
                }
            },
            set: { viewModel.applyCustomColor(NSColor($0), to: target) }
        )
    }

    private func laserColorPicker(title: String, color: Binding<Color>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ColorPicker(
                title,
                selection: color,
                supportsOpacity: false
            )
            .labelsHidden()
            .accessibilityLabel(L10n.t("Laser Pointer ", "激光指针") + title + L10n.t(" Color", "颜色"))
        }
    }

    // MARK: - Pane Header

    private var paneHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.selectedPane.title)
                .font(.system(size: 22, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.selectedPane.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Panes

    private var generalPane: some View {
        VStack(spacing: 16) {
            SettingsCard {
                ModernRow(title: L10n.t("Enable ClickLight", "启用 ClickLight"),
                          subtitle: L10n.t("Show pulse highlights on every click.", "在每次点击时显示脉冲高亮。")) {
                    Toggle("", isOn: binding(\.isEnabled))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Enable ClickLight", "启用 ClickLight"))
                }
            }

            SettingsCard(title: L10n.t("Language", "语言"),
                         subtitle: L10n.t("Choose the display language for ClickLight.", "选择 ClickLight 的显示语言。")) {
                Picker(L10n.t("Language", "语言"), selection: binding(\.language)) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        Text(language.title).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .accessibilityLabel(L10n.t("Language", "语言"))
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    ModernRow(title: L10n.t("Launch at Login", "登录时启动"),
                              subtitle: L10n.t("Open ClickLight automatically after signing in.", "登录后自动打开 ClickLight。")) {
                        Toggle("", isOn: Binding(
                            get: { viewModel.launchAtLoginEnabled },
                            set: { viewModel.setLaunchAtLogin($0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Launch at Login", "登录时启动"))
                    }
                    if let message = viewModel.launchAtLoginErrorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            SettingsCard {
                VStack(spacing: 0) {
                    ModernRow(title: L10n.t("Show Menu Bar Text", "显示菜单栏文字"),
                              subtitle: L10n.t("Display the ClickLight name next to the menu bar icon.", "在菜单栏图标旁显示 ClickLight 名称。")) {
                        Toggle("", isOn: binding(\.showMenuBarText))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel(L10n.t("Show Menu Bar Text", "显示菜单栏文字"))
                    }
                    Divider().padding(.vertical, 6)
                    ModernRow(title: L10n.t("Show Click Count in Menu Bar", "在菜单栏显示点击次数"),
                              subtitle: L10n.t("Display today's click total beside the menu bar icon.", "在菜单栏图标旁显示今日点击总数。")) {
                        Toggle("", isOn: binding(\.showMenuBarClickCount))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel(L10n.t("Show Click Count in Menu Bar", "在菜单栏显示点击次数"))
                    }
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: viewModel.accessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(viewModel.accessibilityTrusted ? .green : .orange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.accessibilityTrusted
                                 ? L10n.t("Accessibility Granted", "已授予辅助功能权限")
                                 : L10n.t("Accessibility Required", "需要辅助功能权限"))
                                .font(.callout.weight(.medium))
                            Text(viewModel.accessibilityTrusted
                                 ? L10n.t("ClickLight can observe clicks across the system.", "ClickLight 可以观察全系统的点击。")
                                 : L10n.t("Grant Accessibility access so ClickLight can see your clicks.", "授予辅助功能权限，以便 ClickLight 检测你的点击。"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    HStack {
                        Spacer()
                        Button {
                            viewModel.openAccessibilitySettings()
                        } label: {
                            Label(viewModel.accessibilityTrusted
                                  ? L10n.t("Open Accessibility Settings", "打开辅助功能设置")
                                  : L10n.t("Grant Access…", "授予权限…"),
                                  systemImage: "arrow.up.right.square")
                        }
                        .controlSize(.regular)
                    }
                }
            }

            if viewModel.settings.showLiveKeyboardShortcuts {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.inputMonitoringTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(viewModel.inputMonitoringTrusted ? .green : .orange)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.inputMonitoringTrusted
                                     ? L10n.t("Input Monitoring Granted", "已授予输入监控权限")
                                     : L10n.t("Input Monitoring Required", "需要输入监控权限"))
                                    .font(.callout.weight(.medium))
                                Text(viewModel.inputMonitoringTrusted
                                     ? L10n.t("ClickLight can observe keyboard shortcuts across the system.", "ClickLight 可以观察全系统的键盘快捷键。")
                                     : L10n.t("Grant Input Monitoring access so ClickLight can show keyboard shortcuts.", "授予输入监控权限，以便 ClickLight 显示键盘快捷键。"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Spacer()
                            Button {
                                viewModel.openInputMonitoringSettings()
                            } label: {
                                Label(viewModel.inputMonitoringTrusted
                                      ? L10n.t("Open Input Monitoring Settings", "打开输入监控设置")
                                      : L10n.t("Grant Access...", "授予权限…"),
                                      systemImage: "arrow.up.right.square")
                            }
                            .controlSize(.regular)
                        }
                    }
                }
            }

            SettingsCard {
                ModernRow(title: L10n.t("Reset to Defaults", "恢复默认设置"),
                          subtitle: L10n.t("Restore size, intensity, duration, color, and toggles.", "还原大小、强度、时长、颜色和开关。")) {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label(L10n.t("Reset", "还原"), systemImage: "arrow.counterclockwise")
                    }
                    .controlSize(.regular)
                }
            }

        }
        .confirmationDialog(
            L10n.t("Reset all ClickLight settings?", "还原所有 ClickLight 设置？"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Reset", "还原"), role: .destructive) {
                viewModel.resetToDefaults()
            }
            Button(L10n.t("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L10n.t("This restores size, intensity, duration, color, and visibility toggles to their defaults.", "这会将大小、强度、时长、颜色和可见性开关还原为默认值。"))
        }
    }

    private var stylePane: some View {
        VStack(spacing: 16) {
            SettingsCard(title: L10n.t("Pulse Style", "脉冲样式"), subtitle: L10n.t("The effect drawn at each click. Try it in the Preview Pad.", "每次点击绘制的效果。可在预览区中试用。")) {
                Picker(L10n.t("Pulse Style", "脉冲样式"), selection: binding(\.pulseStyle)) {
                    ForEach(ClickPulseStyle.allCases, id: \.rawValue) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .accessibilityLabel(L10n.t("Pulse Style", "脉冲样式"))
            }

            SettingsCard(title: L10n.t("Size", "大小"), subtitle: L10n.t("How large the click pulse appears.", "点击脉冲的显示大小。")) {
                VStack(alignment: .leading, spacing: 16) {
                    presetSegmented(
                        label: L10n.t("Size Preset", "大小预设"),
                        selection: Binding(
                            get: { viewModel.sizePresetSelection },
                            set: { viewModel.applySizePresetSelection($0) }
                        ),
                        options: ClickSettingOptions.sizePresets
                    )

                    modernSlider(
                        label: L10n.t("Size", "大小"),
                        value: Binding(
                            get: { Double(viewModel.settings.size) },
                            set: { newValue in
                                viewModel.update { $0.size = CGFloat(newValue) }
                            }
                        ),
                        range: 16...240,
                        lower: "16",
                        upper: "240",
                        readout: "\(Int(viewModel.settings.size.rounded())) px"
                    )
                }
            }

            SettingsCard(title: L10n.t("Intensity", "强度"), subtitle: L10n.t("How bright the click pulse glows.", "点击脉冲的亮度。")) {
                VStack(alignment: .leading, spacing: 16) {
                    presetSegmented(
                        label: L10n.t("Intensity Preset", "强度预设"),
                        selection: Binding(
                            get: { viewModel.intensityPresetSelection },
                            set: { viewModel.applyIntensityPresetSelection($0) }
                        ),
                        options: ClickSettingOptions.intensityPresets
                    )

                    modernSlider(
                        label: L10n.t("Intensity", "强度"),
                        value: Binding(
                            get: { Double(viewModel.settings.intensity) },
                            set: { newValue in
                                viewModel.update { $0.intensity = CGFloat(newValue) }
                            }
                        ),
                        range: 0.05...2.0,
                        lower: L10n.t("Subtle", "微弱"),
                        upper: L10n.t("Beacon", "耀眼"),
                        readout: String(format: "%.2f", Double(viewModel.settings.intensity))
                    )
                }
            }

            SettingsCard(title: L10n.t("Duration", "时长"), subtitle: L10n.t("How long each pulse stays visible.", "每次脉冲持续显示的时间。")) {
                VStack(alignment: .leading, spacing: 16) {
                    presetSegmented(
                        label: L10n.t("Duration Preset", "时长预设"),
                        selection: Binding(
                            get: { viewModel.durationPresetSelection },
                            set: { viewModel.applyDurationPresetSelection($0) }
                        ),
                        options: ClickSettingOptions.durationPresets
                    )

                    modernSlider(
                        label: L10n.t("Duration", "时长"),
                        value: Binding(
                            get: { viewModel.settings.duration },
                            set: { newValue in
                                viewModel.update { $0.duration = newValue }
                            }
                        ),
                        range: 0.1...2.0,
                        lower: "0.10s",
                        upper: "2.00s",
                        readout: String(format: "%.2f s", viewModel.settings.duration)
                    )
                }
            }

            SettingsCard(title: L10n.t("Color", "颜色"), subtitle: L10n.t("Tint applied to every pulse.", "应用于每次脉冲的色彩。")) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ColorSwatch(color: resolvedColor)
                            .accessibilityHidden(true)
                        Picker(L10n.t("Color", "颜色"), selection: binding(\.colorPreset)) {
                            ForEach(ClickColorPreset.allCases, id: \.rawValue) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    if viewModel.settings.colorPreset == .custom {
                        Divider()

                        Picker(L10n.t("Custom Color Mode", "自定义颜色模式"), selection: binding(\.customColorMode)) {
                            ForEach(CustomClickColorMode.allCases, id: \.rawValue) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .accessibilityLabel(L10n.t("Custom Color Mode", "自定义颜色模式"))

                        if viewModel.settings.customColorMode == .all {
                            customColorRow(
                                title: L10n.t("Custom Color", "自定义颜色"),
                                subtitle: L10n.t("Use one custom color for every click.", "所有点击使用同一种自定义颜色。"),
                                color: Binding(
                                    get: { Color(nsColor: viewModel.settings.customColor) },
                                    set: { viewModel.applyCustomColor(NSColor($0)) }
                                )
                            )
                        } else {
                            VStack(spacing: 0) {
                                customColorRow(
                                    title: L10n.t("Left Click", "左键点击"),
                                    subtitle: L10n.t("Used for left press and release pulses.", "用于左键按下和松开的脉冲。"),
                                    color: customClickColorBinding(.left)
                                )
                                Divider().padding(.vertical, 6)
                                customColorRow(
                                    title: L10n.t("Right Click", "右键点击"),
                                    subtitle: L10n.t("Used for secondary-button pulses.", "用于次要键的脉冲。"),
                                    color: customClickColorBinding(.right)
                                )
                                Divider().padding(.vertical, 6)
                                customColorRow(
                                    title: L10n.t("Middle Click", "中键点击"),
                                    subtitle: L10n.t("Used for center-button pulses.", "用于中间键的脉冲。"),
                                    color: customClickColorBinding(.middle)
                                )
                                Divider().padding(.vertical, 6)
                                customColorRow(
                                    title: L10n.t("Drag", "拖拽"),
                                    subtitle: L10n.t("Used for the normal drag trail.", "用于普通拖拽轨迹。"),
                                    color: customClickColorBinding(.drag)
                                )
                            }
                        }
                    } else {
                        Divider()

                        ModernRow(title: L10n.t("Custom Color", "自定义颜色"),
                                  subtitle: L10n.t("Picking a color switches to Custom automatically.", "选取颜色后自动切换为自定义。")) {
                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { resolvedColor },
                                    set: { viewModel.applyCustomColor(NSColor($0)) }
                                ),
                                supportsOpacity: false
                            )
                            .labelsHidden()
                            .accessibilityLabel(L10n.t("Custom Color Picker", "自定义颜色选择器"))
                        }
                    }

                    Divider()

                    ModernRow(title: L10n.t("Laser Pointer Color", "激光指针颜色"),
                              subtitle: L10n.t("Outer ring and inner fill. The middle color is blended automatically.", "外圈与内圈填充。中间颜色自动混合。")) {
                        HStack(spacing: 12) {
                            laserColorPicker(
                                title: L10n.t("Outer", "外圈"),
                                color: Binding(
                                    get: { Color(nsColor: viewModel.settings.laserColor) },
                                    set: { viewModel.applyLaserColor(NSColor($0)) }
                                )
                            )
                            laserColorPicker(
                                title: L10n.t("Inner", "内圈"),
                                color: Binding(
                                    get: { Color(nsColor: viewModel.settings.laserInnerColor) },
                                    set: { viewModel.applyLaserInnerColor(NSColor($0)) }
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private var eventsPane: some View {
        SettingsCard {
            VStack(spacing: 0) {
                ModernRow(title: L10n.t("Laser Pointer Mode", "激光指针模式"),
                          subtitle: L10n.t("Show a fading pointer and draw temporary strokes while dragging.", "显示渐隐的指针，并在拖拽时绘制临时笔迹。")) {
                    Toggle("", isOn: binding(\.showLaserPointer))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Laser Pointer Mode", "激光指针模式"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(title: L10n.t("Laser Dot Follows Pointer", "激光点跟随指针"),
                          subtitle: L10n.t("Turn off to keep only drag strokes", "关闭后仅保留拖动划线")) {
                    Toggle("", isOn: binding(\.laserCursorVisible))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Laser Dot Follows Pointer", "激光点跟随指针"))
                        .disabled(!viewModel.settings.showLaserPointer)
                }
                Divider().padding(.vertical, 6)
                ModernRow(title: L10n.t("Show Live Keyboard Shortcuts", "显示实时键盘快捷键"),
                          subtitle: L10n.t("Display shortcut combinations while you use them.", "在使用快捷键时实时显示按键组合。")) {
                    Toggle("", isOn: binding(\.showLiveKeyboardShortcuts))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Live Keyboard Shortcuts", "显示实时键盘快捷键"))
                }
                if viewModel.settings.showLiveKeyboardShortcuts {
                    Divider().padding(.vertical, 6)
                    VStack(alignment: .leading, spacing: 14) {
                        shortcutDisplayPicker(
                            title: L10n.t("Position", "位置"),
                            selection: binding(\.liveShortcutPosition),
                            options: LiveShortcutPosition.allCases
                        )
                        shortcutDisplayPicker(
                            title: L10n.t("Size", "大小"),
                            selection: binding(\.liveShortcutSize),
                            options: LiveShortcutSize.allCases
                        )
                    }
                    .padding(.vertical, 6)
                }
                Divider().padding(.vertical, 6)
                ModernRow(title: L10n.t("Show Press", "显示按下"),
                          subtitle: L10n.t("Highlight when the mouse button goes down.", "鼠标按键按下时高亮。")) {
                    Toggle("", isOn: binding(\.showPress))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Press", "显示按下"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(title: L10n.t("Show Release", "显示松开"),
                          subtitle: L10n.t("Highlight when the mouse button releases.", "鼠标按键松开时高亮。")) {
                    Toggle("", isOn: binding(\.showRelease))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Release", "显示松开"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(title: L10n.t("Show Right Click", "显示右键点击"),
                          subtitle: L10n.t("Highlight secondary-button clicks.", "高亮次要键点击。")) {
                    Toggle("", isOn: binding(\.showRightClick))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Right Click", "显示右键点击"))
                }
                Divider().padding(.vertical, 6)
                    ModernRow(title: L10n.t("Show Middle Click", "显示中键点击"),
                          subtitle: L10n.t("Highlight center-button clicks.", "高亮中间键点击。")) {
                      Toggle("", isOn: binding(\.showMiddleClick))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Middle Click", "显示中键点击"))
                    }
                    Divider().padding(.vertical, 6)
                ModernRow(title: L10n.t("Show Drag", "显示拖拽"),
                          subtitle: viewModel.settings.showLaserPointer
                              ? L10n.t("Laser Pointer Mode replaces the normal drag trail.", "激光指针模式会替代普通拖拽轨迹。")
                              : L10n.t("Trail pointer movement while dragging.", "拖拽时显示指针轨迹。")) {
                    Toggle("", isOn: binding(\.showDrag))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Drag", "显示拖拽"))
                        .disabled(viewModel.settings.showLaserPointer)
                }
            }
        }
    }

    private var shortcutsPane: some View {
        VStack(spacing: 16) {
            if viewModel.hasHotKeyRegistrationIssues {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.t("Some shortcuts could not be registered globally.", "部分快捷键无法全局注册。"), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)

                        ForEach(viewModel.hotKeyRegistrationIssueSummary, id: \.self) { line in
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            SettingsCard(title: L10n.t("Global Shortcuts", "全局快捷键")) {
                VStack(spacing: 0) {
                    ForEach(Array(ClickShortcutAction.allCases.enumerated()), id: \.element) { index, action in
                        ShortcutRecorderField(
                            label: action.title,
                            currentBinding: viewModel.shortcutBinding(for: action),
                            defaultBinding: action.defaultBinding,
                            errorMessage: viewModel.shortcutError(for: action),
                            onRecord: { binding in
                                viewModel.updateShortcutBinding(binding, for: action)
                            },
                            onReset: {
                                viewModel.resetShortcutBinding(for: action)
                            },
                            onClear: {
                                viewModel.clearShortcutBinding(for: action)
                            }
                        )
                        .padding(.vertical, 4)

                        if index < ClickShortcutAction.allCases.count - 1 {
                            Divider().padding(.vertical, 4)
                        }
                    }
                }
            }

            SettingsCard {
                ModernRow(title: L10n.t("Reset All Shortcuts", "还原所有快捷键"),
                          subtitle: L10n.t("Restore the ClickLight toggle shortcut and disable optional shortcuts.", "恢复 ClickLight 开关快捷键并停用可选快捷键。")) {
                    Button(role: .destructive) {
                        showShortcutResetConfirmation = true
                    } label: {
                        Label(L10n.t("Reset", "还原"), systemImage: "arrow.counterclockwise")
                    }
                    .controlSize(.regular)
                }
            }

        }
        .confirmationDialog(
            L10n.t("Reset all keyboard shortcuts?", "还原所有键盘快捷键？"),
            isPresented: $showShortcutResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Reset", "还原"), role: .destructive) {
                viewModel.resetAllShortcutBindings()
            }
            Button(L10n.t("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L10n.t("This restores the ClickLight toggle shortcut and disables every optional shortcut.", "这会恢复 ClickLight 开关快捷键，并停用所有可选快捷键。"))
        }
    }

    private var profilesPane: some View {
        VStack(spacing: 16) {
            SettingsCard(
                title: L10n.t("Profiles", "预设"),
                subtitle: L10n.t("Save reusable visual setups. Profiles do not include hotkeys, launch at login, menu layout, or activity history.", "保存可复用的视觉配置。预设不包含快捷键、登录时启动、菜单布局或活动历史。")
            ) {
                VStack(spacing: 0) {
                    ModernRow(
                        title: L10n.t("Save Current Settings", "保存当前设置"),
                        subtitle: L10n.t("Use the current click, laser pointer, and shortcut-display settings.", "使用当前的点击、激光指针和快捷键显示设置。")
                    ) {
                        HStack(spacing: 8) {
                            TextField(L10n.t("Profile name", "预设名称"), text: $profileName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                            Button {
                                saveCurrentProfile()
                            } label: {
                                Label(L10n.t("Save", "保存"), systemImage: "square.and.arrow.down")
                            }
                            .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if !profileStore.profiles.isEmpty {
                        Divider().padding(.vertical, 6)
                    }

                    ForEach(profileStore.profiles) { profile in
                        ModernRow(
                            title: profile.name,
                            subtitle: L10n.t("Created ", "创建于 ") + profile.createdAt.formatted(date: .abbreviated, time: .shortened)
                        ) {
                            HStack(spacing: 8) {
                                Button {
                                    viewModel.applyProfile(profile)
                                } label: {
                                    Label(L10n.t("Apply", "应用"), systemImage: "checkmark.circle")
                                }
                                .disabled(isCurrentProfile(profile))
                                Button(role: .destructive) {
                                    profileStore.delete(profile)
                                    profileStatusMessage = L10n.t("Deleted ", "已删除 ") + profile.name + "."
                                } label: {
                                    Label(L10n.t("Delete", "删除"), systemImage: "trash")
                                }
                            }
                        }
                        if profile.id != profileStore.profiles.last?.id {
                            Divider().padding(.vertical, 6)
                        }
                    }

                    if profileStore.profiles.isEmpty {
                        Text(L10n.t("No profiles yet.", "还没有预设。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
            }

            SettingsCard(title: L10n.t("Import and Export", "导入与导出"), subtitle: L10n.t("Move profiles between Macs with a JSON file.", "通过 JSON 文件在 Mac 之间迁移预设。")) {
                ModernRow(title: L10n.t("Profiles File", "预设文件"),
                          subtitle: L10n.t("Exports all saved profiles, not activity or app-level settings.", "导出所有已保存的预设，不含活动或 App 级设置。")) {
                    HStack(spacing: 8) {
                        Button {
                            exportProfiles()
                        } label: {
                            Label(L10n.t("Export", "导出"), systemImage: "square.and.arrow.up")
                        }
                        .disabled(profileStore.profiles.isEmpty)

                        Button {
                            importProfiles()
                        } label: {
                            Label(L10n.t("Import", "导入"), systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }

            if let profileStatusMessage {
                Text(profileStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var activityPane: some View {
        VStack(spacing: 16) {
            SettingsCard(
                title: L10n.t("Daily Clicks", "每日点击"),
                subtitle: L10n.t("Your last seven days. Stored locally on this Mac.", "最近七天的数据，仅存储在这台 Mac 上。")
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(activityStore.today.totalClicks.formatted())
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(L10n.t("clicks today", "次点击（今天）"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                ClickActivityChart(days: activityStore.lastSevenDays, store: activityStore)
                    .frame(height: 190)
                    .padding(.top, 8)
            }

            SettingsCard(title: L10n.t("Today", "今天")) {
                HStack(spacing: 0) {
                    ActivityMetric(title: L10n.t("Left", "左键"), value: activityStore.today.primaryClicks)
                    Divider().frame(height: 44)
                    ActivityMetric(title: L10n.t("Right", "右键"), value: activityStore.today.secondaryClicks)
                    Divider().frame(height: 44)
                    ActivityMetric(title: L10n.t("Middle", "中键"), value: activityStore.today.middleClicks)
                    Divider().frame(height: 44)
                    ActivityMetric(title: L10n.t("Drags", "拖拽"), value: activityStore.today.drags)
                }
                .padding(.vertical, 6)
            }

            SettingsCard {
                ModernRow(
                    title: L10n.t("Reset Activity History", "还原活动历史"),
                    subtitle: L10n.t("Remove all click counts stored by ClickLight.", "删除 ClickLight 记录的所有点击次数。")
                ) {
                    Button(role: .destructive) {
                        showActivityResetConfirmation = true
                    } label: {
                        Label(L10n.t("Reset", "还原"), systemImage: "arrow.counterclockwise")
                    }
                    .controlSize(.regular)
                }
            }
        }
        .confirmationDialog(
            L10n.t("Reset click activity history?", "还原点击活动历史？"),
            isPresented: $showActivityResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Reset", "还原"), role: .destructive) {
                activityStore.reset()
            }
            Button(L10n.t("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L10n.t("This removes the daily click totals saved on this Mac.", "这会删除这台 Mac 上保存的每日点击总数。"))
        }
    }

    // MARK: - Helpers

    private var resolvedColor: Color {
        if viewModel.settings.colorPreset == .custom {
            return Color(nsColor: viewModel.settings.customColor)
        }
        if let color = viewModel.settings.colorPreset.color {
            return Color(nsColor: color)
        }
        return Color.accentColor
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ClickSettings, T>) -> Binding<T> {
        Binding(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { newValue in
                viewModel.update { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func saveCurrentProfile() {
        guard let profile = profileStore.saveProfile(named: profileName, from: viewModel.settings) else { return }
        profileName = ""
        profileStatusMessage = L10n.t("Saved ", "已保存 ") + profile.name + "."
    }

    private func isCurrentProfile(_ profile: ClickSettingsProfile) -> Bool {
        profile.settings == ClickProfileSettings(settings: viewModel.settings)
    }

    private func exportProfiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ClickLight Profiles.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try profileStore.exportProfiles(to: url)
            let count = profileStore.profiles.count
            profileStatusMessage = L10n.t(
                "Exported \(count) profile\(count == 1 ? "" : "s").",
                "已导出 \(count) 个预设。"
            )
        } catch {
            profileStatusMessage = L10n.t("Could not export profiles: ", "无法导出预设：") + error.localizedDescription
        }
    }

    private func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let count = try profileStore.importProfiles(from: url)
            profileStatusMessage = L10n.t(
                "Imported \(count) profile\(count == 1 ? "" : "s").",
                "已导入 \(count) 个预设。"
            )
        } catch {
            profileStatusMessage = L10n.t("Could not import profiles: ", "无法导入预设：") + error.localizedDescription
        }
    }

    @ViewBuilder
    private func shortcutDisplayPicker<Option: Hashable & Equatable>(
        title: String,
        selection: Binding<Option>,
        options: [Option]
    ) -> some View where Option: ShortcutDisplayOption {
        HStack(spacing: 16) {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(width: 62, alignment: .leading)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .accessibilityLabel(L10n.t("Live Shortcut ", "实时快捷键") + title)
        }
    }

    @ViewBuilder
    private func presetSegmented(
        label: String,
        selection: Binding<String>,
        options: [ClickNumericPreset]
    ) -> some View {
        Picker(label, selection: selection) {
            ForEach(options, id: \.value) { preset in
                Text(preset.title).tag(String(preset.value))
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func modernSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        lower: String,
        upper: String,
        readout: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(lower)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Slider(value: value, in: range)
                    .accessibilityLabel(label)
                    .accessibilityValue(readout)
                Text(upper)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            HStack {
                Spacer()
                Text(readout)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.12))
                    )
                    .accessibilityHidden(true)
            }
        }
    }

}

private struct MenuLayoutPane: View {
    @ObservedObject var viewModel: ClickLightSettingsViewModel

    init(viewModel: ClickLightSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        SettingsCard(title: L10n.t("Menu Sections", "菜单分区"), subtitle: L10n.t("Keep essential controls visible and hide optional menu sections you do not use.", "保留常用控制项，隐藏不使用的可选菜单分区。")) {
            VStack(spacing: 0) {
                ModernRow(
                    title: L10n.t("Show Event Controls", "显示事件控制"),
                    subtitle: L10n.t("Show Press, Release, Right Click, Middle Click, and Drag in the menu.", "在菜单中显示按下、松开、右键点击、中键点击和拖拽。")
                ) {
                    Toggle("", isOn: binding(\.showEventControlsInMenu))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Event Controls", "显示事件控制"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(
                    title: L10n.t("Show Style Presets", "显示样式预设"),
                    subtitle: L10n.t("Show Size, Intensity, Duration, and Colors in the menu.", "在菜单中显示大小、强度、时长和颜色。")
                ) {
                    Toggle("", isOn: binding(\.showStyleControlsInMenu))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Style Presets", "显示样式预设"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(
                    title: L10n.t("Show Profiles", "显示预设"),
                    subtitle: L10n.t("Show saved profiles as a quick switcher in the menu.", "在菜单中显示已保存的预设以便快速切换。")
                ) {
                    Toggle("", isOn: binding(\.showProfilesInMenu))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Profiles", "显示预设"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(
                    title: L10n.t("Show Menu Bar Controls", "显示菜单栏控制"),
                    subtitle: L10n.t("Show menu bar text and click count controls in the menu.", "在菜单中显示菜单栏文字和点击次数控制。")
                ) {
                    Toggle("", isOn: binding(\.showMenuBarControlsInMenu))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Menu Bar Controls", "显示菜单栏控制"))
                }
                Divider().padding(.vertical, 6)
                ModernRow(
                    title: L10n.t("Show Launch at Login", "显示登录时启动"),
                    subtitle: L10n.t("Show Launch at Login in the menu.", "在菜单中显示登录时启动。")
                ) {
                    Toggle("", isOn: binding(\.showLaunchAtLoginInMenu))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(L10n.t("Show Launch at Login", "显示登录时启动"))
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ClickSettings, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.settings[keyPath: keyPath] },
            set: { newValue in
                viewModel.update { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}

private protocol ShortcutDisplayOption {
    var title: String { get }
}

extension LiveShortcutPosition: ShortcutDisplayOption {}
extension LiveShortcutSize: ShortcutDisplayOption {}

// MARK: - Reusable Components

private struct SettingsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ModernRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.vertical, 6)
    }
}

private struct ColorSwatch: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(width: 28, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            )
    }
}

private struct ClickActivityChart: View {
    let days: [ClickActivityDay]
    @ObservedObject var store: ClickActivityStore

    private var maximum: Int {
        max(1, days.map(\.totalClicks).max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.totalClicks.formatted())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    GeometryReader { geometry in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.accentColor)
                                .frame(
                                    height: max(
                                        day.totalClicks == 0 ? 2 : 6,
                                        geometry.size.height * CGFloat(day.totalClicks) / CGFloat(maximum)
                                    )
                                )
                        }
                    }

                    Text(store.label(for: day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.accessibilityLabel(for: day))
            }
        }
    }
}

private struct ActivityMetric: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value.formatted())
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct ClickPreviewPad: NSViewRepresentable {
    let settings: ClickSettings

    func makeNSView(context: Context) -> InteractiveClickPreviewView {
        InteractiveClickPreviewView(settings: settings)
    }

    func updateNSView(_ nsView: InteractiveClickPreviewView, context: Context) {
        nsView.apply(settings: settings)
    }
}

@MainActor
private final class InteractiveClickPreviewView: NSView {
    private let overlayView: ClickOverlayView
    private var settings: ClickSettings

    init(settings: ClickSettings) {
        self.settings = settings
        self.overlayView = ClickOverlayView(
            screenFrame: CGRect(x: 0, y: 0, width: 200, height: 116),
            settings: settings
        )
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor

        overlayView.autoresizingMask = [.width, .height]
        addSubview(overlayView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        overlayView.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    func apply(settings: ClickSettings) {
        self.settings = settings
        overlayView.apply(settings: settings)
    }

    override func mouseDown(with event: NSEvent) {
        show(.leftDown, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        show(.leftUp, event: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        show(.rightDown, event: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        show(.rightUp, event: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return }
        show(.middleDown, event: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return }
        show(.middleUp, event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        show(.drag, event: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        show(.drag, event: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return }
        show(.drag, event: event)
    }

    private func show(_ kind: ClickKind, event: NSEvent) {
        guard settings.isEnabled else { return }
        let location = convert(event.locationInWindow, from: nil)
        let clickEvent = ClickEvent(
            kind: kind,
            location: location,
            timestamp: CACurrentMediaTime()
        )
        // Preview clicks only render the overlay; they are not real user
        // activity and must not be counted in the daily stats.
        overlayView.show(event: clickEvent, settings: settings)
    }
}

enum SettingsPane: String, CaseIterable, Hashable {
    case general
    case events
    case style
    case shortcuts
    case profiles
    case activity
    case menu

    var title: String {
        switch self {
        case .general:
            return L10n.t("General", "通用")
        case .style:
            return L10n.t("Visual Style", "视觉效果")
        case .shortcuts:
            return L10n.t("Keyboard Shortcuts", "键盘快捷键")
        case .profiles:
            return L10n.t("Profiles", "预设")
        case .events:
            return L10n.t("Event Visibility", "事件可见性")
        case .activity:
            return L10n.t("Activity", "活动")
        case .menu:
            return L10n.t("Menu Layout", "菜单布局")
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return L10n.t("Enable ClickLight, set startup behavior, and manage permissions.", "启用 ClickLight、设置启动行为并管理权限。")
        case .style:
            return L10n.t("Size, intensity, duration, and color of click pulses.", "点击脉冲的大小、强度、时长与颜色。")
        case .shortcuts:
            return L10n.t("Set global shortcuts.", "设置全局快捷键。")
        case .profiles:
            return L10n.t("Save and move reusable visual setups.", "保存和迁移可复用的视觉配置。")
        case .events:
            return L10n.t("Choose which interactions and shortcut overlays appear.", "选择要显示哪些交互与快捷键浮层。")
        case .activity:
            return L10n.t("A local daily view of your clicking.", "本地记录的每日点击概览。")
        case .menu:
            return L10n.t("Choose which items appear in the status bar menu and their order.", "选择状态栏菜单中显示哪些项目及其顺序。")
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .style:
            return "paintpalette"
        case .shortcuts:
            return "keyboard"
        case .profiles:
            return "rectangle.stack"
        case .events:
            return "cursorarrow.click.2"
        case .activity:
            return "chart.bar.xaxis"
        case .menu:
            return "menubar.rectangle"
        }
    }
}
