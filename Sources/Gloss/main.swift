import AppKit

let app = NSApplication.shared
// NSApplication keeps its delegate weakly
let delegate = AppDelegate()
app.delegate = delegate
app.run()
