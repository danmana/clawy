import AppKit

/// The main view that displays and animates Clawy.
class PetView: NSView {

    private let imageView = NSImageView()
    private var animationTimer: Timer?
    private var currentFrames: [NSImage] = []
    private var currentFrameIndex: Int = 0
    private(set) var currentAnimationState: AnimationState? = nil

    // Preloaded frame caches
    private var frameCache: [AnimationState: [NSImage]] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Preload all animation frames
        for state in AnimationState.allCases {
            frameCache[state] = SpriteRenderer.frames(for: state)
        }

        // Setup image view
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = false
        addSubview(imageView)

        // Start idle animation
        setState(.idle)
    }

    func setState(_ state: AnimationState) {
        guard state != currentAnimationState || !state.loops || currentAnimationState == nil else { return }

        currentAnimationState = state
        currentFrameIndex = 0
        currentFrames = frameCache[state] ?? []

        // Reset timer
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: state.frameDuration,
            repeats: true
        ) { [weak self] _ in
            self?.advanceFrame()
        }

        // Show first frame immediately
        if !currentFrames.isEmpty {
            imageView.image = currentFrames[0]
        }
    }

    private func advanceFrame() {
        guard !currentFrames.isEmpty else { return }

        currentFrameIndex += 1

        if currentFrameIndex >= currentFrames.count {
            if currentAnimationState?.loops == true {
                currentFrameIndex = 0
            } else {
                // Non-looping animation finished, return to idle
                setState(.idle)
                return
            }
        }

        imageView.image = currentFrames[currentFrameIndex]
    }

    // MARK: - Mouse Interaction

    /// Called when the pet is clicked. Override behavior externally.
    var onClick: (() -> Void)?
    var onDragEnd: (() -> Void)?

    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStartLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        isDragging = true

        // Move window horizontally only (constrain Y to current position)
        let currentFrame = window.frame
        let deltaX = event.locationInWindow.x - dragStartLocation.x
        let newOrigin = NSPoint(x: currentFrame.origin.x + deltaX, y: currentFrame.origin.y)
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            onClick?()
            if currentAnimationState == .idle {
                setState(.wave)
            }
        } else {
            onDragEnd?()
        }
        isDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        // Right-click context menu
        let menu = NSMenu(title: "Clawy")

        menu.addItem(withTitle: "Wave", action: #selector(doWave), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Walk", action: #selector(doWalk), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Think", action: #selector(doThink), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clawy", action: #selector(doQuit), keyEquivalent: "q")
            .target = self

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func doWave() { setState(.wave) }
    @objc private func doWalk() { setState(.walking) }
    @objc private func doThink() { setState(.thinking) }
    @objc private func doQuit() { NSApplication.shared.terminate(nil) }
}
