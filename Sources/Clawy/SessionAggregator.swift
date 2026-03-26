import Foundation

/// Represents the state of a single Claude Code session.
struct SessionState {
    let sessionId: String
    let state: AnimationState
    let toolName: String?
    let command: String?
    let terminalPid: Int32
    let timestamp: TimeInterval
}

/// Aggregated state across all sessions, with priority logic.
struct AggregatedState {
    let animationState: AnimationState
    let toolName: String?
    let command: String?
    let terminalPid: Int32
    let alertCount: Int  // Number of sessions waiting for permission
}

/// Watches ~/.clawy/sessions/ and aggregates state from all Claude Code sessions.
/// Priority: alert > thinking > wave > idle
class SessionAggregator {

    static let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".clawy/sessions")

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var onChange: (AggregatedState) -> Void
    private var pollTimer: Timer?

    init(onChange: @escaping (AggregatedState) -> Void) {
        self.onChange = onChange
    }

    func start() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.sessionsDir, withIntermediateDirectories: true)

        // Watch the sessions directory for changes
        fileDescriptor = open(Self.sessionsDir.path, O_RDONLY)
        guard fileDescriptor >= 0 else {
            NSLog("Clawy: Could not open sessions directory for watching")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .link],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.readAndAggregate()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        source?.resume()

        // Also poll periodically since directory watching can miss file content changes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.readAndAggregate()
        }

        NSLog("Clawy: Watching sessions at \(Self.sessionsDir.path)")
    }

    func stop() {
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private var lastAggregatedState: String = ""

    private func readAndAggregate() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: Self.sessionsDir, includingPropertiesForKeys: nil)
        else { return }

        var sessions: [SessionState] = []
        let now = Date().timeIntervalSince1970
        let staleThreshold: TimeInterval = 60  // Ignore sessions older than 60s

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stateStr = json["state"] as? String,
                  let state = AnimationState(rawValue: stateStr),
                  let timestamp = json["timestamp"] as? TimeInterval
            else { continue }

            // Skip stale sessions (except alerts which persist until resolved)
            if state != .alert && (now - timestamp) > staleThreshold {
                continue
            }

            let sessionId = file.deletingPathExtension().lastPathComponent
            sessions.append(SessionState(
                sessionId: sessionId,
                state: state,
                toolName: json["tool"] as? String,
                command: json["command"] as? String,
                terminalPid: Int32(json["terminal_pid"] as? Int ?? 0),
                timestamp: timestamp
            ))
        }

        let aggregated = aggregate(sessions: sessions)

        // Only notify if something changed
        let stateKey = "\(aggregated.animationState)|\(aggregated.toolName ?? "")|\(aggregated.command ?? "")|\(aggregated.alertCount)"
        if stateKey != lastAggregatedState {
            lastAggregatedState = stateKey
            onChange(aggregated)
        }
    }

    private func aggregate(sessions: [SessionState]) -> AggregatedState {
        // Find all alert sessions (permission pending)
        let alerts = sessions.filter { $0.state == .alert }
            .sorted { $0.timestamp < $1.timestamp }  // Oldest first

        if let first = alerts.first {
            return AggregatedState(
                animationState: .alert,
                toolName: first.toolName,
                command: first.command,
                terminalPid: first.terminalPid,
                alertCount: alerts.count
            )
        }

        // Find thinking sessions
        let thinking = sessions.filter { $0.state == .thinking }
            .sorted { $0.timestamp > $1.timestamp }  // Most recent first

        if let first = thinking.first {
            return AggregatedState(
                animationState: .thinking,
                toolName: first.toolName,
                command: first.command,
                terminalPid: first.terminalPid,
                alertCount: 0
            )
        }

        // Find wave (session just stopped)
        let waving = sessions.filter { $0.state == .wave }
            .sorted { $0.timestamp > $1.timestamp }

        if let first = waving.first {
            return AggregatedState(
                animationState: .wave,
                toolName: nil,
                command: nil,
                terminalPid: first.terminalPid,
                alertCount: 0
            )
        }

        // Default: idle, use most recently active terminal
        let latest = sessions.sorted { $0.timestamp > $1.timestamp }.first
        return AggregatedState(
            animationState: .idle,
            toolName: nil,
            command: nil,
            terminalPid: latest?.terminalPid ?? 0,
            alertCount: 0
        )
    }
}
