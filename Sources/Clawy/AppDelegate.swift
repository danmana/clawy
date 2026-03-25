import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var petWindow: PetWindow!
    private var petView: PetView!
    private var hookWatcher: HookWatcher!
    private var statusItem: NSStatusItem!
    private var thoughtBubble: ThoughtBubbleWindow!
    private var bubbleDelayTimer: Timer?
    private var bubbleFallbackTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon first (before policy switch)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Clawy") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "C"
            }
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Wave", action: #selector(triggerWave), keyEquivalent: "w")
        menu.addItem(withTitle: "Walk", action: #selector(triggerWalk), keyEquivalent: "")
        menu.addItem(withTitle: "Think", action: #selector(triggerThink), keyEquivalent: "")
        menu.addItem(withTitle: "Alert!", action: #selector(triggerAlert), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Test Random Bubble", action: #selector(testRandomBubble), keyEquivalent: "t")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clawy", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        // Create the pet window
        petWindow = PetWindow()
        petView = PetView(frame: NSRect(
            x: 0, y: 0,
            width: SpriteRenderer.spriteWidth,
            height: SpriteRenderer.spriteHeight
        ))
        petWindow.contentView = petView
        petWindow.makeKeyAndOrderFront(nil)
        petWindow.orderFrontRegardless()

        // Create thought bubble (hidden initially)
        thoughtBubble = ThoughtBubbleWindow()

        // Switch to accessory to hide from Dock (status item + window stay visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }

        // Start watching for Claude Code hook events
        hookWatcher = HookWatcher { [weak self] status in
            self?.handleHookStatus(status)
        }
        hookWatcher.start()

        // Reposition when screen configuration changes (Dock resize, display connect/disconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSLog("Clawy: Clawy is alive!")
    }

    private func handleHookStatus(_ status: HookStatus) {
        petView.setState(status.state)

        if status.state == .alert, status.toolName != nil {
            // Delay showing the bubble by 300ms — if idle arrives before then, skip it
            let msg = ThoughtBubble.message(toolName: status.toolName, command: status.command)
                ?? "Can I? Can I?"
            bubbleDelayTimer?.invalidate()
            bubbleDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.thoughtBubble.show(message: msg, above: self.petWindow)
                // Fallback: reset everything after 15s (for when user cancels permission)
                self.bubbleFallbackTimer?.invalidate()
                self.bubbleFallbackTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
                    self?.thoughtBubble.hide()
                    self?.petView.setState(.idle)
                }
            }
        } else {
            // Any other state (idle, wave, thinking) = hide the bubble
            bubbleDelayTimer?.invalidate()
            bubbleDelayTimer = nil
            bubbleFallbackTimer?.invalidate()
            bubbleFallbackTimer = nil
            thoughtBubble.hide()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hookWatcher?.stop()
    }

    @objc private func triggerWave() { petView.setState(.wave) }
    @objc private func triggerWalk() { petView.setState(.walking) }
    @objc private func triggerThink() { petView.setState(.thinking) }
    @objc private func triggerAlert() { petView.setState(.alert) }

    @objc private func testRandomBubble() {
        let testCases: [(String?, String?)] = [
            ("Bash", "rm"),
            ("Bash", "git"),
            ("Bash", "npm"),
            ("Bash", "curl"),
            ("Bash", "docker"),
            ("Bash", "mkdir"),
            ("Bash", "chmod"),
            ("Bash", "mv"),
            ("Bash", "kill"),
            ("Bash", "pip"),
            ("Bash", "brew"),
            ("Bash", "sed"),
            ("Bash", "touch"),
            ("Bash", "python"),
            ("Bash", "node"),
            ("Bash", "swift"),
        ]
        let pick = testCases.randomElement()!
        guard let msg = ThoughtBubble.message(toolName: pick.0, command: pick.1) else { return }
        petView.setState(.alert)
        thoughtBubble.show(message: msg, above: petWindow, duration: 4.0)
    }

    @objc private func screenDidChange(_ notification: Notification) {
        petWindow.resetPosition()
    }

    @objc private func resetPosition() {
        petWindow.resetPosition()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
