import AppKit
import Combine

@MainActor
final class StatusController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settingsStore: SettingsStore
    private let profileStore: ClickProfileStore
    private let activityStore: ClickActivityStore
    private let permissions: PermissionController
    private let launchAtLogin: LaunchAtLoginManaging
    private let onCheckForUpdates: () -> Void
    private let updatesAreConfigured: () -> Bool
    private let onOpenSettings: (SettingsPane?) -> Void
    private let onQuit: () -> Void
    private let onMenuWillOpen: () -> Void
    private let onMenuDidClose: () -> Void
    private var activityObserver: AnyCancellable?

    init(
        settingsStore: SettingsStore,
        profileStore: ClickProfileStore,
        activityStore: ClickActivityStore,
        permissions: PermissionController,
        launchAtLogin: LaunchAtLoginManaging,
        onCheckForUpdates: @escaping () -> Void,
        updatesAreConfigured: @escaping () -> Bool,
        onOpenSettings: @escaping (SettingsPane?) -> Void,
        onQuit: @escaping () -> Void,
        onMenuWillOpen: @escaping () -> Void = {},
        onMenuDidClose: @escaping () -> Void = {}
    ) {
        self.settingsStore = settingsStore
        self.profileStore = profileStore
        self.activityStore = activityStore
        self.permissions = permissions
        self.launchAtLogin = launchAtLogin
        self.onCheckForUpdates = onCheckForUpdates
        self.updatesAreConfigured = updatesAreConfigured
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.onMenuWillOpen = onMenuWillOpen
        self.onMenuDidClose = onMenuDidClose
        super.init()
    }

    func start() {
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "ClickLight")
        statusItem.button?.toolTip = "ClickLight"
        applyStatusItemAppearance(settingsStore.settings)
        rebuildMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsStore.didChangeNotification,
            object: nil
        )
        activityObserver = activityStore.$days.sink { [weak self] _ in
            self?.applyStatusItemAppearance(self?.settingsStore.settings ?? .defaults)
        }
    }

    func refresh() {
        rebuildMenu()
    }

    func dismissMenu() {
        statusItem.menu?.cancelTrackingWithoutAnimation()
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            MainActor.assumeIsolated {
                self?.statusItem.menu?.cancelTrackingWithoutAnimation()
            }
        }
    }

    private func dismissMenu(from item: NSMenuItem) {
        item.menu?.cancelTrackingWithoutAnimation()
        dismissMenu()
    }

    @objc private func settingsDidChange() {
        // Update the menu bar button immediately; the dropdown menu itself is
        // rebuilt lazily in menuNeedsUpdate(_:) so it always shows fresh state
        // the next time it opens. NSStatusItem menus don't repaint reliably
        // while tracking, so live mid-tracking refresh isn't attempted.
        applyStatusItemAppearance(settingsStore.settings)
    }

    private func rebuildMenu() {
        let menu = statusItem.menu ?? NSMenu()
        rebuildMenuItems(in: menu)
        menu.delegate = self
        if statusItem.menu !== menu {
            statusItem.menu = menu
        }
    }

    private func rebuildMenuItems(in menu: NSMenu) {
        let settings = settingsStore.settings
        menu.removeAllItems()
        StatusMenuConfiguration.apply(to: menu)

        menu.addItem(toggleItem(
            title: L10n.t("Enabled", "启用"),
            isOn: settings.isEnabled,
            action: #selector(toggleEnabled(_:)),
            shortcut: settings.shortcutBinding(for: .toggleEnabled)
        ))
        menu.addItem(.separator())

        menu.addItem(toggleItem(
            title: L10n.t("Laser Pointer Mode", "激光指针模式"),
            isOn: settings.showLaserPointer,
            action: #selector(toggleLaserPointer(_:)),
            shortcut: settings.shortcutBinding(for: .toggleLaserPointer)
        ))
        menu.addItem(toggleItem(
            title: L10n.t("Show Live Keyboard Shortcuts", "显示实时键盘快捷键"),
            isOn: settings.showLiveKeyboardShortcuts,
            action: #selector(toggleLiveKeyboardShortcuts(_:)),
            shortcut: settings.shortcutBinding(for: .toggleLiveKeyboardShortcuts)
        ))
        menu.addItem(.separator())

        if settings.showEventControlsInMenu {
            menu.addItem(toggleItem(
                title: L10n.t("Show Press", "显示按下"),
                isOn: settings.showPress,
                action: #selector(togglePress(_:)),
                shortcut: settings.shortcutBinding(for: .toggleShowPress)
            ))
            menu.addItem(toggleItem(
                title: L10n.t("Show Release", "显示松开"),
                isOn: settings.showRelease,
                action: #selector(toggleRelease(_:)),
                shortcut: settings.shortcutBinding(for: .toggleShowRelease)
            ))
            menu.addItem(toggleItem(
                title: L10n.t("Show Right Click", "显示右键点击"),
                isOn: settings.showRightClick,
                action: #selector(toggleRightClick(_:)),
                shortcut: settings.shortcutBinding(for: .toggleShowRightClick)
            ))
            menu.addItem(toggleItem(
                title: L10n.t("Show Middle Click", "显示中键点击"),
                isOn: settings.showMiddleClick,
                action: #selector(toggleMiddleClick(_:)),
                shortcut: settings.shortcutBinding(for: .toggleShowMiddleClick)
            ))
            let showDragItem = toggleItem(
                title: L10n.t("Show Drag", "显示拖拽"),
                isOn: settings.showDrag,
                action: #selector(toggleDrag(_:)),
                shortcut: settings.shortcutBinding(for: .toggleShowDrag)
            )
            showDragItem.isEnabled = !settings.showLaserPointer
            menu.addItem(showDragItem)
            menu.addItem(.separator())
        }

        if settings.showStyleControlsInMenu {
            menu.addItem(submenu(
                title: L10n.t("Size", "大小"),
                options: ClickSettingOptions.sizePresets,
                selected: Double(settings.size),
                action: #selector(selectSize(_:))
            ))
            menu.addItem(submenu(
                title: L10n.t("Intensity", "强度"),
                options: ClickSettingOptions.intensityPresets,
                selected: Double(settings.intensity),
                action: #selector(selectIntensity(_:))
            ))
            menu.addItem(submenu(
                title: L10n.t("Duration", "时长"),
                options: ClickSettingOptions.durationPresets,
                selected: settings.duration,
                action: #selector(selectDuration(_:))
            ))
            menu.addItem(pulseStyleSubmenu(selected: settings.pulseStyle))
            menu.addItem(colorSubmenu(selected: settings.colorPreset))
            menu.addItem(.separator())
        }

        if settings.showProfilesInMenu {
            menu.addItem(profilesSubmenu(settings: settings))
            menu.addItem(.separator())
        }

        if settings.showMenuBarControlsInMenu {
            menu.addItem(toggleItem(
                title: L10n.t("Show Menu Bar Text", "显示菜单栏文字"),
                isOn: settings.showMenuBarText,
                action: #selector(toggleMenuBarText)
            ))
            menu.addItem(toggleItem(
                title: L10n.t("Show Click Count in Menu Bar", "在菜单栏显示点击次数"),
                isOn: settings.showMenuBarClickCount,
                action: #selector(toggleMenuBarClickCount)
            ))
            menu.addItem(.separator())
        }

        if settings.showLaunchAtLoginInMenu {
            menu.addItem(toggleItem(
                title: L10n.t("Launch at Login", "登录时启动"),
                isOn: launchAtLogin.isEnabled,
                action: #selector(toggleLaunchAtLogin)
            ))
            menu.addItem(.separator())
        }

        let openSettingsItem = NSMenuItem(title: L10n.t("Open Settings...", "打开设置…"), action: #selector(openSettings), keyEquivalent: ",")
        openSettingsItem.target = self
        menu.addItem(openSettingsItem)

        let permissionTitle = permissions.isAccessibilityTrusted
            ? L10n.t("Accessibility: Granted", "辅助功能：已授权")
            : L10n.t("Open Accessibility Settings...", "打开辅助功能设置…")
        let permissionItem = NSMenuItem(title: permissionTitle, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        permissionItem.isEnabled = true
        menu.addItem(permissionItem)
        if settings.showLiveKeyboardShortcuts {
            let inputTitle = permissions.isInputMonitoringTrusted
                ? L10n.t("Input Monitoring: Granted", "输入监控：已授权")
                : L10n.t("Open Input Monitoring Settings...", "打开输入监控设置…")
            let inputItem = NSMenuItem(title: inputTitle, action: #selector(openInputMonitoringSettings), keyEquivalent: "")
            inputItem.target = self
            inputItem.isEnabled = true
            menu.addItem(inputItem)
        }

        menu.addItem(.separator())
        let updatesConfigured = updatesAreConfigured()
        let updateItem = NSMenuItem(
            title: updatesConfigured
                ? L10n.t("Check for Updates...", "检查更新…")
                : L10n.t("Updates: Not Configured", "更新：未配置"),
            action: updatesConfigured ? #selector(checkForUpdates) : nil,
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = updatesConfigured
        menu.addItem(updateItem)

        let aboutItem = NSMenuItem(title: L10n.t("About ClickLight", "关于 ClickLight"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: L10n.t("Quit ClickLight", "退出 ClickLight"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func applyStatusItemAppearance(_ settings: ClickSettings) {
        guard let button = statusItem.button else { return }
        var titleParts: [String] = []
        if settings.showMenuBarText {
            titleParts.append("ClickLight")
        }
        if settings.showMenuBarClickCount {
            titleParts.append(compactCount(activityStore.today.totalClicks))
        }
        button.imagePosition = titleParts.isEmpty ? .imageOnly : .imageLeading
        button.title = titleParts.joined(separator: " ")
        // Subtle state cue: dim the status item while ClickLight is disabled
        // so a global-hotkey toggle has visible feedback.
        button.alphaValue = settings.isEnabled ? 1.0 : 0.45
    }

    private func compactCount(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    private func toggleItem(
        title: String,
        isOn: Bool,
        action: Selector,
        shortcut: HotKeyBinding? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        applyShortcut(shortcut, to: item)
        return item
    }

    private func applyShortcut(_ shortcut: HotKeyBinding?, to item: NSMenuItem) {
        item.attributedTitle = nil
        guard let shortcut, let keyEquivalent = shortcut.menuKeyEquivalent else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = shortcut.menuModifierFlags
    }

    private func submenu(
        title: String,
        options: [ClickNumericPreset],
        selected: Double,
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        let selectedPreset = options.first { abs($0.value - selected) < 0.01 }
        for option in options {
            let child = NSMenuItem(title: option.title, action: action, keyEquivalent: "")
            child.target = self
            child.representedObject = option.value
            child.state = selectedPreset?.value == option.value ? .on : .off
            menu.addItem(child)
        }
        if selectedPreset == nil {
            menu.addItem(NSMenuItem.separator())
            let custom = NSMenuItem(title: L10n.t("Custom", "自定义"), action: nil, keyEquivalent: "")
            custom.state = .on
            custom.isEnabled = false
            menu.addItem(custom)
        }
        item.submenu = menu
        return item
    }

    private func pulseStyleSubmenu(selected: ClickPulseStyle) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("Pulse Style", "脉冲样式"), action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for style in ClickPulseStyle.allCases {
            let child = NSMenuItem(title: style.title, action: #selector(selectPulseStyle(_:)), keyEquivalent: "")
            child.target = self
            child.representedObject = style.rawValue
            child.state = style == selected ? .on : .off
            menu.addItem(child)
        }
        item.submenu = menu
        return item
    }

    private func colorSubmenu(selected: ClickColorPreset) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("Colors", "颜色"), action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for preset in ClickColorPreset.allCases where preset != .custom {
            let child = NSMenuItem(title: preset.title, action: #selector(selectColor(_:)), keyEquivalent: "")
            child.target = self
            child.representedObject = preset.rawValue
            child.state = preset == selected ? .on : .off
            menu.addItem(child)
        }

        menu.addItem(NSMenuItem.separator())

        if selected == .custom {
            let selectedCustom = NSMenuItem(title: L10n.t("Custom (Configured in Settings)", "自定义（在设置中配置）"), action: nil, keyEquivalent: "")
            selectedCustom.state = .on
            selectedCustom.isEnabled = false
            menu.addItem(selectedCustom)
        }

        let configureCustom = NSMenuItem(title: L10n.t("Configure Custom Colors...", "配置自定义颜色…"), action: #selector(openVisualStyleSettings), keyEquivalent: "")
        configureCustom.target = self
        menu.addItem(configureCustom)

        item.submenu = menu
        return item
    }

    private func profilesSubmenu(settings: ClickSettings) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t("Profiles", "预设"), action: nil, keyEquivalent: "")
        let menu = NSMenu()
        let currentSettings = ClickProfileSettings(settings: settings)

        if profileStore.profiles.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.t("No Profiles Saved", "尚未保存预设"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for profile in profileStore.profiles {
                let child = NSMenuItem(title: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
                child.target = self
                child.representedObject = profile.id.uuidString
                child.state = profile.settings == currentSettings ? .on : .off
                child.isEnabled = profile.settings != currentSettings
                menu.addItem(child)
            }
        }

        menu.addItem(.separator())
        let manageItem = NSMenuItem(title: L10n.t("Manage Profiles...", "管理预设…"), action: #selector(openProfileSettings), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)

        item.submenu = menu
        return item
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.isEnabled.toggle() }
    }

    @objc private func openSettings() {
        onOpenSettings(nil)
    }

    @objc private func openProfileSettings() {
        onOpenSettings(.profiles)
    }

    @objc private func openVisualStyleSettings() {
        onOpenSettings(.style)
    }

    @objc private func togglePress(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showPress.toggle() }
    }

    @objc private func toggleRelease(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showRelease.toggle() }
    }

    @objc private func toggleRightClick(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showRightClick.toggle() }
    }

    @objc private func toggleMiddleClick(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showMiddleClick.toggle() }
    }

    @objc private func toggleDrag(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showDrag.toggle() }
    }

    @objc private func toggleLaserPointer(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showLaserPointer.toggle() }
    }

    @objc private func toggleLiveKeyboardShortcuts(_ sender: NSMenuItem) {
        dismissMenu(from: sender)
        settingsStore.update { $0.showLiveKeyboardShortcuts.toggle() }
    }

    @objc private func toggleMenuBarText() {
        settingsStore.update { $0.showMenuBarText.toggle() }
    }

    @objc private func toggleMenuBarClickCount() {
        settingsStore.update { $0.showMenuBarClickCount.toggle() }
    }

    @objc private func toggleLaunchAtLogin() {
        let enabled = LaunchAtLoginState.toggledValue(currentlyEnabled: launchAtLogin.isEnabled)
        do {
            try launchAtLogin.setEnabled(enabled)
        } catch {
            NSLog("ClickLight: Failed to update launch at login: \(error)")
        }
        rebuildMenu()
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        settingsStore.update { $0.size = CGFloat(value) }
    }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        settingsStore.update { $0.intensity = CGFloat(value) }
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        settingsStore.update { $0.duration = value }
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let preset = ClickColorPreset(rawValue: rawValue)
        else { return }
        settingsStore.update { $0.colorPreset = preset }
    }

    @objc private func selectPulseStyle(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let style = ClickPulseStyle(rawValue: rawValue)
        else { return }
        settingsStore.update { $0.pulseStyle = style }
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let profileID = UUID(uuidString: rawValue),
            let profile = profileStore.profiles.first(where: { $0.id == profileID })
        else { return }
        dismissMenu(from: sender)
        settingsStore.update { settings in
            profile.settings.apply(to: &settings)
        }
    }

    @objc private func openAccessibilitySettings() {
        permissions.requestAccessibilityIfNeeded()
        permissions.openPrivacySettings()
    }

    @objc private func openInputMonitoringSettings() {
        permissions.requestInputMonitoringIfNeeded()
        permissions.openInputMonitoringSettings()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(string: L10n.t("Source on GitHub", "在 GitHub 上查看源码"))
        credits.addAttributes(
            [
                .link: URL(string: "https://github.com/aurorascharff/ClickLight")!,
                .foregroundColor: NSColor.linkColor
            ],
            range: NSRange(location: 0, length: credits.length)
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        onQuit()
    }
}

extension StatusController: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            onMenuWillOpen()
        }
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            onMenuDidClose()
        }
    }

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            // Refresh the existing menu instance. Replacing statusItem.menu
            // while AppKit is opening it can fire menuDidClose for the old
            // menu and re-register global hotkeys before tracking actually
            // ends.
            guard let menu = statusItem.menu else { return }
            rebuildMenuItems(in: menu)
        }
    }
}
