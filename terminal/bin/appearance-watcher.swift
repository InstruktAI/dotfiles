#!/usr/bin/env swift
// Watches for macOS appearance changes and reloads tmux theme
// Compile: swiftc -O -o appearance-watcher appearance-watcher.swift
// Or run directly: swift appearance-watcher.swift

import Cocoa

class AppearanceWatcher: NSObject, NSApplicationDelegate {
    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var debounceWorkItem: DispatchWorkItem?
    private var lastKnownMode: String?
    private var observation: NSKeyValueObservation?

    private func log(_ message: String) {
        let ts = logDateFormatter.string(from: Date())
        print("[\(ts)] \(message)")
        fflush(stdout)
    }

    private func currentMode() -> String {
        let appearance = NSApp.effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? "dark" : "light"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("started")
        lastKnownMode = currentMode()
        log("initial mode=\(lastKnownMode!)")

        observation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.appearanceChanged()
        }
        log("registered appearance observer (KVO)")
    }

    private func appearanceChanged() {
        log("appearance change received")
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleChange()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func handleChange() {
        let mode = currentMode()
        log("resolved mode=\(mode)")
        if mode == lastKnownMode {
            log("mode unchanged, skipping")
            return
        }
        reload(mode: mode)
        lastKnownMode = mode
    }

    private func reload(mode: String) {
        let task = Process()
        let appearanceURL = URL(fileURLWithPath: NSHomeDirectory() + "/.local/bin/appearance")
        task.executableURL = appearanceURL
        task.arguments = ["reload"]
        var env = ProcessInfo.processInfo.environment
        env["APPEARANCE_LOG"] = "1"
        let logURL = appearanceURL.resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .appendingPathComponent("appearance.log")
        env["APPEARANCE_LOG_FILE"] = logURL.path
        env["APPEARANCE_MODE"] = mode
        task.environment = env

        do {
            log("running appearance reload mode=\(mode)")
            try task.run()
            task.waitUntilExit()
            log("appearance reload exited status=\(task.terminationStatus)")
        } catch {
            log("appearance reload failed error=\(error)")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppearanceWatcher()
app.delegate = delegate
print("Watching for appearance changes... (Ctrl+C to stop)")
app.run()
