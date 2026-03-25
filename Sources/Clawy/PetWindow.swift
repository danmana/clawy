import AppKit

/// A transparent, borderless, always-on-top window that sits above the Dock.
class PetWindow: NSWindow {

    init() {
        let size = NSSize(
            width: CGFloat(SpriteRenderer.spriteWidth),
            height: CGFloat(SpriteRenderer.spriteHeight)
        )

        let origin = Self.calculatePosition(for: size)

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

    func resetPosition() {
        let origin = Self.calculatePosition(for: frame.size)
        setFrameOrigin(origin)
    }

    /// Find the best screen and position Clawy on top of the Dock.
    /// Strategy: prefer the screen with a bottom Dock, fall back to the screen with the mouse cursor.
    static func calculatePosition(for size: NSSize) -> NSPoint {
        // Try to find a screen with a bottom Dock (visibleFrame.minY > frame.minY)
        let screenWithDock = NSScreen.screens.first { screen in
            screen.visibleFrame.minY - screen.frame.minY > 10
        }

        // Fall back to screen containing the mouse cursor
        let mouseScreen = NSScreen.screens.first { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        }

        let screen = screenWithDock ?? mouseScreen ?? NSScreen.screens[0]
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // If this screen has a bottom Dock, sit on top of it
        // Otherwise, sit at the bottom of the screen
        let dockTop = visibleFrame.minY
        let y = (dockTop > fullFrame.minY + 10) ? dockTop - 30 : fullFrame.minY

        return NSPoint(
            x: fullFrame.midX - size.width / 2 + 100,
            y: y
        )
    }
}
