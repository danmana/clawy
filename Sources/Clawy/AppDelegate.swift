import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var petWindow: PetWindow!
    private var petView: PetView!
    private var sessionAggregator: SessionAggregator!
    private var statusItem: NSStatusItem!
    private var thoughtBubble: ThoughtBubbleWindow!
    private var bubbleDelayTimer: Timer?
    private var bubbleFallbackTimer: Timer?
    private var idleWalkTimer: Timer?
    private var walkAnimationTimer: Timer?
    private var config = Config.load()
    private var sizeMenuItems: [PetSize: NSMenuItem] = [:]
    private var currentTerminalPid: Int32 = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply size from config
        SpriteRenderer.pixelSize = config.size.pixelSize

        // Setup menu bar icon
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

        // Size submenu
        let sizeMenu = NSMenu()
        for (label, size) in [("Small", PetSize.small), ("Medium", PetSize.medium), ("Large", PetSize.large)] {
            let item = NSMenuItem(title: label, action: #selector(changeSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            item.state = (config.size == size) ? .on : .off
            sizeMenu.addItem(item)
            sizeMenuItems[size] = item
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "GitHub", action: #selector(openGitHub), keyEquivalent: "")
            .target = self
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

        // Switch to accessory to hide from Dock
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }

        // Install hooks into Claude Code settings
        HookInstaller.install()

        // Handle SIGTERM/SIGINT to clean up hooks
        signal(SIGTERM) { _ in
            HookInstaller.uninstall()
            _Exit(0)
        }
        signal(SIGINT) { _ in
            HookInstaller.uninstall()
            _Exit(0)
        }

        // Start watching sessions directory
        sessionAggregator = SessionAggregator { [weak self] state in
            self?.handleAggregatedState(state)
        }
        sessionAggregator.start()

        // Reposition when screen configuration changes
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

    // MARK: - Aggregated State Handling

    private func handleAggregatedState(_ state: AggregatedState) {
        // Track terminal PID for click-to-focus
        if state.terminalPid > 0 {
            currentTerminalPid = state.terminalPid
        }

        // Stop idle walk if something is happening
        if state.animationState != .idle && isWalking {
            walkAnimationTimer?.invalidate()
            isWalking = false
        }

        petView.setState(state.animationState)

        if state.animationState == .alert {
            let msg = ThoughtBubble.message(toolName: state.toolName, command: state.command)
                ?? "Can I? Can I?"

            // Show alert count if multiple sessions need permission
            let displayMsg = state.alertCount > 1 ? "\(msg) (\(state.alertCount))" : msg

            bubbleDelayTimer?.invalidate()
            bubbleDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.thoughtBubble.show(message: displayMsg, above: self.petWindow)
                self.bubbleFallbackTimer?.invalidate()
                self.bubbleFallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
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
        if state.animationState == .idle {
            scheduleIdleWalk()
        }
    }

    // MARK: - Idle Walk

    private var idleWalkMenuItem: NSMenuItem!
    private var isWalking = false

    private func scheduleIdleWalk() {
        idleWalkTimer?.invalidate()
        guard config.idleWalk else { return }

        let delay = TimeInterval.random(in: 15...45)
        idleWalkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.startIdleWalk()
        }
    }

    private func startIdleWalk(force: Bool = false) {
        guard !isWalking else { return }
        guard force || config.idleWalk else {
            scheduleIdleWalk()
            return
        }

        guard force || petView.currentAnimationState == .idle else {
            scheduleIdleWalk()
            return
        }

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
        let steps = Int(abs(distance) / 2)
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

    // MARK: - Size

    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let newSize = PetSize(rawValue: rawValue),
              newSize != config.size else { return }

        config.size = newSize
        config.save()

        for (size, item) in sizeMenuItems {
            item.state = (size == newSize) ? .on : .off
        }

        SpriteRenderer.pixelSize = newSize.pixelSize
        rebuildPet()
    }

    private func rebuildPet() {
        let wasOriginX = petWindow.frame.origin.x

        walkAnimationTimer?.invalidate()
        isWalking = false
        idleWalkTimer?.invalidate()
        thoughtBubble.hide()
        petWindow.orderOut(nil)
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

        var origin = PetWindow.calculatePosition(for: petWindow.frame.size)
        origin.x = wasOriginX
        petWindow.setFrameOrigin(origin)

        petWindow.makeKeyAndOrderFront(nil)
        petWindow.orderFrontRegardless()

        scheduleIdleWalk()
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

    // MARK: - Actions

    func applicationWillTerminate(_ notification: Notification) {
        sessionAggregator?.stop()
        HookInstaller.uninstall()
    }

    @objc private func triggerWave() { petView.setState(.wave) }
    @objc private func triggerWalk() { startIdleWalk(force: true) }
    @objc private func triggerThink() { petView.setState(.thinking) }
    @objc private func triggerAlert() { petView.setState(.alert) }

    @objc private func testRandomBubble() {
        let testCases: [(String?, String?)] = [
            ("Bash", "rm"), ("Bash", "git"), ("Bash", "npm"),
            ("Bash", "curl"), ("Bash", "docker"), ("Bash", "mkdir"),
            ("Bash", "chmod"), ("Bash", "mv"), ("Bash", "kill"),
            ("Bash", "pip"), ("Bash", "brew"), ("Bash", "sed"),
            ("Bash", "touch"), ("Bash", "python"), ("Bash", "node"),
            ("Bash", "swift"), ("Bash", "ssh"), ("Bash", "kubectl"),
            ("Bash", "psql"), ("Bash", "mongo"),
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
        guard currentTerminalPid > 0 else {
            NSLog("Clawy: No terminal PID to focus")
            return
        }
        if let app = NSRunningApplication(processIdentifier: currentTerminalPid) {
            NSLog("Clawy: Focusing \(app.localizedName ?? "unknown") (PID \(currentTerminalPid))")
            app.activate(options: [.activateAllWindows])
        } else {
            NSLog("Clawy: Could not find app for PID \(currentTerminalPid)")
        }
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/danmana/clawy")!)
    }

    @objc private func quit() {
        HookInstaller.uninstall()
        NSApplication.shared.terminate(nil)
    }
}
