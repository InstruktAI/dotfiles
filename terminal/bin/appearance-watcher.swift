#!/usr/bin/env swift
// Watches for macOS appearance changes and reloads tmux theme
// Compile: swiftc -o appearance-watcher appearance-watcher.swift
// Or run directly: swift appearance-watcher.swift

import Cocoa
import Darwin

private let appearanceNotificationName = NSNotification.Name("AppleInterfaceThemeChangedNotification")

private func appearanceDarwinCallback(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    guard let observer = observer else { return }
    let watcher = Unmanaged<AppearanceWatcher>.fromOpaque(observer).takeUnretainedValue()
    watcher.appearanceChanged(Notification(name: appearanceNotificationName))
}

class AppearanceWatcher {
    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var debounceWorkItem: DispatchWorkItem?

    private func log(_ message: String) {
        let ts = logDateFormatter.string(from: Date())
        print("[\(ts)] \(message)")
        fflush(stdout)
    }

    init() {
        log("started")
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: appearanceNotificationName,
            object: nil
        )
        log("registered distributed notification")

        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            darwinCenter,
            observer,
            appearanceDarwinCallback,
            appearanceNotificationName.rawValue as CFString,
            nil,
            .deliverImmediately
        )
        log("registered darwin notification")
    }

    @objc func appearanceChanged(_ notification: Notification) {
        log("appearance change received")
        // Small delay to ensure appearance change is fully propagated
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.reloadTmuxTheme()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func reloadTmuxTheme() {
        let task = Process()
        let appearanceURL = URL(fileURLWithPath: "/Users/Morriz/.local/bin/appearance")
        task.executableURL = appearanceURL
        task.arguments = ["reload"]
        var env = ProcessInfo.processInfo.environment
        env["APPEARANCE_LOG"] = "1"
        let logURL = appearanceURL.resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .appendingPathComponent("appearance.log")
        env["APPEARANCE_LOG_FILE"] = logURL.path
        task.environment = env

        do {
            log("running appearance reload")
            try task.run()
            task.waitUntilExit()
            log("appearance reload exited status=\(task.terminationStatus)")
        } catch {
            log("appearance reload failed error=\(error)")
        }
    }
}

// Create watcher and run forever
let watcher = AppearanceWatcher()
print("Watching for appearance changes... (Ctrl+C to stop)")
RunLoop.main.run()
