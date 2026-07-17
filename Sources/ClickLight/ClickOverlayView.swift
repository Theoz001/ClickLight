import AppKit

final class ClickOverlayView: NSView {
    private var screenFrame: CGRect
    private var settings: ClickSettings
    private var pulses: [ClickPulse] = []
    private var laserCursor: LaserCursor?
    private var activeLaserStroke: LaserStroke?
    private var completedLaserStrokes: [LaserStroke] = []
    private var liveShortcutLabel: LiveShortcutLabel?
    private var displayLink: Timer?

    init(screenFrame: CGRect, settings: ClickSettings) {
        self.screenFrame = screenFrame
        self.settings = settings
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(settings: ClickSettings) {
        self.settings = settings
        if !settings.showLaserPointer {
            laserCursor = nil
            activeLaserStroke = nil
            completedLaserStrokes = []
            needsDisplay = true
        }
        if !settings.showLiveKeyboardShortcuts {
            liveShortcutLabel = nil
            needsDisplay = true
        }
    }

    func show(event: ClickEvent, settings: ClickSettings) {
        self.settings = settings

        let localPoint = CGPoint(
            x: event.location.x - screenFrame.minX,
            y: event.location.y - screenFrame.minY
        )

        if settings.showLaserPointer {
            switch event.kind {
            case .move:
                showLaserCursor(at: localPoint)
                return
            case .drag:
                appendLaserPoint(localPoint)
                return
            case .leftUp, .rightUp, .middleUp:
                completeLaserStroke()
            case .leftDown, .rightDown, .middleDown:
                break
            }
        }

        guard shouldShowPulse(for: event.kind) else { return }

        pulses.append(ClickPulse(
            kind: event.kind,
            point: localPoint,
            startTime: CACurrentMediaTime(),
            duration: duration(for: event.kind),
            baseSize: size(for: event.kind),
            intensity: settings.intensity,
            color: color(for: event.kind),
            style: settings.pulseStyle
        ))

        startDisplayLink()
        needsDisplay = true
    }

    func show(shortcut: KeyboardShortcutEvent, settings: ClickSettings) {
        self.settings = settings
        liveShortcutLabel = LiveShortcutLabel(
            text: shortcut.displayString,
            point: CGPoint(
                x: shortcut.location.x - screenFrame.minX,
                y: shortcut.location.y - screenFrame.minY
            ),
            startTime: CACurrentMediaTime()
        )
        startDisplayLink()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let now = CACurrentMediaTime()
        pulses = pulses.filter { !$0.isExpired(at: now) }
        completedLaserStrokes = completedLaserStrokes.filter { !$0.isExpired(at: now) }
        if liveShortcutLabel?.isExpired(at: now) == true {
            liveShortcutLabel = nil
        }

        drawLaser(at: now, in: context)
        for pulse in pulses {
            draw(pulse: pulse, at: now, in: context)
        }
        drawLiveShortcutLabel(at: now, in: context)

        if pulses.isEmpty &&
            laserCursor?.isExpired(at: now) != false &&
            activeLaserStroke == nil &&
            completedLaserStrokes.isEmpty &&
            liveShortcutLabel == nil {
            stopDisplayLink()
        }
    }

    private func showLaserCursor(at point: CGPoint) {
        laserCursor = LaserCursor(point: point, updatedAt: CACurrentMediaTime())
        startDisplayLink()
        needsDisplay = true
    }

    private func appendLaserPoint(_ point: CGPoint) {
        let now = CACurrentMediaTime()
        showLaserCursor(at: point)

        if activeLaserStroke == nil {
            activeLaserStroke = LaserStroke(points: [point], completedAt: nil)
        } else if activeLaserStroke?.shouldAppend(point) == true {
            activeLaserStroke?.points.append(point)
        }

        if activeLaserStroke?.points.count == 1 {
            activeLaserStroke?.points.append(point)
        }

        laserCursor = LaserCursor(point: point, updatedAt: now)
        startDisplayLink()
        needsDisplay = true
    }

    private func completeLaserStroke() {
        guard var stroke = activeLaserStroke else { return }
        stroke.completedAt = CACurrentMediaTime()
        completedLaserStrokes.append(stroke)
        activeLaserStroke = nil
        startDisplayLink()
        needsDisplay = true
    }

    private func drawLaser(at now: CFTimeInterval, in context: CGContext) {
        guard settings.showLaserPointer else { return }

        for stroke in completedLaserStrokes {
            drawLaserStroke(stroke, alpha: stroke.alpha(at: now), in: context)
        }

        if let activeLaserStroke {
            drawLaserStroke(activeLaserStroke, alpha: 0.95, in: context)
        }

        guard let laserCursor, !laserCursor.isExpired(at: now) else { return }
        let alpha = laserCursor.alpha(at: now)
        let laserColor = settings.laserColor
        let middleColor = settings.laserMiddleColor
        let innerColor = settings.laserInnerColor
        context.saveGState()
        context.setFillColor(laserColor.withAlphaComponent(alpha * 0.18).cgColor)
        context.fillEllipse(in: CGRect(x: laserCursor.point.x - 16, y: laserCursor.point.y - 16, width: 32, height: 32))
        context.setFillColor(laserColor.withAlphaComponent(alpha).cgColor)
        context.fillEllipse(in: CGRect(x: laserCursor.point.x - 8, y: laserCursor.point.y - 8, width: 16, height: 16))
        context.setFillColor(middleColor.withAlphaComponent(alpha).cgColor)
        context.fillEllipse(in: CGRect(x: laserCursor.point.x - 6.5, y: laserCursor.point.y - 6.5, width: 13, height: 13))
        context.setFillColor(innerColor.withAlphaComponent(alpha).cgColor)
        context.fillEllipse(in: CGRect(x: laserCursor.point.x - 5.5, y: laserCursor.point.y - 5.5, width: 11, height: 11))
        context.restoreGState()
    }

    private func drawLaserStroke(_ stroke: LaserStroke, alpha: CGFloat, in context: CGContext) {
        guard stroke.points.count >= 2, alpha > 0 else { return }
        let laserColor = settings.laserColor
        let middleColor = settings.laserMiddleColor
        let innerColor = settings.laserInnerColor
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let path = CGMutablePath()
        path.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }

        context.addPath(path)
        context.setStrokeColor(laserColor.withAlphaComponent(alpha * 0.2).cgColor)
        context.setLineWidth(14)
        context.strokePath()

        context.addPath(path)
        context.setStrokeColor(laserColor.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(6)
        context.strokePath()

        context.addPath(path)
        context.setStrokeColor(middleColor.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(4)
        context.strokePath()

        context.addPath(path)
        context.setStrokeColor(innerColor.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(2)
        context.strokePath()
        context.restoreGState()
    }

    private func drawLiveShortcutLabel(at now: CFTimeInterval, in context: CGContext) {
        guard settings.showLiveKeyboardShortcuts, let label = liveShortcutLabel else { return }

        let alpha = label.alpha(at: now)
        let style = settings.liveShortcutSize
        let font = NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let textSize = (label.text as NSString).size(withAttributes: attributes)
        let padding = style.padding
        let size = CGSize(width: textSize.width + padding.width * 2, height: textSize.height + padding.height * 2)
        let origin: CGPoint
        switch settings.liveShortcutPosition {
        case .nearPointer:
            let proposedOrigin = CGPoint(x: label.point.x + 18, y: label.point.y + 18)
            origin = CGPoint(
                x: min(max(10, proposedOrigin.x), bounds.width - size.width - 10),
                y: min(max(10, proposedOrigin.y), bounds.height - size.height - 10)
            )
        case .bottomCenter:
            origin = CGPoint(
                x: max(10, (bounds.width - size.width) / 2),
                y: 34
            )
        }
        let rect = CGRect(origin: origin, size: size)

        context.saveGState()
        context.setFillColor(NSColor(calibratedWhite: 0.06, alpha: 0.88 * alpha).cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: style.cornerRadius, cornerHeight: style.cornerRadius, transform: nil))
        context.fillPath()
        context.restoreGState()

        (label.text as NSString).draw(
            at: CGPoint(x: rect.minX + padding.width, y: rect.minY + padding.height),
            withAttributes: attributes
        )
    }

    private func draw(pulse: ClickPulse, at now: CFTimeInterval, in context: CGContext) {
        // The pulse style is a layer on top of click kinds. Drag trails and
        // laser strokes keep their own rendering regardless of style.
        guard pulse.style != .classic, pulse.kind != .drag, pulse.kind != .move else {
            drawClassic(pulse: pulse, at: now, in: context)
            return
        }
        drawStylized(pulse: pulse, at: now, in: context)
    }

    private func drawClassic(pulse: ClickPulse, at now: CFTimeInterval, in context: CGContext) {
        let progress = pulse.progress(at: now)
        let eased = 1 - pow(1 - progress, 3)
        let fade = 1 - eased
        let visualIntensity = max(0.15, min(1.35, pulse.intensity))
        let alpha = clamp(fade * (0.18 + visualIntensity * 0.78))
        let lineWidth = max(2.25, pulse.baseSize * (0.035 + visualIntensity * 0.045))

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch pulse.kind {
        case .leftDown:
            drawGlowIfNeeded(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.28 + 0.78 * eased),
                color: pulse.color,
                alpha: fade * visualIntensity
            )
            drawRing(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.18 + 0.62 * eased),
                lineWidth: lineWidth,
                color: pulse.color,
                alpha: alpha
            )
            drawDot(context: context, point: pulse.point, radius: pulse.baseSize * 0.085, color: pulse.color, alpha: alpha * 0.75)
        case .leftUp:
            let releaseRadius = pulse.baseSize * (0.76 - 0.42 * eased)
            let releaseAlpha = alpha * 0.55
            drawGlowIfNeeded(
                context: context,
                point: pulse.point,
                radius: releaseRadius * 1.25,
                color: pulse.color,
                alpha: fade * visualIntensity * 0.45
            )
            drawRing(
                context: context,
                point: pulse.point,
                radius: releaseRadius,
                lineWidth: lineWidth * 0.55,
                color: pulse.color,
                alpha: releaseAlpha
            )
            drawDot(context: context, point: pulse.point, radius: pulse.baseSize * 0.055, color: pulse.color, alpha: releaseAlpha * 0.6)
        case .rightDown:
            drawGlowIfNeeded(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.28 + 0.7 * eased),
                color: pulse.color,
                alpha: fade * visualIntensity
            )
            drawRing(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.18 + 0.54 * eased),
                lineWidth: lineWidth,
                color: pulse.color,
                alpha: alpha
            )
            drawCrosshair(context: context, point: pulse.point, size: pulse.baseSize * 0.28, color: pulse.color, alpha: alpha * 0.85)
        case .rightUp:
            let releaseRadius = pulse.baseSize * (0.68 - 0.36 * eased)
            let releaseAlpha = alpha * 0.5
            drawGlowIfNeeded(
                context: context,
                point: pulse.point,
                radius: releaseRadius * 1.22,
                color: pulse.color,
                alpha: fade * visualIntensity * 0.4
            )
            drawRing(
                context: context,
                point: pulse.point,
                radius: releaseRadius,
                lineWidth: lineWidth * 0.55,
                color: pulse.color,
                alpha: releaseAlpha
            )
            drawCrosshair(context: context, point: pulse.point, size: pulse.baseSize * (0.16 + 0.08 * fade), color: pulse.color, alpha: releaseAlpha * 0.7)
        case .middleDown:
            drawGlowIfNeeded(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.26 + 0.68 * eased),
                color: pulse.color,
                alpha: fade * visualIntensity
            )
            drawRing(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.16 + 0.52 * eased),
                lineWidth: lineWidth,
                color: pulse.color,
                alpha: alpha
            )
            drawDiamond(context: context, point: pulse.point, size: pulse.baseSize * 0.24, color: pulse.color, alpha: alpha * 0.86)
        case .middleUp:
            let releaseSize = pulse.baseSize * (0.32 - 0.12 * eased)
            let releaseAlpha = alpha * 0.5
            drawGlowIfNeeded(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.42 - 0.12 * eased),
                color: pulse.color,
                alpha: fade * visualIntensity * 0.38
            )
            drawDiamond(context: context, point: pulse.point, size: releaseSize, color: pulse.color, alpha: releaseAlpha * 0.82)
        case .drag:
            drawDot(
                context: context,
                point: pulse.point,
                radius: pulse.baseSize * (0.08 + 0.065 * visualIntensity),
                color: pulse.color,
                alpha: alpha * 0.78
            )
        case .move:
            break
        }

        context.restoreGState()
    }

    private func drawStylized(pulse: ClickPulse, at now: CFTimeInterval, in context: CGContext) {
        let progress = pulse.progress(at: now)
        let eased = 1 - pow(1 - progress, 3)
        let fade = 1 - eased
        let visualIntensity = max(0.15, min(1.35, pulse.intensity))
        let alpha = clamp(fade * (0.18 + visualIntensity * 0.82))

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch pulse.style {
        case .classic:
            break
        case .ripple:
            drawRipple(pulse: pulse, progress: progress, alpha: alpha, intensity: visualIntensity, in: context)
        case .particles:
            drawParticles(pulse: pulse, eased: eased, alpha: alpha, intensity: visualIntensity, in: context)
        case .shockwave:
            drawShockwave(pulse: pulse, progress: progress, alpha: alpha, intensity: visualIntensity, in: context)
        case .spark:
            drawSpark(pulse: pulse, progress: progress, eased: eased, alpha: alpha, intensity: visualIntensity, in: context)
        }

        context.restoreGState()
    }

    private func drawRipple(pulse: ClickPulse, progress: CGFloat, alpha: CGFloat, intensity: CGFloat, in context: CGContext) {
        let delays: [CGFloat] = [0, 0.18, 0.36]
        for (index, delay) in delays.enumerated() {
            let local = max(0, min(1, (progress - delay) / (1 - delay)))
            guard local > 0 else { continue }
            let localEased = 1 - pow(1 - local, 3)
            let localFade = 1 - localEased
            let radius = pulse.baseSize * (0.14 + 0.88 * localEased)
            if index == 0 {
                drawGlowIfNeeded(
                    context: context,
                    point: pulse.point,
                    radius: radius,
                    color: pulse.color,
                    alpha: localFade * intensity
                )
            }
            drawRing(
                context: context,
                point: pulse.point,
                radius: radius,
                lineWidth: max(1.75, pulse.baseSize * (0.05 - 0.011 * CGFloat(index))),
                color: pulse.color,
                alpha: clamp(alpha * localFade)
            )
        }
        let dotFade = 1 - min(1, progress * 2.2)
        drawDot(
            context: context,
            point: pulse.point,
            radius: pulse.baseSize * 0.075,
            color: pulse.color,
            alpha: clamp(alpha * dotFade * 0.8)
        )
    }

    private func drawParticles(pulse: ClickPulse, eased: CGFloat, alpha: CGFloat, intensity: CGFloat, in context: CGContext) {
        // Brief core flash before the dots take over.
        let flashFade = 1 - min(1, eased * 2.4)
        drawGlowIfNeeded(
            context: context,
            point: pulse.point,
            radius: pulse.baseSize * 0.34,
            color: pulse.color,
            alpha: flashFade * intensity * 0.9
        )
        drawDot(
            context: context,
            point: pulse.point,
            radius: pulse.baseSize * 0.08 * (1 - 0.4 * eased),
            color: pulse.color,
            alpha: clamp(alpha * flashFade)
        )

        for particle in pulse.particles {
            let distance = pulse.baseSize * particle.distance * eased
            let center = CGPoint(
                x: pulse.point.x + cos(particle.angle) * distance,
                y: pulse.point.y + sin(particle.angle) * distance
            )
            drawDot(
                context: context,
                point: center,
                radius: max(1.2, pulse.baseSize * 0.05 * particle.size * (1 - 0.55 * eased)),
                color: pulse.color,
                alpha: clamp(alpha * particle.alpha)
            )
        }
    }

    private func drawShockwave(pulse: ClickPulse, progress: CGFloat, alpha: CGFloat, intensity: CGFloat, in context: CGContext) {
        let easedFast = 1 - pow(1 - progress, 4)
        let fade = 1 - easedFast
        let radius = pulse.baseSize * (0.1 + 1.25 * easedFast)
        let lineWidth = max(1.5, pulse.baseSize * (0.02 + 0.22 * fade))

        // Screen-space flash at the click point during the first beat.
        let flashProgress = min(1, progress / 0.28)
        if flashProgress < 1 {
            let flashAlpha = clamp((1 - flashProgress) * (0.2 + intensity * 0.35))
            let flashRadius = pulse.baseSize * (0.42 - 0.12 * flashProgress)
            context.setFillColor(pulse.color.withAlphaComponent(flashAlpha).cgColor)
            context.fillEllipse(in: CGRect(
                x: pulse.point.x - flashRadius,
                y: pulse.point.y - flashRadius,
                width: flashRadius * 2,
                height: flashRadius * 2
            ))
        }

        drawGlowIfNeeded(
            context: context,
            point: pulse.point,
            radius: radius,
            color: pulse.color,
            alpha: fade * intensity
        )
        drawRing(
            context: context,
            point: pulse.point,
            radius: radius,
            lineWidth: lineWidth,
            color: pulse.color,
            alpha: clamp(alpha * (0.35 + 0.65 * fade))
        )
    }

    private func drawSpark(pulse: ClickPulse, progress: CGFloat, eased: CGFloat, alpha: CGFloat, intensity: CGFloat, in context: CGContext) {
        // Arms snap out fast, then dissolve while rotating slightly.
        let grow = min(1, progress / 0.22)
        let growEased = 1 - pow(1 - grow, 3)
        let shrink = 1 - 0.45 * eased
        let armLength = pulse.baseSize * (0.18 + 0.82 * growEased) * shrink
        let armWidth = max(1.5, armLength * 0.16)
        let rotation = eased * 0.55

        drawGlowIfNeeded(
            context: context,
            point: pulse.point,
            radius: pulse.baseSize * 0.3,
            color: pulse.color,
            alpha: (1 - eased) * intensity
        )

        context.saveGState()
        context.translateBy(x: pulse.point.x, y: pulse.point.y)
        context.rotate(by: rotation)
        context.setFillColor(pulse.color.withAlphaComponent(clamp(alpha)).cgColor)
        for arm in 0..<4 {
            context.saveGState()
            context.rotate(by: CGFloat(arm) * .pi / 2)
            context.move(to: CGPoint(x: 0, y: armLength * 0.12))
            context.addLine(to: CGPoint(x: armWidth / 2, y: armLength * 0.45))
            context.addLine(to: CGPoint(x: 0, y: armLength))
            context.addLine(to: CGPoint(x: -armWidth / 2, y: armLength * 0.45))
            context.closePath()
            context.fillPath()
            context.restoreGState()
        }
        context.restoreGState()

        drawDot(
            context: context,
            point: pulse.point,
            radius: pulse.baseSize * 0.07 * (1 - 0.5 * eased),
            color: pulse.color,
            alpha: clamp(alpha * 0.9)
        )
    }

    private func drawGlowIfNeeded(
        context: CGContext,
        point: CGPoint,
        radius: CGFloat,
        color: NSColor,
        alpha: CGFloat
    ) {
        guard settings.intensity >= 0.7 else { return }
        let glowAlpha = clamp(alpha * (settings.intensity >= 1.2 ? 0.18 : 0.08))
        context.setFillColor(color.withAlphaComponent(glowAlpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    private func drawRing(
        context: CGContext,
        point: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        color: NSColor,
        alpha: CGFloat
    ) {
        context.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    private func drawDot(context: CGContext, point: CGPoint, radius: CGFloat, color: NSColor, alpha: CGFloat) {
        context.setFillColor(color.withAlphaComponent(alpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    private func drawCrosshair(context: CGContext, point: CGPoint, size: CGFloat, color: NSColor, alpha: CGFloat) {
        context.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        context.setLineWidth(max(2, size * 0.12))
        context.move(to: CGPoint(x: point.x - size, y: point.y))
        context.addLine(to: CGPoint(x: point.x + size, y: point.y))
        context.move(to: CGPoint(x: point.x, y: point.y - size))
        context.addLine(to: CGPoint(x: point.x, y: point.y + size))
        context.strokePath()
    }

    private func drawDiamond(context: CGContext, point: CGPoint, size: CGFloat, color: NSColor, alpha: CGFloat) {
        context.setFillColor(color.withAlphaComponent(alpha).cgColor)
        context.move(to: CGPoint(x: point.x, y: point.y + size))
        context.addLine(to: CGPoint(x: point.x + size, y: point.y))
        context.addLine(to: CGPoint(x: point.x, y: point.y - size))
        context.addLine(to: CGPoint(x: point.x - size, y: point.y))
        context.closePath()
        context.fillPath()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(displayLinkDidTick), userInfo: nil, repeats: true)
        RunLoop.main.add(displayLink!, forMode: .common)
    }

    @objc private func displayLinkDidTick() {
        needsDisplay = true
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func color(for kind: ClickKind) -> NSColor {
        if settings.colorPreset == .custom {
            switch settings.customColorMode {
            case .all:
                return settings.customColor
            case .byClick:
                switch kind {
                case .leftDown, .leftUp:
                    return settings.customLeftColor
                case .rightDown, .rightUp:
                    return settings.customRightColor
                case .middleDown, .middleUp:
                    return settings.customMiddleColor
                case .drag:
                    return settings.customDragColor
                case .move:
                    return .clear
                }
            }
        }

        if let color = settings.colorPreset.color {
            return color
        }

        switch kind {
        case .leftDown:
            return NSColor(calibratedRed: 0.0, green: 0.74, blue: 1.0, alpha: 1)
        case .leftUp:
            return NSColor(calibratedRed: 0.4, green: 0.88, blue: 1.0, alpha: 1)
        case .rightDown, .rightUp:
            return NSColor(calibratedRed: 1.0, green: 0.46, blue: 0.19, alpha: 1)
        case .middleDown, .middleUp:
            return NSColor(calibratedRed: 0.27, green: 0.92, blue: 0.58, alpha: 1)
        case .drag:
            return NSColor(calibratedRed: 0.92, green: 0.84, blue: 0.22, alpha: 1)
        case .move:
            return .clear
        }
    }

    private func duration(for kind: ClickKind) -> TimeInterval {
        switch kind {
        case .drag:
            return min(0.38, settings.duration * 0.82)
        case .move:
            return 0
        case .leftUp, .rightUp, .middleUp:
            return settings.duration * 0.78
        case .leftDown, .rightDown, .middleDown:
            return settings.duration
        }
    }

    private func size(for kind: ClickKind) -> CGFloat {
        switch kind {
        case .drag:
            return settings.size * 0.6
        case .move:
            return 0
        case .leftUp, .rightUp, .middleUp:
            return settings.size * 0.82
        case .leftDown, .rightDown, .middleDown:
            return settings.size
        }
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
    }

    private func shouldShowPulse(for kind: ClickKind) -> Bool {
        switch kind {
        case .leftDown:
            return settings.showPress
        case .leftUp:
            return settings.showRelease
        case .rightDown:
            return settings.showRightClick
        case .rightUp:
            return settings.showRightClick && settings.showRelease
        case .middleDown:
            return settings.showMiddleClick
        case .middleUp:
            return settings.showMiddleClick && settings.showRelease
        case .drag:
            return settings.showDrag && !settings.showLaserPointer
        case .move:
            return false
        }
    }
}

private struct ClickPulse {
    let kind: ClickKind
    let point: CGPoint
    let startTime: CFTimeInterval
    let duration: TimeInterval
    let baseSize: CGFloat
    let intensity: CGFloat
    let color: NSColor
    let style: ClickPulseStyle
    let particles: [PulseParticle]

    init(
        kind: ClickKind,
        point: CGPoint,
        startTime: CFTimeInterval,
        duration: TimeInterval,
        baseSize: CGFloat,
        intensity: CGFloat,
        color: NSColor,
        style: ClickPulseStyle
    ) {
        self.kind = kind
        self.point = point
        self.startTime = startTime
        self.duration = duration
        self.baseSize = baseSize
        self.intensity = intensity
        self.color = color
        self.style = style
        let seed = UInt64(truncatingIfNeeded: Int64(startTime * 1_000_000))
            &+ UInt64(truncatingIfNeeded: Int64(point.x * 31 + point.y * 57))
        self.particles = PulseParticle.makeBurst(seed: seed, count: 13)
    }

    func progress(at time: CFTimeInterval) -> CGFloat {
        CGFloat(max(0, min(1, (time - startTime) / duration)))
    }

    func isExpired(at time: CFTimeInterval) -> Bool {
        progress(at: time) >= 1
    }
}

private struct PulseParticle {
    let angle: CGFloat
    let distance: CGFloat
    let size: CGFloat
    let alpha: CGFloat

    /// Deterministic pseudo-random burst generated once per pulse, so the
    /// particle pattern is stable across frames (no per-frame RNG).
    static func makeBurst(seed: UInt64, count: Int) -> [PulseParticle] {
        var state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        func nextUnit() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 32) & 0xFFFFFF) / CGFloat(0x1000000)
        }
        return (0..<count).map { index in
            let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi + (nextUnit() - 0.5) * 0.9
            return PulseParticle(
                angle: angle,
                distance: 0.55 + nextUnit() * 0.6,
                size: 0.6 + nextUnit() * 0.8,
                alpha: 0.55 + nextUnit() * 0.45
            )
        }
    }
}

private struct LaserCursor {
    static let fadeDuration: TimeInterval = 0.42

    let point: CGPoint
    let updatedAt: CFTimeInterval

    func alpha(at time: CFTimeInterval) -> CGFloat {
        let progress = CGFloat(max(0, min(1, (time - updatedAt) / Self.fadeDuration)))
        return 1 - progress
    }

    func isExpired(at time: CFTimeInterval) -> Bool {
        time - updatedAt >= Self.fadeDuration
    }
}

private struct LiveShortcutLabel {
    static let visibleDuration: TimeInterval = 0.72
    static let fadeDuration: TimeInterval = 0.28

    let text: String
    let point: CGPoint
    let startTime: CFTimeInterval

    func alpha(at time: CFTimeInterval) -> CGFloat {
        let elapsed = time - startTime
        guard elapsed > Self.visibleDuration else { return 1 }
        let fadeProgress = CGFloat((elapsed - Self.visibleDuration) / Self.fadeDuration)
        return max(0, min(1, 1 - fadeProgress))
    }

    func isExpired(at time: CFTimeInterval) -> Bool {
        time - startTime >= Self.visibleDuration + Self.fadeDuration
    }
}

private struct LaserStroke {
    static let fadeDuration: TimeInterval = 0.9

    var points: [CGPoint]
    var completedAt: CFTimeInterval?

    func shouldAppend(_ point: CGPoint) -> Bool {
        guard let last = points.last else { return true }
        return hypot(last.x - point.x, last.y - point.y) >= 2.5
    }

    func alpha(at time: CFTimeInterval) -> CGFloat {
        guard let completedAt else { return 1 }
        let progress = CGFloat(max(0, min(1, (time - completedAt) / Self.fadeDuration)))
        return 1 - progress
    }

    func isExpired(at time: CFTimeInterval) -> Bool {
        guard let completedAt else { return false }
        return time - completedAt >= Self.fadeDuration
    }
}
