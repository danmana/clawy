import Foundation

/// Parsed status from the hook file.
struct HookStatus {
    let state: AnimationState
    let toolName: String?   // e.g. "Bash", "Write", "Edit"
    let command: String?    // e.g. "rm", "git", "curl" (first word of Bash command)
}

/// Watches ~/.clawd-pet/status for changes written by Claude Code hooks.
/// Format: "state" or "state|tool_name|command"
class HookWatcher {

    static let statusDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".clawd-pet")
    static let statusFile = statusDir.appendingPathComponent("status")

    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var onChange: (HookStatus) -> Void

    init(onChange: @escaping (HookStatus) -> Void) {
        self.onChange = onChange
    }

    func start() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.statusDir, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: Self.statusFile.path) {
            fm.createFile(atPath: Self.statusFile.path, contents: "idle\n".data(using: .utf8))
        }

        fileDescriptor = open(Self.statusFile.path, O_RDONLY)
        guard fileDescriptor >= 0 else {
            print("Clawy: Could not open status file for watching")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.readStatus()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        source?.resume()
        print("Clawy: Watching \(Self.statusFile.path)")
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func readStatus() {
        guard let content = try? String(contentsOf: Self.statusFile, encoding: .utf8) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse format: "state|tool_name|command" or just "state"
        let parts = trimmed.split(separator: "|", maxSplits: 2).map(String.init)
        let stateStr = parts[0].lowercased()

        guard let state = AnimationState(rawValue: stateStr) else { return }

        let toolName = parts.count > 1 ? parts[1] : nil
        let command = parts.count > 2 ? parts[2] : nil

        onChange(HookStatus(state: state, toolName: toolName, command: command))
    }

    static func writeStatus(_ state: AnimationState) {
        try? state.rawValue.write(to: statusFile, atomically: true, encoding: .utf8)
    }
}
