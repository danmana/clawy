import Foundation

/// Reads config from ~/.clawy/config.json
struct Config {
    var idleWalk: Bool = true
    var lastX: Double? = nil  // nil = use default position

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
        return config
    }

    func save() {
        var json: [String: Any] = ["idle_walk": idleWalk]
        if let lastX {
            json["last_x"] = lastX
        }
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: Self.configFile)
        }
    }
}
