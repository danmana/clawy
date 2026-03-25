import Foundation

/// Manages installing/removing Clawy hooks in Claude Code settings.json
struct HookInstaller {

    static let settingsFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    static let hookEvents = ["Notification", "PreToolUse", "PostToolUse", "Stop", "UserPromptSubmit"]

    /// Path to the hook script, found by walking up from the executable
    static var hookScriptPath: String {
        // Check inside .app bundle first (Resources/hooks/clawy-hook.sh)
        if let bundlePath = Bundle.main.path(forResource: "clawy-hook", ofType: "sh", inDirectory: "hooks") {
            return bundlePath
        }

        // Walk up from executable to find hooks/clawy-hook.sh (dev mode)
        var dir = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()

        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("hooks/clawy-hook.sh").path
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }

        NSLog("Clawy: WARNING - could not find hooks/clawy-hook.sh")
        return "hooks/clawy-hook.sh"
    }

    static func install() {
        var settings = loadSettings()

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let hookEntry: [String: Any] = [
            "matcher": "",
            "hooks": [["type": "command", "command": hookScriptPath]]
        ]

        for event in hookEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            let alreadyInstalled = entries.contains { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["command"] as? String)?.contains("clawy-hook.sh") == true
                }
            }
            if !alreadyInstalled {
                entries.append(hookEntry)
                hooks[event] = entries
            }
        }

        settings["hooks"] = hooks
        saveSettings(settings)
        NSLog("Clawy: Hooks installed")
    }

    static func uninstall() {
        var settings = loadSettings()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in hookEvents {
            guard var entries = hooks[event] as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                return innerHooks.contains { h in
                    (h["command"] as? String)?.contains("clawy-hook.sh") == true
                }
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = entries
            }
        }

        if (hooks as NSDictionary).count == 0 {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        saveSettings(settings)
        NSLog("Clawy: Hooks uninstalled")
    }

    // MARK: - Private

    private static func loadSettings() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private static func saveSettings(_ settings: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsFile)
        }
    }
}
