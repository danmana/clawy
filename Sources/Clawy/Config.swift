import Foundation

enum PetSize: String {
    case small = "S"
    case medium = "M"
    case large = "L"

    var pixelSize: Int {
        switch self {
        case .small:  return 4
        case .medium: return 6
        case .large:  return 8
        }
    }
}

/// Reads config from ~/.clawy/config.json
struct Config {
    var idleWalk: Bool = true
    var lastX: Double? = nil
    var size: PetSize = .medium

    static let configFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".clawy/config.json")

    static func load() -> Config {
        var config = Config()
        guard let data = try? Data(contentsOf: configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            config.save()
            return config
        }
        if let idleWalk = json["idle_walk"] as? Bool {
            config.idleWalk = idleWalk
        }
        if let lastX = json["last_x"] as? Double {
            config.lastX = lastX
        }
        if let sizeStr = json["size"] as? String, let size = PetSize(rawValue: sizeStr) {
            config.size = size
        }
        return config
    }

    func save() {
        var json: [String: Any] = [
            "idle_walk": idleWalk,
            "size": size.rawValue,
        ]
        if let lastX {
            json["last_x"] = lastX
        }
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: Self.configFile)
        }
    }
}
