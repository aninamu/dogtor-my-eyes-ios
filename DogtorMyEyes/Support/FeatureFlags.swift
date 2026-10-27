import Foundation

enum FeatureFlag: String, CaseIterable {
    case phase1Finder

    var defaultValue: Bool {
        switch self {
        case .phase1Finder:
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }

    var defaultsKey: String { "FeatureFlag.\(rawValue)" }
}

/// Resolution order: launch argument (`--enable-<flag>` / `--disable-<flag>`), then UserDefaults, then the flag's default.
/// UserDefaults also picks up `-FeatureFlag.<flag> YES` launch arguments through the argument domain.
struct FeatureFlags {
    private let defaults: UserDefaults
    private let arguments: [String]

    init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        self.arguments = arguments
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        if arguments.contains("--disable-\(flag.rawValue)") { return false }
        if arguments.contains("--enable-\(flag.rawValue)") { return true }
        if defaults.object(forKey: flag.defaultsKey) != nil {
            return defaults.bool(forKey: flag.defaultsKey)
        }
        return flag.defaultValue
    }

    func set(_ flag: FeatureFlag, enabled: Bool?) {
        if let enabled {
            defaults.set(enabled, forKey: flag.defaultsKey)
        } else {
            defaults.removeObject(forKey: flag.defaultsKey)
        }
    }
}
