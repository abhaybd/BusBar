import Foundation

// `--selftest` runs a headless pipeline check and exits; otherwise launch the menu bar app.
if CommandLine.arguments.contains("--selftest") {
    SelfTest.run()
} else {
    BusBarApp.main()
}
