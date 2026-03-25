import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var petWindow: PetWindow!
    private var petView: PetView!
    private var hookWatcher: HookWatcher!
    private var statusItem: NSStatusItem!
    private var thoughtBubble: ThoughtBubbleWindow!
    private var bubbleDelayTimer: Timer?
    private var bubbleFallbackTimer: Timer?
    private var idleWalkTimer: Timer?
    private var walkAnimationTimer: Timer?
    private var config = Config.load()

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
        idleWalkMenuItem = NSMenuItem(title: "Idle Walk", action: #selector(toggleIdleWalk), keyEquivalent: "")
        idleWalkMenuItem.target = self
        idleWalkMenuItem.state = config.idleWalk ? .on : .off
        menu.addItem(idleWalkMenuItem)
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
        petView.onClick = { [weak self] in
            self?.focusTerminal()
        }
        petView.onDragEnd = { [weak self] in
            self?.savePosition()
        }
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

        // Start idle walk timer
        scheduleIdleWalk()

        NSLog("Clawy: Clawy is alive!")
    }

    // MARK: - Idle Walk

    private var idleWalkMenuItem: NSMenuItem!
    private var isWalking = false

    private func scheduleIdleWalk() {
        idleWalkTimer?.invalidate()
        guard config.idleWalk else { return }

        // Walk every 15-45 seconds when idle
        let delay = TimeInterval.random(in: 15...45)
        idleWalkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.startIdleWalk()
        }
    }

    private func startIdleWalk() {
        guard config.idleWalk, !isWalking else {
            scheduleIdleWalk()
            return
        }

        // Only walk when idle
        guard petView.currentAnimationState == .idle else {
            scheduleIdleWalk()
            return
        }

        // Pick a random X within the center 60% of the screen (approximate Dock width)
        let screen = NSScreen.screens.first { $0.frame.contains(petWindow.frame.origin) }
            ?? NSScreen.screens[0]
        let screenWidth = screen.frame.width
        let walkWidth = screenWidth * 0.6
        let walkMargin = (screenWidth - walkWidth) / 2
        let minX = screen.frame.minX + walkMargin
        let maxX = screen.frame.minX + walkMargin + walkWidth - petWindow.frame.width
        let targetX = CGFloat.random(in: minX...maxX)

        walkTo(targetX: targetX)
    }

    private func walkTo(targetX: CGFloat) {
        isWalking = true
        petView.setState(.walking)

        let currentX = petWindow.frame.origin.x
        let distance = targetX - currentX
        let steps = Int(abs(distance) / 2)  // 2 points per step
        guard steps > 0 else {
            finishWalk()
            return
        }

        let stepX = distance / CGFloat(steps)
        var step = 0

        walkAnimationTimer?.invalidate()
        walkAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let newOrigin = NSPoint(
                x: self.petWindow.frame.origin.x + stepX,
                y: self.petWindow.frame.origin.y
            )
            self.petWindow.setFrameOrigin(newOrigin)

            if step >= steps {
                timer.invalidate()
                self.finishWalk()
            }
        }
    }

    private func finishWalk() {
        isWalking = false
        petView.setState(.idle)
        savePosition()
        scheduleIdleWalk()
    }

    private func savePosition() {
        config.lastX = Double(petWindow.frame.origin.x)
        config.save()
    }

    @objc private func toggleIdleWalk() {
        config.idleWalk.toggle()
        config.save()
        idleWalkMenuItem.state = config.idleWalk ? .on : .off
        if config.idleWalk {
            scheduleIdleWalk()
        } else {
            idleWalkTimer?.invalidate()
            walkAnimationTimer?.invalidate()
            if isWalking {
                finishWalk()
            }
        }
    }

    // MARK: - Hook Handling

    private func handleHookStatus(_ status: HookStatus) {
        // Stop idle walk if something else is happening
        if status.state != .idle && isWalking {
            walkAnimationTimer?.invalidate()
            isWalking = false
        }

        petView.setState(status.state)

        if status.state == .alert, status.toolName != nil {
            let msg = ThoughtBubble.message(toolName: status.toolName, command: status.command)
                ?? "Can I? Can I?"
            bubbleDelayTimer?.invalidate()
            bubbleDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.thoughtBubble.show(message: msg, above: self.petWindow)
                self.bubbleFallbackTimer?.invalidate()
                self.bubbleFallbackTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
                    self?.thoughtBubble.hide()
                    self?.petView.setState(.idle)
                }
            }
        } else {
            bubbleDelayTimer?.invalidate()
            bubbleDelayTimer = nil
            bubbleFallbackTimer?.invalidate()
            bubbleFallbackTimer = nil
            thoughtBubble.hide()
        }

        // Reschedule idle walk when returning to idle
        if status.state == .idle {
            scheduleIdleWalk()
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

    private func focusTerminal() {
        let pidFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".clawy/terminal_pid")
        guard let content = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
