import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Start as regular so window + status item appear, then switch to accessory to hide Dock icon
app.setActivationPolicy(.regular)

app.run()
