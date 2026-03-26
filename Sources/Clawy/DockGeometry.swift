import AppKit
import CoreGraphics

/// Reads macOS Dock preferences and calculates the precise dock icon area bounds.
struct DockGeometry {

    struct Info {
        /// The screen the dock is on (nil if no bottom dock found)
        let screen: NSScreen?
        /// Left edge of the dock icon area (in screen coordinates)
        let iconAreaX: CGFloat
        /// Width of the dock icon area
        let iconAreaWidth: CGFloat
        /// Y position of the top of the dock
        let dockTopY: CGFloat
        /// Whether the dock is set to auto-hide
        let autoHide: Bool
        /// Whether the dock is currently visible
        let isVisible: Bool
    }

    /// Check if the Dock's layer-20 window is on screen.
    /// This is the only reliable way to detect auto-hide visibility —
    /// visibleFrame doesn't change when the dock slides in/out with auto-hide.
    private static func isDockWindowOnScreen() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windowList.contains { w in
            let owner = w[kCGWindowOwnerName as String] as? String
            let layer = w[kCGWindowLayer as String] as? Int
            let name = w[kCGWindowName as String] as? String
            // The dock's main window is unnamed, on layer 20
            return owner == "Dock" && layer == 20 && (name == nil || name == "" || name == "(no name)")
        }
    }

    /// Calculate dock geometry for the current system state.
    static func current() -> Info {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let autoHide = dockDefaults?.bool(forKey: "autohide") ?? false
        let orientation = dockDefaults?.string(forKey: "orientation") ?? "bottom"
        let isBottomDock = (orientation == "bottom")

        guard isBottomDock else {
            let fallback = NSScreen.main ?? NSScreen.screens.first!
            return Info(
                screen: nil,
                iconAreaX: fallback.frame.minX,
                iconAreaWidth: fallback.frame.width,
                dockTopY: fallback.frame.minY,
                autoHide: autoHide,
                isVisible: false
            )
        }

        // Determine visibility: use visibleFrame gap for non-auto-hide,
        // CGWindowList for auto-hide
        let dockWindowPresent = isDockWindowOnScreen()

        let screenWithVisibleDock = NSScreen.screens.first { screen in
            screen.visibleFrame.minY - screen.frame.minY > 10
        }

        let dockScreen: NSScreen?
        let isCurrentlyVisible: Bool

        if let s = screenWithVisibleDock {
            // visibleFrame shows the dock gap — dock is permanently visible here
            dockScreen = s
            isCurrentlyVisible = true
        } else if autoHide && dockWindowPresent {
            // Auto-hide is on but dock is temporarily shown (layer-20 window present)
            dockScreen = NSScreen.main ?? NSScreen.screens.first
            isCurrentlyVisible = true
        } else {
            // Dock is hidden or not on bottom
            dockScreen = NSScreen.main ?? NSScreen.screens.first
            isCurrentlyVisible = false
        }

        let screen = dockScreen ?? NSScreen.screens.first!
        let screenFrame = screen.frame

        // Calculate the dock icon area width from dock preferences
        let tileSize = CGFloat(dockDefaults?.double(forKey: "tilesize") ?? 48)
        let slotWidth = tileSize * 1.25

        let persistentApps = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        let persistentOthers = dockDefaults?.array(forKey: "persistent-others")?.count ?? 0
        let showRecents = dockDefaults?.bool(forKey: "show-recents") ?? true
        let recentApps = showRecents ? (dockDefaults?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = persistentApps + persistentOthers + recentApps

        var dividers = 0
        if persistentApps > 0 && (persistentOthers > 0 || recentApps > 0) { dividers += 1 }
        if persistentOthers > 0 && recentApps > 0 { dividers += 1 }
        if showRecents && recentApps > 0 { dividers += 1 }

        let dividerWidth: CGFloat = 12.0
        var iconAreaWidth = slotWidth * CGFloat(totalIcons) + CGFloat(dividers) * dividerWidth
        iconAreaWidth *= 1.1

        let iconAreaX = screenFrame.minX + (screenFrame.width - iconAreaWidth) / 2.0

        // Top of the dock
        let dockTopY: CGFloat
        if !isCurrentlyVisible {
            dockTopY = screenFrame.minY
        } else if let s = screenWithVisibleDock, s == screen {
            // Non-auto-hide: visibleFrame gives us the exact dock top
            dockTopY = s.visibleFrame.minY
        } else {
            // Auto-hide showing: estimate dock height from tile size
            // Dock height ≈ tileSize + 2*padding. Empirically ~tileSize * 1.5
            let estimatedDockHeight = tileSize * 1.5
            dockTopY = screenFrame.minY + estimatedDockHeight
        }

        return Info(
            screen: screen,
            iconAreaX: iconAreaX,
            iconAreaWidth: iconAreaWidth,
            dockTopY: dockTopY,
            autoHide: autoHide,
            isVisible: isCurrentlyVisible
        )
    }
}
