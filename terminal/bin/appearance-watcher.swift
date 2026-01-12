#!/usr/bin/env swift
// Watches for macOS appearance changes and reloads tmux theme
// Compile: swiftc -o appearance-watcher appearance-watcher.swift
// Or run directly: swift appearance-watcher.swift

import Cocoa

class AppearanceWatcher {
    init() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc func appearanceChanged(_ notification: Notification) {
        // Small delay to ensure appearance change is fully propagated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.reloadTmuxTheme()
        }
    }

    func reloadTmuxTheme() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/Users/Morriz/.local/bin/appearance")
        task.arguments = ["reload"]

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // Silently ignore errors
        }
    }
}

// Create watcher and run forever
let watcher = AppearanceWatcher()
print("Watching for appearance changes... (Ctrl+C to stop)")
RunLoop.main.run()
