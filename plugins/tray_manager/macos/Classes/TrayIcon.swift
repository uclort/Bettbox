//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

import Cocoa

public class TrayIcon: NSView {
    static let inactiveColor = NSColor(srgbRed: 0.60, green: 0.60, blue: 0.60, alpha: 1)
    static let speedFontSize: CGFloat = 9.5
    private static let speedLineHeight: CGFloat = 10
    private static let speedPadding: CGFloat = 12
    private static let speedMinimumWidth: CGFloat = 66
    private static let speedDisplayThreshold = 1000.0
    private static let speedUnits = ["B/s", "K/s", "M/s", "G/s", "T/s"]
    private static let speedScales = [
        1.0,
        1024.0,
        1024.0 * 1024.0,
        1024.0 * 1024.0 * 1024.0,
        1024.0 * 1024.0 * 1024.0 * 1024.0,
    ]

    public var onTrayIconMouseDown:((Bool) -> Void)?
    public var onTrayIconMouseUp:((Bool) -> Void)?
    public var onTrayIconRightMouseDown:((Bool) -> Void)?
    public var onTrayIconRightMouseUp:((Bool) -> Void)?
    
    public private(set) var isOptionPressed = false

    var statusItem: NSStatusItem?
    private var sourceImage: NSImage?
    private var isActive = true
    private var lastSpeedTitle: String?
    private var lastSpeedActive: Bool?
    // BETTBOX-CUSTOM: 策略组标签（可与网速组合）。非 nil 时整块内容（图标 + 标签 +
    // 网速）绘制为一张按当前外观实时着色的图片，nil 时沿用原图标与网速标题。
    private var statusContent: StatusContent?

    struct StatusContent: Equatable {
        let label: String
        let labelBeforeSpeed: Bool
        let speedLines: [String]?
    }
    
    public init() {
        super.init(frame: NSRect.zero)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem?.button?.addSubview(self)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setImage(_ image: NSImage, _ imagePosition: String) {
        sourceImage = image
        if let button = statusItem?.button {
            updateImageAppearance(button)
            setImagePosition(imagePosition)
            syncClickTargetFrame(button)
        }
    }
    
    public func setImagePosition(_ imagePosition: String) {
        if let button = statusItem?.button {
            button.imagePosition = imagePosition == "right" ? NSControl.ImagePosition.imageRight : NSControl.ImagePosition.imageLeft
            syncClickTargetFrame(button)
        }
    }
    
    public func removeImage() {
        sourceImage = nil
        if let button = statusItem?.button {
            button.image = nil
            syncClickTargetFrame(button)
        }
    }
    
    public func setTitle(_ title: String) {
        exitStatusContent()
        if let button = statusItem?.button {
            button.title  = title
            syncClickTargetFrame(button)
        }
        lastSpeedTitle = nil
        lastSpeedActive = nil
    }

    public func setActive(_ active: Bool) {
        isActive = active
        if let button = statusItem?.button {
            updateImageAppearance(button)
        }
    }

    public func setSpeedTitle(
        upload: UInt64,
        download: UInt64,
        active: Bool
    ) {
        exitStatusContent()
        let uploadText = formatSpeed(upload)
        let downloadText = formatSpeed(download)
        let title = "  \(leftPad(uploadText, width: 6))\n  \(leftPad(downloadText, width: 6))"
        if lastSpeedTitle == title && lastSpeedActive == active {
            return
        }
        guard let statusItem, let button = statusItem.button else {
            return
        }

        let font = NSFont.monospacedSystemFont(
            ofSize: Self.speedFontSize,
            weight: .regular
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byClipping
        paragraphStyle.lineSpacing = 0
        paragraphStyle.lineHeightMultiple = 1
        paragraphStyle.minimumLineHeight = Self.speedLineHeight
        paragraphStyle.maximumLineHeight = Self.speedLineHeight
        paragraphStyle.paragraphSpacingBefore = 0

        let barHeight = button.bounds.height > 0
            ? button.bounds.height
            : NSStatusBar.system.thickness
        let glyphHeight = font.ascender - font.descender
        let freeSpace = Self.speedLineHeight * 2 - barHeight
        let baselineOffset = -(glyphHeight / 3) + freeSpace / 2
        let attributedTitle = NSMutableAttributedString(string: title)
        let fullRange = NSRange(
            location: 0,
            length: attributedTitle.length
        )
        attributedTitle.addAttributes(
            [
                .font: font,
                .paragraphStyle: paragraphStyle,
                .baselineOffset: baselineOffset,
            ],
            range: fullRange
        )
        attributedTitle.removeAttribute(
            .foregroundColor,
            range: fullRange
        )

        let textWidth = ceil(attributedTitle.size().width)
        let imageWidth = button.image?.size.width ?? 0
        statusItem.length = max(
            textWidth + imageWidth + Self.speedPadding,
            Self.speedMinimumWidth
        )
        button.title = ""
        button.attributedTitle = attributedTitle
        button.needsDisplay = true
        syncClickTargetFrame(button)
        lastSpeedTitle = title
        lastSpeedActive = active
    }

    public func clearSpeedTitle() {
        exitStatusContent()
        lastSpeedTitle = nil
        lastSpeedActive = nil
        statusItem?.length = NSStatusItem.variableLength
        if let button = statusItem?.button {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.needsDisplay = true
            syncClickTargetFrame(button)
        }
    }

    /// BETTBOX-CUSTOM: 图标旁显示策略组标签；[showSpeed] 为 false 时标签占用网速位置。
    public func setStatusTitle(
        label: String,
        labelBeforeSpeed: Bool,
        showSpeed: Bool,
        upload: UInt64,
        download: UInt64
    ) {
        let content = StatusContent(
            label: label,
            labelBeforeSpeed: labelBeforeSpeed,
            speedLines: showSpeed
                ? [
                    leftPad(formatSpeed(upload), width: 6),
                    leftPad(formatSpeed(download), width: 6),
                ]
                : nil
        )
        if statusContent == content {
            return
        }
        statusContent = content
        // 回到纯网速模式时必须重新绘制标题，不能命中旧缓存。
        lastSpeedTitle = nil
        lastSpeedActive = nil
        guard let statusItem, let button = statusItem.button else {
            return
        }
        statusItem.length = NSStatusItem.variableLength
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        updateImageAppearance(button)
        button.needsDisplay = true
        syncClickTargetFrame(button)
    }

    private func exitStatusContent() {
        guard statusContent != nil else {
            return
        }
        statusContent = nil
        if let button = statusItem?.button {
            updateImageAppearance(button)
            syncClickTargetFrame(button)
        }
    }

    static let statusGap: CGFloat = 4
    static let statusSpeedLineHeight: CGFloat = 10

    /// 组合图标、标签与两行网速。绘制回调在状态栏按钮绘制时执行，
    /// `labelColor` 随菜单栏明暗实时解析；未接管流量时图标为灰色。
    static func composeStatusImage(
        icon: NSImage?,
        iconActive: Bool,
        content: StatusContent,
        barHeight: CGFloat
    ) -> NSImage {
        let labelFont = NSFont.menuBarFont(ofSize: 0)
        let speedFont = NSFont.monospacedSystemFont(
            ofSize: speedFontSize,
            weight: .regular
        )
        let labelSize = (content.label as NSString).size(
            withAttributes: [.font: labelFont]
        )
        let speedLineSizes = (content.speedLines ?? []).map {
            ($0 as NSString).size(withAttributes: [.font: speedFont])
        }
        let speedWidth = ceil(speedLineSizes.map(\.width).max() ?? 0)
        let iconSize = icon?.size ?? .zero
        let labelWidth = ceil(labelSize.width)

        var segments: [(kind: Int, width: CGFloat)] = [(0, labelWidth)]
        if content.speedLines != nil {
            if content.labelBeforeSpeed {
                segments.append((1, speedWidth))
            } else {
                segments.insert((1, speedWidth), at: 0)
            }
        }
        var totalWidth = iconSize.width
        for segment in segments {
            totalWidth += (totalWidth > 0 ? statusGap : 0) + segment.width
        }
        totalWidth = ceil(totalWidth + 2)

        let image = NSImage(
            size: NSSize(width: totalWidth, height: barHeight),
            flipped: false
        ) { _ in
            let textColor = NSColor.labelColor
            var x: CGFloat = 0
            if let icon {
                let iconRect = NSRect(
                    x: 0,
                    y: floor((barHeight - iconSize.height) / 2),
                    width: iconSize.width,
                    height: iconSize.height
                )
                icon.draw(in: iconRect)
                (iconActive ? textColor : inactiveColor).set()
                iconRect.fill(using: .sourceAtop)
                x = iconSize.width
            }
            for segment in segments {
                if x > 0 {
                    x += statusGap
                }
                if segment.kind == 0 {
                    (content.label as NSString).draw(
                        at: NSPoint(
                            x: x,
                            y: (barHeight - labelSize.height) / 2
                        ),
                        withAttributes: [
                            .font: labelFont,
                            .foregroundColor: textColor,
                        ]
                    )
                } else if let lines = content.speedLines {
                    let blockBottom =
                        (barHeight - statusSpeedLineHeight * 2) / 2
                    for (index, line) in lines.enumerated() {
                        let size = speedLineSizes[index]
                        // 第一行（上传）在上，右对齐。
                        let lineBottom = blockBottom +
                            statusSpeedLineHeight * CGFloat(lines.count - 1 - index)
                        (line as NSString).draw(
                            at: NSPoint(
                                x: x + segment.width - size.width,
                                y: lineBottom +
                                    (statusSpeedLineHeight - size.height) / 2
                            ),
                            withAttributes: [
                                .font: speedFont,
                                .foregroundColor: textColor,
                            ]
                        )
                    }
                }
                x += segment.width
            }
            return true
        }
        image.cacheMode = .never
        image.isTemplate = false
        return image
    }

    private func formatSpeed(_ bytesPerSecond: UInt64) -> String {
        if bytesPerSecond < UInt64(Self.speedDisplayThreshold) {
            return "\(bytesPerSecond)B/s"
        }

        let bitIndex = Int(log2(Double(bytesPerSecond))) / 10
        var unitIndex = min(bitIndex, Self.speedUnits.count - 1)
        var value = Double(bytesPerSecond) / Self.speedScales[unitIndex]
        if value.rounded() >= Self.speedDisplayThreshold &&
            unitIndex < Self.speedUnits.count - 1 {
            unitIndex += 1
            value = Double(bytesPerSecond) / Self.speedScales[unitIndex]
        }

        let unit = Self.speedUnits[unitIndex]
        if value < 9.95 {
            let number = String(
                format: "%.1f",
                locale: Locale(identifier: "en_US_POSIX"),
                value
            )
            return "\(number)\(unit)"
        }
        return "\(Int(value.rounded()))\(unit)"
    }

    private func leftPad(_ value: String, width: Int) -> String {
        let padding = max(0, width - value.count)
        return String(repeating: " ", count: padding) + value
    }

    private func updateImageAppearance(_ button: NSStatusBarButton) {
        if let statusContent {
            button.appearsDisabled = false
            button.contentTintColor = nil
            button.image = Self.composeStatusImage(
                icon: sourceImage,
                iconActive: isActive,
                content: statusContent,
                barHeight: button.bounds.height > 0
                    ? button.bounds.height
                    : NSStatusBar.system.thickness
            )
            return
        }
        guard let sourceImage else {
            return
        }
        button.appearsDisabled = false
        button.contentTintColor = nil
        if isActive {
            sourceImage.isTemplate = true
            button.image = sourceImage
        } else {
            button.image = tintedImage(sourceImage, color: Self.inactiveColor)
        }
    }

    private func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.draw(
            in: NSRect(origin: .zero, size: image.size),
            from: .zero,
            operation: .destinationIn,
            fraction: 1
        )
        tintedImage.unlockFocus()
        tintedImage.isTemplate = false
        return tintedImage
    }

    private func syncClickTargetFrame(_ button: NSStatusBarButton) {
        self.frame = button.bounds
    }
    
    public func setToolTip(_ toolTip: String) {
        if let button = statusItem?.button {
            button.toolTip  = toolTip
        }
    }

    static func isOptionPressed(
        eventFlags: NSEvent.ModifierFlags,
        currentFlags: NSEvent.ModifierFlags
    ) -> Bool {
        eventFlags.contains(.option) || currentFlags.contains(.option)
    }

    private func isOptionPressed(for event: NSEvent) -> Bool {
        Self.isOptionPressed(
            eventFlags: event.modifierFlags,
            currentFlags: NSEvent.modifierFlags
        )
    }
    
    public override func mouseDown(with event: NSEvent) {
        statusItem?.button?.highlight(true)
        self.onTrayIconMouseDown!(isOptionPressed(for: event))
    }
    
    public override func mouseUp(with event: NSEvent) {
        statusItem?.button?.highlight(false)
        self.onTrayIconMouseUp!(isOptionPressed(for: event))
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        self.onTrayIconRightMouseDown!(isOptionPressed(for: event))
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        self.onTrayIconRightMouseUp!(isOptionPressed(for: event))
    }
}
