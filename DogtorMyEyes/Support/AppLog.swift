import Foundation
#if canImport(os)
import os
#endif

/// Thin wrapper over `os.Logger`. Only log app/catalog diagnostics here — never user input, favorites, or appointments.
struct AppLog {
    static let data = AppLog(category: "data")
    static let finder = AppLog(category: "finder")

    let category: String

    func error(_ message: String) {
        #if canImport(os)
        Logger(subsystem: "com.demo.DogtorMyEyes", category: category).error("\(message, privacy: .public)")
        #else
        FileHandle.standardError.write(Data("[\(category)] \(message)\n".utf8))
        #endif
    }

    func info(_ message: String) {
        #if canImport(os)
        Logger(subsystem: "com.demo.DogtorMyEyes", category: category).info("\(message, privacy: .public)")
        #endif
    }
}
