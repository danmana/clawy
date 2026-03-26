#!/usr/bin/env swift
// Generates a Clawy menu bar icon as a template PNG (black silhouette).
// Cropped tight to the character (no empty space below legs).

import AppKit

let gridWidth = 18
let gridHeight = 11  // Only rows 2-12 (body + legs), cropped tight
let topPadding = 2   // 2px transparent on top to shift down
let pixelSize = 3    // 3px per grid cell = 54x33 image
let imgWidth = gridWidth * pixelSize
let imgHeight = gridHeight * pixelSize + topPadding

let black = NSColor.black
let clear = NSColor.clear

// Build the grid — offset so row 2 of the original becomes row 0 here
var grid = Array(repeating: Array(repeating: clear, count: gridWidth), count: gridHeight)

// Body: original rows 2-8 → grid rows 0-6
for row in 0...6 {
    for col in 4...13 { grid[row][col] = black }
}
// Arms: original rows 5-6 → grid rows 3-4
for row in 3...4 {
    grid[row][2] = black; grid[row][3] = black
    grid[row][14] = black; grid[row][15] = black
}
// Eyes: original rows 4-5 → grid rows 2-3 (transparent cutouts)
grid[2][6] = clear; grid[2][7] = clear
grid[3][6] = clear; grid[3][7] = clear
grid[2][10] = clear; grid[2][11] = clear
grid[3][10] = clear; grid[3][11] = clear

// Legs: original rows 9-10 → grid rows 7-8
for row in 7...8 {
    grid[row][5] = black; grid[row][7] = black
    grid[row][10] = black; grid[row][12] = black
}

// Render
let image = NSImage(size: NSSize(width: imgWidth, height: imgHeight))
image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .none
clear.setFill()
NSRect(x: 0, y: 0, width: imgWidth, height: imgHeight).fill()

for (row, cols) in grid.enumerated() {
    for (col, color) in cols.enumerated() {
        if color != clear {
            color.setFill()
            NSRect(
                x: col * pixelSize,
                y: (gridHeight - 1 - row) * pixelSize,  // no topPadding offset — draws from bottom
                width: pixelSize,
                height: pixelSize
            ).fill()
        }
    }
}
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to render")
    exit(1)
}

try! png.write(to: URL(fileURLWithPath: "assets/menubar-icon.png"))
print("Generated assets/menubar-icon.png (\(imgWidth)x\(imgHeight))")
