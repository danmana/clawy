import AppKit

/// A floating window that shows a pixel-art thought bubble above Clawy.
class ThoughtBubbleWindow: NSWindow {

    private let label = NSTextField(labelWithString: "")
    private var hideTimer: Timer?

    static let bubbleWidth: CGFloat = 180
    static let bubbleHeight: CGFloat = 50
    static let tailHeight: CGFloat = 16
    static let borderSize: CGFloat = 3
    static let totalHeight: CGFloat = bubbleHeight + tailHeight

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.bubbleWidth, height: Self.totalHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = PixelBubbleView(frame: NSRect(x: 0, y: 0, width: Self.bubbleWidth, height: Self.totalHeight))
        self.contentView = container

        // Label
        label.frame = NSRect(x: 12, y: Self.tailHeight + 6, width: Self.bubbleWidth - 24, height: Self.bubbleHeight - 12)
        label.alignment = .center
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        label.textColor = NSColor(red: 0.18, green: 0.15, blue: 0.14, alpha: 1.0)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        container.addSubview(label)
    }

    /// Show the bubble. Pass `duration: 0` to keep it visible until `hide()` is called.
    func show(message: String, above petWindow: NSWindow, duration: TimeInterval = 0) {
        label.stringValue = message
        label.sizeToFit()
        let labelH = label.frame.height
        let bubbleInnerY = Self.tailHeight + (Self.bubbleHeight - labelH) / 2
        label.frame = NSRect(x: 12, y: bubbleInnerY, width: Self.bubbleWidth - 24, height: labelH)

        let petFrame = petWindow.frame
        let x = petFrame.midX - Self.bubbleWidth / 2
        let y = petFrame.maxY - 8

        setFrameOrigin(NSPoint(x: x, y: y))
        orderFrontRegardless()

        hideTimer?.invalidate()
        if duration > 0 {
            hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.orderOut(nil)
            }
        }
    }

    func hide() {
        hideTimer?.invalidate()
        orderOut(nil)
    }
}

/// Draws a pixel-art speech bubble with stepped corners and a pixel tail.
private class PixelBubbleView: NSView {

    private let px: CGFloat = 3  // Pixel size for the border
    private let borderColor = NSColor(red: 0.15, green: 0.12, blue: 0.12, alpha: 1.0)
    private let fillColor = NSColor.white

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let tailH: CGFloat = ThoughtBubbleWindow.tailHeight
        let bubbleH: CGFloat = ThoughtBubbleWindow.bubbleHeight

        // The bubble sits from tailH to tailH+bubbleH
        let bY = tailH
        let bH = bubbleH

        // Draw filled bubble with pixel-stepped corners
        // Main fill (inset by border)
        fillColor.setFill()

        // Center rect (full width minus corners)
        NSRect(x: px * 2, y: bY, width: w - px * 4, height: bH).fill()
        // Left strip
        NSRect(x: px, y: bY + px, width: px, height: bH - px * 2).fill()
        // Right strip
        NSRect(x: w - px * 2, y: bY + px, width: px, height: bH - px * 2).fill()
        // Left edge
        NSRect(x: 0, y: bY + px * 2, width: px, height: bH - px * 4).fill()
        // Right edge
        NSRect(x: w - px, y: bY + px * 2, width: px, height: bH - px * 4).fill()

        // Draw border pixels
        borderColor.setFill()

        // Top border
        NSRect(x: px * 2, y: bY + bH - px, width: w - px * 4, height: px).fill()
        // Bottom border (with gap for tail)
        let tailX = w - px * 8
        NSRect(x: px * 2, y: bY, width: tailX - px * 2, height: px).fill()
        NSRect(x: tailX + px * 4, y: bY, width: w - px * 3 - (tailX + px * 4), height: px).fill()

        // Left border
        NSRect(x: 0, y: bY + px * 2, width: px, height: bH - px * 4).fill()
        // Right border
        NSRect(x: w - px, y: bY + px * 2, width: px, height: bH - px * 4).fill()

        // Stepped corners (top-left)
        NSRect(x: px, y: bY + bH - px * 2, width: px, height: px).fill()
        NSRect(x: px * 2, y: bY + bH - px, width: px, height: px).fill()      // extra step

        // Stepped corners (top-right)
        NSRect(x: w - px * 2, y: bY + bH - px * 2, width: px, height: px).fill()
        NSRect(x: w - px * 3, y: bY + bH - px, width: px, height: px).fill()

        // Stepped corners (bottom-left)
        NSRect(x: px, y: bY + px, width: px, height: px).fill()
        NSRect(x: px * 2, y: bY, width: px, height: px).fill()

        // Stepped corners (bottom-right) — skip, tail goes here
        NSRect(x: w - px * 2, y: bY + px, width: px, height: px).fill()
        NSRect(x: w - px * 3, y: bY, width: px, height: px).fill()

        // Pixel tail (right side, pointing down-left)
        // White fill where tail meets bubble
        fillColor.setFill()
        NSRect(x: tailX, y: bY, width: px * 4, height: px).fill()

        // Tail: stepped diagonal going down-left
        // Row 1 (just below bubble)
        fillColor.setFill()
        NSRect(x: tailX, y: bY - px, width: px * 3, height: px).fill()
        borderColor.setFill()
        NSRect(x: tailX + px * 3, y: bY - px, width: px, height: px).fill()

        // Row 2
        fillColor.setFill()
        NSRect(x: tailX - px, y: bY - px * 2, width: px * 3, height: px).fill()
        borderColor.setFill()
        NSRect(x: tailX - px * 2, y: bY - px * 2, width: px, height: px).fill()
        NSRect(x: tailX + px * 2, y: bY - px * 2, width: px, height: px).fill()

        // Row 3
        fillColor.setFill()
        NSRect(x: tailX - px * 2, y: bY - px * 3, width: px * 2, height: px).fill()
        borderColor.setFill()
        NSRect(x: tailX - px * 3, y: bY - px * 3, width: px, height: px).fill()
        NSRect(x: tailX, y: bY - px * 3, width: px, height: px).fill()

        // Row 4 (tip)
        borderColor.setFill()
        NSRect(x: tailX - px * 3, y: bY - px * 4, width: px, height: px).fill()
        NSRect(x: tailX - px * 2, y: bY - px * 4, width: px, height: px).fill()

        // Row 5 (very tip)
        NSRect(x: tailX - px * 4, y: bY - px * 5, width: px, height: px).fill()
    }
}
