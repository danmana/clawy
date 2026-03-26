import AppKit

/// A transparent, borderless, always-on-top window that sits above the Dock.
class PetWindow: NSWindow {

    init() {
        let size = NSSize(
            width: CGFloat(SpriteRenderer.spriteWidth),
            height: CGFloat(SpriteRenderer.spriteHeight)
        )

        var origin = Self.calculatePosition(for: size)

        // Restore saved X position if available
        let config = Config.load()
        if let lastX = config.lastX {
            origin.x = lastX
        }

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        NSLog("Clawy: window origin=\(origin), size=\(size)")
    }

    /// Full reset (used by menu item) — recalculates both X and Y.
    func resetPosition() {
        let origin = Self.calculatePosition(for: frame.size)
        setFrameOrigin(origin)
    }

    /// Update only the Y position (preserves horizontal placement).
    /// Called when Dock shows/hides or screen config changes.
    func updateVerticalPosition() {
        let newOrigin = Self.calculatePosition(for: frame.size)
        setFrameOrigin(NSPoint(x: frame.origin.x, y: newOrigin.y))
    }

    /// Find the best screen and position Clawy on top of the Dock.
    /// Uses precise dock geometry from macOS Dock preferences.
    static func calculatePosition(for size: NSSize) -> NSPoint {
        let dock = DockGeometry.current()

        // Fall back to screen containing the mouse cursor if no dock screen
        let mouseScreen = NSScreen.screens.first { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        }
        let screen = dock.screen ?? mouseScreen ?? NSScreen.screens[0]

        // Offset by the empty space below the feet in the sprite
        let feetOffset = CGFloat(SpriteRenderer.feetBottomPadding)
        let y = dock.isVisible ? dock.dockTopY - feetOffset : screen.frame.minY - 10

        // Center within the dock icon area
        let x = dock.iconAreaX + dock.iconAreaWidth / 2 - size.width / 2 + 100

        return NSPoint(x: x, y: y)
    }
}
