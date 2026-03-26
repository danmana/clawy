#!/usr/bin/env swift
// Generates Clawy app icon as a 1024x1024 PNG from the pixel art grid.
// Usage: swift scripts/generate-icon.swift

import AppKit

let gridWidth = 18
let gridHeight = 16
let iconSize = 1024
let pixelSize = iconSize / gridWidth  // ~56px per grid cell

let bodyColor = NSColor(red: 0.85, green: 0.48, blue: 0.37, alpha: 1.0)
let eyeColor = NSColor(red: 0.18, green: 0.15, blue: 0.14, alpha: 1.0)
let clear = NSColor.clear

// Build the idle frame grid (same layout as SpriteRenderer)
var grid = Array(repeating: Array(repeating: clear, count: gridWidth), count: gridHeight)

// Body: rows 2-8, cols 4-13
for row in 2...8 {
    for col in 4...13 { grid[row][col] = bodyColor }
}
// Arms: rows 5-6
for row in 5...6 {
    grid[row][2] = bodyColor; grid[row][3] = bodyColor
    grid[row][14] = bodyColor; grid[row][15] = bodyColor
}
// Eyes: rows 4-5
grid[4][6] = eyeColor; grid[4][7] = eyeColor
grid[5][6] = eyeColor; grid[5][7] = eyeColor
grid[4][10] = eyeColor; grid[4][11] = eyeColor
grid[5][10] = eyeColor; grid[5][11] = eyeColor
// Legs: rows 9-10
for row in 9...10 {
    grid[row][5] = bodyColor; grid[row][7] = bodyColor
    grid[row][10] = bodyColor; grid[row][12] = bodyColor
}

// Render to image
let image = NSImage(size: NSSize(width: iconSize, height: iconSize))
image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .none
clear.setFill()
NSRect(x: 0, y: 0, width: iconSize, height: iconSize).fill()

for (row, cols) in grid.enumerated() {
    for (col, color) in cols.enumerated() {
        if color != clear {
            color.setFill()
            NSRect(
                x: col * pixelSize,
                y: (gridHeight - 1 - row) * pixelSize,
                width: pixelSize,
                height: pixelSize
            ).fill()
        }
    }
}
image.unlockFocus()

// Save as PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to render icon")
    exit(1)
}

let outputPath = "assets/icon.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Generated \(outputPath) (\(iconSize)x\(iconSize))")
