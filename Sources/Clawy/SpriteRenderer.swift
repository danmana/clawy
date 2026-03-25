import AppKit

/// Programmatically renders Clawd pixel art frames.
/// The character is drawn on a pixel grid and scaled up for crisp rendering.
///
/// Clawd design (from reference):
/// - Wide salmon/orange rectangular body
/// - Two dark square eyes in the upper portion
/// - Two stubby arms extending from the sides
/// - Four legs underneath with gaps between them
struct SpriteRenderer {

    static let pixelSize: Int = 6       // Each logical pixel = 6x6 screen pixels
    static let gridWidth: Int = 18      // Wider grid to fit arms
    static let gridHeight: Int = 16     // Character grid height

    static var spriteWidth: Int { gridWidth * pixelSize }   // 108
    static var spriteHeight: Int { gridHeight * pixelSize } // 96

    // MARK: - Colors

    static let bodyColor      = NSColor(red: 0.85, green: 0.48, blue: 0.37, alpha: 1.0)  // salmon/orange
    static let eyeColor       = NSColor(red: 0.18, green: 0.15, blue: 0.14, alpha: 1.0)  // near black
    static let clear          = NSColor.clear

    // MARK: - Frame Generation

    static func frames(for state: AnimationState) -> [NSImage] {
        (0..<state.frameCount).map { frame(for: state, index: $0) }
    }

    static func frame(for state: AnimationState, index: Int) -> NSImage {
        let width = spriteWidth
        let height = spriteHeight
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none

        // Clear background
        clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        let grid = buildGrid(for: state, frameIndex: index)
        drawGrid(grid)

        image.unlockFocus()
        return image
    }

    // MARK: - Grid Building

    static func buildGrid(for state: AnimationState, frameIndex: Int) -> [[NSColor]] {
        switch state {
        case .idle:     return idleGrid(frame: frameIndex)
        case .wave:     return waveGrid(frame: frameIndex)
        case .alert:    return alertGrid(frame: frameIndex)
        case .thinking: return thinkingGrid(frame: frameIndex)
        case .walking:  return walkingGrid(frame: frameIndex)
        }
    }

    // MARK: - Base Body
    //
    // Clawd layout on 18x16 grid:
    //
    //   Row 2-8:   Main body (cols 4-13, 10 wide x 7 tall)
    //   Row 5-6:   Arms (cols 2-3 left, cols 14-15 right)
    //   Row 4-5:   Eyes 2x2 (left: cols 6-7, right: cols 10-11)
    //   Row 9-12:  Four legs (each 1 wide, 3 tall) at cols 5, 7, 10, 12
    //

    static func baseBody(bodyOffset: Int = 0, eyeStyle: EyeStyle = .open,
                         armStyle: ArmStyle = .down,
                         legStyle: LegStyle = .standing) -> [[NSColor]] {
        var grid = Array(repeating: Array(repeating: clear, count: gridWidth), count: gridHeight)

        let top = 2 + bodyOffset
        let bottom = 8 + bodyOffset

        // Main body rectangle
        for row in top...bottom {
            for col in 4...13 {
                grid[row][col] = bodyColor
            }
        }

        // Stubby arms
        let armTop = 5 + bodyOffset
        let armBottom = 6 + bodyOffset
        switch armStyle {
        case .down:
            // Both arms at sides
            grid[armTop][2] = bodyColor; grid[armTop][3] = bodyColor
            grid[armBottom][2] = bodyColor; grid[armBottom][3] = bodyColor
            grid[armTop][14] = bodyColor; grid[armTop][15] = bodyColor
            grid[armBottom][14] = bodyColor; grid[armBottom][15] = bodyColor
        case .rightUp:
            // Left arm normal, right arm raised
            grid[armTop][2] = bodyColor; grid[armTop][3] = bodyColor
            grid[armBottom][2] = bodyColor; grid[armBottom][3] = bodyColor
            let raisedRow = armTop - 1
            grid[raisedRow][14] = bodyColor; grid[raisedRow][15] = bodyColor
            grid[armTop][14] = bodyColor; grid[armTop][15] = bodyColor
        case .rightWave:
            // Left arm normal, right arm raised high
            grid[armTop][2] = bodyColor; grid[armTop][3] = bodyColor
            grid[armBottom][2] = bodyColor; grid[armBottom][3] = bodyColor
            let raisedRow = armTop - 2
            if raisedRow >= 0 {
                grid[raisedRow][14] = bodyColor; grid[raisedRow][15] = bodyColor
                grid[raisedRow][16] = bodyColor
            }
            grid[raisedRow + 1][14] = bodyColor; grid[raisedRow + 1][15] = bodyColor
        case .bothUp:
            // Both arms raised
            let raisedRow = armTop - 1
            grid[raisedRow][2] = bodyColor; grid[raisedRow][3] = bodyColor
            grid[armTop][2] = bodyColor; grid[armTop][3] = bodyColor
            grid[raisedRow][14] = bodyColor; grid[raisedRow][15] = bodyColor
            grid[armTop][14] = bodyColor; grid[armTop][15] = bodyColor
        }

        // Eyes
        let eyeRow = 4 + bodyOffset
        switch eyeStyle {
        case .open:
            grid[eyeRow][6] = eyeColor; grid[eyeRow][7] = eyeColor
            grid[eyeRow + 1][6] = eyeColor; grid[eyeRow + 1][7] = eyeColor
            grid[eyeRow][10] = eyeColor; grid[eyeRow][11] = eyeColor
            grid[eyeRow + 1][10] = eyeColor; grid[eyeRow + 1][11] = eyeColor
        case .closed:
            grid[eyeRow + 1][6] = eyeColor; grid[eyeRow + 1][7] = eyeColor
            grid[eyeRow + 1][10] = eyeColor; grid[eyeRow + 1][11] = eyeColor
        case .lookUp:
            grid[eyeRow - 1][6] = eyeColor; grid[eyeRow - 1][7] = eyeColor
            grid[eyeRow][6] = eyeColor; grid[eyeRow][7] = eyeColor
            grid[eyeRow - 1][10] = eyeColor; grid[eyeRow - 1][11] = eyeColor
            grid[eyeRow][10] = eyeColor; grid[eyeRow][11] = eyeColor
        case .wide:
            for r in (eyeRow - 1)...(eyeRow + 1) {
                grid[r][6] = eyeColor; grid[r][7] = eyeColor
                grid[r][10] = eyeColor; grid[r][11] = eyeColor
            }
        }

        // Four legs underneath the body
        let legTop = bottom + 1
        switch legStyle {
        case .standing:
            for r in legTop...(legTop + 1) {
                grid[r][5] = bodyColor
                grid[r][7] = bodyColor
                grid[r][10] = bodyColor
                grid[r][12] = bodyColor
            }
        case .walkA:
            for r in legTop...(legTop + 1) {
                grid[r][4] = bodyColor
                grid[r][8] = bodyColor
                grid[r][9] = bodyColor
                grid[r][13] = bodyColor
            }
        case .walkB:
            for r in legTop...(legTop + 1) {
                grid[r][6] = bodyColor
                grid[r][7] = bodyColor
                grid[r][10] = bodyColor
                grid[r][11] = bodyColor
            }
        case .tucked:
            grid[legTop][5] = bodyColor
            grid[legTop][7] = bodyColor
            grid[legTop][10] = bodyColor
            grid[legTop][12] = bodyColor
        }

        return grid
    }

    // MARK: - Animation Grids

    static func idleGrid(frame: Int) -> [[NSColor]] {
        let offset = (frame == 1 || frame == 2) ? -1 : 0
        let eyeStyle: EyeStyle = (frame == 3) ? .closed : .open
        return baseBody(bodyOffset: offset, eyeStyle: eyeStyle)
    }

    static func waveGrid(frame: Int) -> [[NSColor]] {
        switch frame {
        case 0: return baseBody()
        case 1: return baseBody(armStyle: .rightUp)
        case 2, 3: return baseBody(armStyle: .rightWave)
        case 4: return baseBody(armStyle: .rightUp)
        case 5: return baseBody()
        default: return baseBody()
        }
    }

    static func alertGrid(frame: Int) -> [[NSColor]] {
        let offset = (frame % 2 == 0) ? -2 : 0
        var grid = baseBody(bodyOffset: offset, eyeStyle: .wide, armStyle: .bothUp)

        // Exclamation mark above head
        let markRow = offset
        if markRow >= 0 && frame % 3 != 2 {
            grid[markRow][8] = eyeColor
            grid[markRow][9] = eyeColor
            if markRow + 1 < gridHeight {
                grid[markRow + 1][8] = eyeColor
                grid[markRow + 1][9] = eyeColor
            }
        }

        return grid
    }

    static func thinkingGrid(frame: Int) -> [[NSColor]] {
        var grid = baseBody(eyeStyle: .lookUp)

        // Animated dots above head
        let dotRow = 0
        let dotCount = (frame % 4) + 1
        if dotCount >= 1 { grid[dotRow][5] = bodyColor }
        if dotCount >= 2 { grid[dotRow][8] = bodyColor }
        if dotCount >= 3 { grid[dotRow][11] = bodyColor }

        return grid
    }

    static func walkingGrid(frame: Int) -> [[NSColor]] {
        let legStyle: LegStyle = (frame % 2 == 0) ? .walkA : .walkB
        let offset = (frame == 1 || frame == 3) ? -1 : 0
        return baseBody(bodyOffset: offset, legStyle: legStyle)
    }

    // MARK: - Drawing

    static func drawGrid(_ grid: [[NSColor]]) {
        for (row, cols) in grid.enumerated() {
            for (col, color) in cols.enumerated() {
                if color != clear {
                    color.setFill()
                    let rect = NSRect(
                        x: col * pixelSize,
                        y: (gridHeight - 1 - row) * pixelSize,  // Flip Y
                        width: pixelSize,
                        height: pixelSize
                    )
                    rect.fill()
                }
            }
        }
    }

    // MARK: - Types

    enum EyeStyle {
        case open, closed, lookUp, wide
    }

    enum ArmStyle {
        case down, rightUp, rightWave, bothUp
    }

    enum LegStyle {
        case standing, walkA, walkB, tucked
    }
}
