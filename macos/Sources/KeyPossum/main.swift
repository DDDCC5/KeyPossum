import AppKit
import Darwin

signal(SIGPIPE, SIG_IGN)
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--watchdog",
   let parent = Int32(CommandLine.arguments[2]) {
    Watchdog.run(parent: parent)
}
let delegate = ApplicationDelegate()
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
