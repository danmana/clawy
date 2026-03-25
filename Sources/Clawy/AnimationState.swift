import Foundation

enum AnimationState: String, CaseIterable {
    case idle
    case wave
    case alert       // PermissionRequest
    case thinking    // Claude is processing
    case walking

    var frameCount: Int {
        switch self {
        case .idle:     return 4
        case .wave:     return 6
        case .alert:    return 6
        case .thinking: return 4
        case .walking:  return 4
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .idle:     return 0.4
        case .wave:     return 0.15
        case .alert:    return 0.12
        case .thinking: return 0.5
        case .walking:  return 0.2
        }
    }

    /// Whether this animation loops or plays once then returns to idle
    var loops: Bool {
        switch self {
        case .idle:     return true
        case .wave:     return false
        case .alert:    return true
        case .thinking: return true
        case .walking:  return true
        }
    }
}
