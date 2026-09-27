import Foundation
import OSLog

enum MonitoringDiagnostics {
    private static let logger = Logger(subsystem: "dev.local.lookfar", category: "Diagnostics")
    private static let source = Bundle.main.bundleIdentifier ?? "unknown"
    private static let log = Result { DiagnosticLog(directory: try directory(), source: source) }

    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
    }

    private static func directory() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ScreenTimeSupport.appGroup) else {
            throw ScreenTimeFailure.sharedStorageUnavailable
        }
        return container.appendingPathComponent("MonitoringDiagnostics", isDirectory: true)
    }

    static func record(_ name: String, _ details: String = "") {
        logger.notice("\(name, privacy: .public): \(details, privacy: .public)")
        do { try log.get().append(DiagnosticEvent(source: source, name: name, details: details)) }
        catch {
            // Diagnostics must not interrupt a callback or prevent releasing a shield.
            // The diagnostics screen reports storage/read failures too.
            logger.error("Could not save diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func events() throws -> [DiagnosticEvent] {
        try DiagnosticLog.read(directory: directory())
    }
}
