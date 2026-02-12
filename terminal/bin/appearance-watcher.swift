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
    private var lastKnownMode: String?

    private func log(_ message: String) {
        let ts = logDateFormatter.string(from: Date())
        print("[\(ts)] \(message)")
        fflush(stdout)
    }

    init() {
        log("started")
        lastKnownMode = detectMode()
        if let mode = lastKnownMode {
            log("initial mode=\(mode)")
        } else {
            log("initial mode=unknown")
        }
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
        // Debounce bursty notifications and resolve the post-switch mode before reload.
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.reloadWithResolvedMode()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func detectMode() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/Users/Morriz/.local/bin/appearance")
        task.arguments = ["get-mode"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let mode = text, mode == "dark" || mode == "light" else { return nil }
            return mode
        } catch {
            return nil
        }
    }

    private func resolveModeAfterChange() -> String? {
        // Mode propagation can lag the notification; wait briefly for it to settle.
        let previous = lastKnownMode
        var observed: String?
        for _ in 0..<12 {
            observed = detectMode()
            if let mode = observed, mode != previous {
                return mode
            }
            usleep(250_000)
        }
        return observed
    }

    private func reloadWithResolvedMode() {
        let resolvedMode = resolveModeAfterChange()
        if let resolvedMode {
            log("resolved mode=\(resolvedMode)")
        } else {
            log("resolved mode=unknown")
        }
        reloadTmuxTheme(modeOverride: resolvedMode)
        if let resolvedMode {
            lastKnownMode = resolvedMode
        }
    }

    func reloadTmuxTheme(modeOverride: String?) {
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
        if let modeOverride {
            env["APPEARANCE_MODE"] = modeOverride
        }
        task.environment = env

        do {
            if let modeOverride {
                log("running appearance reload mode=\(modeOverride)")
            } else {
                log("running appearance reload")
            }
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
