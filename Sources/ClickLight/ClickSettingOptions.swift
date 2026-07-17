import Foundation

struct ClickNumericPreset: Equatable {
    let titleEN: String
    let titleZH: String
    let value: Double

    /// Resolved at call time so language switches apply to rebuilt UI.
    var title: String { L10n.t(titleEN, titleZH) }
}

enum ClickSettingOptions {
    static let sizePresets: [ClickNumericPreset] = [
        .init(titleEN: "Small", titleZH: "小", value: 44),
        .init(titleEN: "Medium", titleZH: "中", value: 64),
        .init(titleEN: "Large", titleZH: "大", value: 88),
        .init(titleEN: "Huge", titleZH: "特大", value: 116)
    ]

    static let intensityPresets: [ClickNumericPreset] = [
        .init(titleEN: "Subtle", titleZH: "微弱", value: 0.28),
        .init(titleEN: "Normal", titleZH: "标准", value: 0.7),
        .init(titleEN: "Bright", titleZH: "明亮", value: 1.0),
        .init(titleEN: "Beacon", titleZH: "耀眼", value: 1.35)
    ]

    static let durationPresets: [ClickNumericPreset] = [
        .init(titleEN: "Snappy", titleZH: "短促", value: 0.28),
        .init(titleEN: "Normal", titleZH: "标准", value: 0.48),
        .init(titleEN: "Long", titleZH: "较长", value: 0.72),
        .init(titleEN: "Very Long", titleZH: "很长", value: 1.0)
    ]

    static func matchingPreset(
        for value: CGFloat,
        in options: [ClickNumericPreset],
        tolerance: Double = 0.01
    ) -> ClickNumericPreset? {
        options.first { abs(Double(value) - $0.value) < tolerance }
    }

    static func matchingPreset(
        for value: TimeInterval,
        in options: [ClickNumericPreset],
        tolerance: Double = 0.01
    ) -> ClickNumericPreset? {
        options.first { abs(value - $0.value) < tolerance }
    }
}
