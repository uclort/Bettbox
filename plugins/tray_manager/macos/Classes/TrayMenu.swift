//
//  TrayMenu.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/8.
//

import AppKit

private final class PersistentTrayMenuItemView: NSView {
    private let highlightView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var isDisabled = false
    private var isHovered = false
    private var isPressed = false
    var onClick: (() -> Void)?

    init(label: String, disabled: Bool, width: CGFloat) {
        let font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: width,
                height: 28
            )
        )
        autoresizingMask = [.width]

        highlightView.material = .selection
        highlightView.blendingMode = .withinWindow
        highlightView.state = .active
        highlightView.isEmphasized = true
        highlightView.isHidden = true
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 7
        highlightView.layer?.masksToBounds = true
        highlightView.frame = bounds.insetBy(dx: 4, dy: 2)
        highlightView.autoresizingMask = [.width, .height]
        addSubview(highlightView)

        titleLabel.font = font
        titleLabel.alignment = .left
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = bounds.insetBy(dx: 14, dy: 5)
        titleLabel.autoresizingMask = [.width, .height]
        addSubview(titleLabel)

        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited,
                    .activeAlways,
                    .inVisibleRect,
                    .enabledDuringMouseDrag,
                ],
                owner: self,
                userInfo: nil
            )
        )
        update(label: label, disabled: disabled)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func update(label: String, disabled: Bool) {
        isDisabled = disabled
        if disabled {
            isPressed = false
        }
        titleLabel.stringValue = label
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        guard !isDisabled, contains(event) else {
            return
        }
        isPressed = true
        isHovered = true
        updateAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPressed else {
            return
        }
        isHovered = contains(event)
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        guard isPressed else {
            return
        }
        let shouldTrigger = !isDisabled && contains(event)
        isPressed = false
        isHovered = contains(event)
        updateAppearance()
        if shouldTrigger {
            onClick?()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isHighlighted = !isDisabled && isHovered
        highlightView.isHidden = !isHighlighted
        let textColor: NSColor
        if isDisabled {
            textColor = .disabledControlTextColor
        } else if isHighlighted {
            textColor = .selectedMenuItemTextColor
        } else {
            textColor = .controlTextColor
        }
        titleLabel.attributedStringValue = NSAttributedString(
            string: titleLabel.stringValue,
            attributes: [
                .font: titleLabel.font
                    ?? NSFont.menuFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: textColor,
            ]
        )
    }

    private func contains(_ event: NSEvent) -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        let rectInWindow = convert(bounds, to: nil)
        guard let screenRect = window?.convertToScreen(rectInWindow) else {
            return false
        }
        return screenRect.contains(mouseLocation)
    }
}

private final class AlignedTrayMenuItemView: NSView {
    private let highlightView = NSVisualEffectView()
    private let checkmarkLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private var isDisabled = false
    private var isHovered = false
    private var isPressed = false
    var onClick: (() -> Void)?

    init(
        label: String,
        detail: String,
        checked: Bool,
        disabled: Bool,
        width: CGFloat
    ) {
        let font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 24))
        autoresizingMask = [.width]

        highlightView.material = .selection
        highlightView.blendingMode = .withinWindow
        highlightView.state = .active
        highlightView.isEmphasized = true
        highlightView.isHidden = true
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 6
        highlightView.layer?.masksToBounds = true
        addSubview(highlightView)

        for textLabel in [checkmarkLabel, titleLabel, detailLabel] {
            textLabel.font = font
            textLabel.lineBreakMode = .byTruncatingTail
            addSubview(textLabel)
        }
        checkmarkLabel.alignment = .center
        titleLabel.alignment = .left
        detailLabel.alignment = .right

        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited,
                    .activeAlways,
                    .inVisibleRect,
                    .enabledDuringMouseDrag,
                ],
                owner: self,
                userInfo: nil
            )
        )
        update(
            label: label,
            detail: detail,
            checked: checked,
            disabled: disabled
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        highlightView.frame = bounds.insetBy(dx: 4, dy: 1)

        let verticalInset: CGFloat = 3
        let contentHeight = max(0, bounds.height - verticalInset * 2)
        checkmarkLabel.frame = NSRect(
            x: 8,
            y: verticalInset,
            width: 16,
            height: contentHeight
        )
        // BETTBOX-CUSTOM: 右侧说明按本行实际宽度右对齐，不再使用固定宽列。
        let titleX = TrayMenuMetrics.titleX
        let detailRight = bounds.width - TrayMenuMetrics.trailingInset
        let detailWidth = TrayMenuMetrics.detailWidth(
            detail: detailLabel.stringValue,
            label: titleLabel.stringValue,
            available: detailRight - titleX
        )
        let detailX = detailRight - detailWidth
        titleLabel.frame = NSRect(
            x: titleX,
            y: verticalInset,
            width: max(0, detailX - titleX - TrayMenuMetrics.columnGap),
            height: contentHeight
        )
        detailLabel.frame = NSRect(
            x: detailX,
            y: verticalInset,
            width: detailWidth,
            height: contentHeight
        )
    }

    func update(
        label: String,
        detail: String,
        checked: Bool,
        disabled: Bool
    ) {
        isDisabled = disabled
        if disabled {
            isPressed = false
        }
        checkmarkLabel.stringValue = checked ? "✓" : ""
        titleLabel.stringValue = label
        detailLabel.stringValue = detail
        needsLayout = true
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        guard !isDisabled, contains(event) else {
            return
        }
        isPressed = true
        isHovered = true
        updateAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPressed else {
            return
        }
        isHovered = contains(event)
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        guard isPressed else {
            return
        }
        let shouldTrigger = !isDisabled && contains(event)
        isPressed = false
        isHovered = contains(event)
        updateAppearance()
        if shouldTrigger {
            onClick?()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isHighlighted = !isDisabled && isHovered
        highlightView.isHidden = !isHighlighted
        // BETTBOX-CUSTOM: 不可手动选择的节点（Fallback 等）名称与右侧延迟同为次级灰色。
        let textColor: NSColor
        if isDisabled {
            textColor = .secondaryLabelColor
        } else if isHighlighted {
            textColor = .selectedMenuItemTextColor
        } else {
            textColor = .controlTextColor
        }
        // BETTBOX-CUSTOM: 右侧说明使用次级灰色；富文本必须带段落对齐，
        // 否则会覆盖 NSTextField.alignment 变成左对齐。
        let detailColor: NSColor
        if isDisabled {
            detailColor = .secondaryLabelColor
        } else if isHighlighted {
            detailColor = NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8)
        } else {
            detailColor = .secondaryLabelColor
        }
        let labels: [(NSTextField, NSColor, NSTextAlignment)] = [
            (checkmarkLabel, textColor, .center),
            (titleLabel, textColor, .left),
            (detailLabel, detailColor, .right),
        ]
        for (textLabel, color, alignment) in labels {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineBreakMode = .byTruncatingTail
            textLabel.attributedStringValue = NSAttributedString(
                string: textLabel.stringValue,
                attributes: [
                    .font: textLabel.font
                        ?? NSFont.menuFont(ofSize: NSFont.systemFontSize),
                    .foregroundColor: color,
                    .paragraphStyle: paragraph,
                ]
            )
        }
    }

    private func contains(_ event: NSEvent) -> Bool {
        guard event.window === window else {
            return false
        }
        return bounds.contains(convert(event.locationInWindow, from: nil))
    }
}

// BETTBOX-CUSTOM: 托盘自绘行统一尺寸：左侧名称，右侧灰色说明紧贴箭头或右边缘。
enum TrayMenuMetrics {
    static let titleX: CGFloat = 30
    static let trailingInset: CGFloat = 14
    static let columnGap: CGFloat = 28
    static let chevronWidth: CGFloat = 8
    static let chevronGap: CGFloat = 6
    static let rowHeight: CGFloat = 24

    static var font: NSFont { NSFont.menuFont(ofSize: NSFont.systemFontSize) }

    static func textWidth(_ text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        // NSTextField 自带约 2pt 内边距，额外留出避免末字被截断。
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + 4
    }

    /// 菜单宽度足够时完整显示说明；不足时说明至少保留 60%，其余截断名称。
    static func detailWidth(detail: String, label: String, available: CGFloat) -> CGFloat {
        let needed = textWidth(detail)
        guard needed > 0, available > 0 else { return 0 }
        let room = max(available * 0.6, available - columnGap - textWidth(label))
        return min(needed, room)
    }
}

// BETTBOX-CUSTOM: 一级策略组行。原生子菜单项右侧会预留快捷键列，说明与箭头
// 之间空白过大，因此自绘名称、灰色说明和箭头；子菜单展开仍由 NSMenu 负责。
private final class SubmenuTrayMenuItemView: NSView {
    private var label: String
    private var detail: String

    init(label: String, detail: String, width: CGFloat) {
        self.label = label
        self.detail = detail
        super.init(
            frame: NSRect(x: 0, y: 0, width: width, height: TrayMenuMetrics.rowHeight)
        )
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(label: String, detail: String) {
        guard label != self.label || detail != self.detail else { return }
        self.label = label
        self.detail = detail
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enclosingMenuItem?.isHighlighted ?? false
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 4, dy: 1),
                xRadius: 6,
                yRadius: 6
            ).fill()
        }
        let titleColor: NSColor = highlighted ? .selectedMenuItemTextColor : .labelColor
        let detailColor: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8)
            : .secondaryLabelColor

        let chevronRect = NSRect(
            x: bounds.width - TrayMenuMetrics.trailingInset - TrayMenuMetrics.chevronWidth,
            y: bounds.midY - 6,
            width: TrayMenuMetrics.chevronWidth,
            height: 12
        )
        drawChevron(in: chevronRect, color: titleColor)

        let detailRight = chevronRect.minX - TrayMenuMetrics.chevronGap
        let titleX = TrayMenuMetrics.titleX
        let detailWidth = TrayMenuMetrics.detailWidth(
            detail: detail,
            label: label,
            available: detailRight - titleX
        )
        let detailX = detailRight - detailWidth
        drawText(
            detail,
            in: NSRect(x: detailX, y: 0, width: detailWidth, height: bounds.height),
            color: detailColor,
            alignment: .right
        )
        let titleWidth = detailWidth > 0
            ? detailX - TrayMenuMetrics.columnGap - titleX
            : detailRight - titleX
        drawText(
            label,
            in: NSRect(x: titleX, y: 0, width: max(0, titleWidth), height: bounds.height),
            color: titleColor,
            alignment: .left
        )
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        color: NSColor,
        alignment: NSTextAlignment
    ) {
        guard !text.isEmpty, rect.width > 0 else { return }
        let font = TrayMenuMetrics.font
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let string = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
        let lineHeight = ceil(string.size().height)
        let textRect = NSRect(
            x: rect.minX,
            y: rect.minY + floor((rect.height - lineHeight) / 2),
            width: rect.width,
            height: lineHeight
        )
        string.draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }

    private func drawChevron(in rect: NSRect, color: NSColor) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        if let image = NSImage(
            systemSymbolName: "chevron.right",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration) {
            let size = image.size
            let scale = min(1, rect.width / size.width, rect.height / size.height)
            let drawSize = NSSize(width: size.width * scale, height: size.height * scale)
            image.draw(
                in: NSRect(
                    x: rect.midX - drawSize.width / 2,
                    y: rect.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
            )
            return
        }
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + 1, y: rect.maxY - 1))
        path.line(to: NSPoint(x: rect.maxX - 1, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX + 1, y: rect.minY + 1))
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }
}

public class TrayMenu: NSMenu, NSMenuDelegate {
    public var onMenuItemClick:((NSMenuItem) -> Void)?
    
    public override init(title: String) {
        super.init(title: title)
        autoenablesItems = false
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        autoenablesItems = false
    }

    private func menuItemTitle(
        _ label: String,
        _ sublabel: String,
        forceRightColumn: Bool = false
    ) -> String {
        if sublabel.isEmpty {
            return forceRightColumn ? "\(label)\t" : label
        }
        return "\(label)\t\(sublabel)"
    }

    private func applyShortcut(_ shortcut: String, to menuItem: NSMenuItem) {
        let parts = shortcut.split(separator: "-")
        guard parts.count == 2, parts[0] == "command" else {
            menuItem.keyEquivalent = ""
            menuItem.keyEquivalentModifierMask = []
            return
        }
        menuItem.keyEquivalent = String(parts[1]).lowercased()
        menuItem.keyEquivalentModifierMask = [.command]
    }

    private func preferredMenuWidth(_ items: [NSDictionary]) -> CGFloat {
        // BETTBOX-CUSTOM: 自绘行按整张菜单分两列：左列宽 = 最长名称，右列宽 = 最长说明，
        // 中间固定留 columnGap，保证任何一行的灰色说明都不会伸进其他行的名称区域。
        var width = CGFloat(220)
        var maxLabel = CGFloat.zero
        var maxDetail = CGFloat.zero
        var hasSubmenuRow = false
        var hasCustomRow = false
        for item in items {
            let itemDict = item as? [String: Any] ?? [:]
            let type = itemDict["type"] as? String ?? ""
            guard type != "separator" else {
                continue
            }
            let key = itemDict["key"] as? String ?? ""
            let label = itemDict["label"] as? String ?? ""
            let sublabel = itemDict["sublabel"] as? String ?? ""
            if TrayMenu.isCustomDrawnKey(key) {
                hasCustomRow = true
                hasSubmenuRow = hasSubmenuRow || key.hasPrefix("group-item:")
                maxLabel = max(maxLabel, TrayMenuMetrics.textWidth(label))
                maxDetail = max(maxDetail, TrayMenuMetrics.textWidth(sublabel))
                continue
            }
            let title = menuItemTitle(label, sublabel, forceRightColumn: type == "checkbox")
            width = max(width, ceil(TrayMenuMetrics.textWidth(title) + 56))
        }
        if hasCustomRow {
            var columns = TrayMenuMetrics.titleX + maxLabel + TrayMenuMetrics.trailingInset
            if maxDetail > 0 {
                columns += TrayMenuMetrics.columnGap + maxDetail
            }
            if hasSubmenuRow {
                columns += TrayMenuMetrics.chevronGap + TrayMenuMetrics.chevronWidth
            }
            width = max(width, ceil(columns))
        }
        return width
    }

    private static func isCustomDrawnKey(_ key: String) -> Bool {
        key.hasPrefix("proxy-item:") || key.hasPrefix("group-item:")
    }

    private func maximumTextWidth(_ items: [NSDictionary]) -> CGFloat {
        let font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        return items.reduce(CGFloat.zero) { width, item in
            let itemDict = item as? [String: Any] ?? [:]
            let type = itemDict["type"] as? String ?? ""
            let key = itemDict["key"] as? String ?? ""
            guard type != "separator", !TrayMenu.isCustomDrawnKey(key) else {
                return width
            }
            let label = itemDict["label"] as? String ?? ""
            let sublabel = itemDict["sublabel"] as? String ?? ""
            let labelWidth = (label as NSString).size(
                withAttributes: [.font: font]
            ).width
            let sublabelWidth = sublabel.isEmpty
                ? 0
                : (sublabel as NSString).size(
                    withAttributes: [.font: font]
                ).width + 24
            let totalWidth = labelWidth + sublabelWidth
            return max(width, ceil(totalWidth))
        }
    }

    private func setMenuItemTitle(
        _ menuItem: NSMenuItem,
        label: String,
        sublabel: String,
        forceRightColumn: Bool,
        maxTextWidth: CGFloat
    ) {
        if sublabel.isEmpty && !forceRightColumn {
            menuItem.title = label
            menuItem.attributedTitle = nil
            return
        }
        let titleString = sublabel.isEmpty ? "\(label)\t" : "\(label)\t\(sublabel)"
        let font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        let tabStop = NSTextTab(
            textAlignment: .right,
            location: maxTextWidth,
            options: [:]
        )
        paragraphStyle.tabStops = [tabStop]
        menuItem.attributedTitle = NSAttributedString(
            string: titleString,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
    
    public init(_ args: [String: Any]) {
        super.init(title: "")
        autoenablesItems = false

        let items: [NSDictionary] = args["items"] as! [NSDictionary];
        let menuWidth = preferredMenuWidth(items)
        minimumWidth = menuWidth
        let maxTextWidth = maximumTextWidth(items)
        for item in items {
            let menuItem: NSMenuItem
            
            let itemDict = item as! [String: Any]
            let id: Int = itemDict["id"] as! Int
            let key: String = itemDict["key"] as? String ?? ""
            let type: String = itemDict["type"] as! String
            let label: String = itemDict["label"] as? String ?? ""
            let sublabel: String = itemDict["sublabel"] as? String ?? ""
            let toolTip: String = itemDict["toolTip"] as? String ?? ""
            let checked: Bool? = itemDict["checked"] as? Bool
            let disabled: Bool = itemDict["disabled"] as? Bool ?? true
            let shortcut: String = itemDict["shortcut"] as? String ?? ""
            let isCheckbox = type == "checkbox"
            
            if (type == "separator") {
                menuItem = NSMenuItem.separator()
            } else {
                menuItem = NSMenuItem()
            }

            menuItem.tag = id
            menuItem.representedObject = key.isEmpty ? nil : key
            setMenuItemTitle(
                menuItem,
                label: label,
                sublabel: sublabel,
                forceRightColumn: isCheckbox,
                maxTextWidth: maxTextWidth
            )
            menuItem.toolTip = toolTip
            menuItem.isEnabled = !disabled
            menuItem.action = !disabled ? #selector(statusItemMenuButtonClicked) : nil
            menuItem.target = self
            applyShortcut(shortcut, to: menuItem)

            if key == "persistent-delay-test" {
                let persistentView = PersistentTrayMenuItemView(
                    label: label,
                    disabled: disabled,
                    width: menuWidth
                )
                persistentView.onClick = { [weak self] in
                    guard
                        let self,
                        let clickedItem = self.item(withTag: id)
                    else {
                        return
                    }
                    self.statusItemMenuButtonClicked(clickedItem)
                }
                menuItem.view = persistentView
                menuItem.action = nil
                menuItem.target = nil
            } else if key.hasPrefix("proxy-item:") {
                let alignedView = AlignedTrayMenuItemView(
                    label: label,
                    detail: sublabel,
                    checked: checked ?? false,
                    disabled: disabled,
                    width: menuWidth
                )
                alignedView.onClick = { [weak self] in
                    guard
                        let self,
                        let clickedItem = self.item(withTag: id)
                    else {
                        return
                    }
                    self.statusItemMenuButtonClicked(clickedItem)
                    self.cancelTracking()
                }
                menuItem.view = alignedView
                menuItem.action = nil
                menuItem.target = nil
            } else if key.hasPrefix("group-item:") && type == "submenu" {
                menuItem.view = SubmenuTrayMenuItemView(
                    label: label,
                    detail: sublabel,
                    width: menuWidth
                )
            }

            switch (type) {
            case "separator":
                break
            case "submenu":
                menuItem.action = nil
                menuItem.target = nil
                if let submenuDict = itemDict["submenu"] as? NSDictionary {
                    let submenu = TrayMenu(submenuDict as! [String : Any])
                    submenu.onMenuItemClick = { [weak self] (menuItem: NSMenuItem) in
                        self?.onMenuItemClick!(menuItem)
                    }
                    menuItem.submenu = submenu
                }
                break
            case "checkbox":
                if let checkedValue = checked {
                    menuItem.state = checkedValue ? .on : .off
                }
                break
            case "normal":
                break
            default:
                break
            }
            self.addItem(menuItem)
        }
        self.delegate = self
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        TrayManagerPlugin.instance.channel?.invokeMethod("onMenuOpen", arguments: nil)
    }

    public func menuDidClose(_ menu: NSMenu) {
        TrayManagerPlugin.instance.channel?.invokeMethod("onMenuClose", arguments: nil)
    }
    
    @objc func statusItemMenuButtonClicked(_ sender: NSMenuItem) {
        self.onMenuItemClick!(sender)
    }
    
    public func update(_ args: [String: Any]) {
        let items: [NSDictionary] = args["items"] as! [NSDictionary];

        guard items.count == self.items.count else {
            return
        }

        let maxTextWidth = maximumTextWidth(items)

        for (index, item) in items.enumerated() {
            let itemDict = item as! [String: Any]
            let key: String = itemDict["key"] as? String ?? ""
            let type: String = itemDict["type"] as! String
            let label: String = itemDict["label"] as? String ?? ""
            let sublabel: String = itemDict["sublabel"] as? String ?? ""
            let toolTip: String = itemDict["toolTip"] as? String ?? ""
            let checked: Bool? = itemDict["checked"] as? Bool
            let disabled: Bool = itemDict["disabled"] as? Bool ?? true
            let shortcut: String = itemDict["shortcut"] as? String ?? ""
            let isCheckbox = type == "checkbox"

            let menuItem: NSMenuItem
            if key.isEmpty {
                menuItem = self.items[index]
            } else {
                guard let keyedItem = self.items.first(where: {
                    ($0.representedObject as? String) == key
                }) else {
                    return
                }
                menuItem = keyedItem
            }
            let expectsSeparator = type == "separator"
            guard menuItem.isSeparatorItem == expectsSeparator else {
                return
            }

            setMenuItemTitle(
                menuItem,
                label: label,
                sublabel: sublabel,
                forceRightColumn: isCheckbox,
                maxTextWidth: maxTextWidth
            )
            menuItem.toolTip = toolTip
            menuItem.isEnabled = !disabled
            menuItem.action = !disabled ? #selector(statusItemMenuButtonClicked) : nil
            applyShortcut(shortcut, to: menuItem)

            if let persistentView = menuItem.view as? PersistentTrayMenuItemView {
                persistentView.update(label: label, disabled: disabled)
                menuItem.action = nil
            } else if let alignedView = menuItem.view as? AlignedTrayMenuItemView {
                alignedView.update(
                    label: label,
                    detail: sublabel,
                    checked: checked ?? false,
                    disabled: disabled
                )
                menuItem.action = nil
            } else if let submenuView = menuItem.view as? SubmenuTrayMenuItemView {
                submenuView.update(label: label, detail: sublabel)
            }

            if let checkedValue = checked {
                menuItem.state = checkedValue ? .on : .off
            }

            if (type == "submenu") {
                menuItem.action = nil
                menuItem.target = nil
                if let submenuDict = itemDict["submenu"] as? NSDictionary {
                    let submenu = menuItem.submenu as? TrayMenu
                    submenu?.update(submenuDict as! [String : Any])
                }
            }
        }
    }
}
