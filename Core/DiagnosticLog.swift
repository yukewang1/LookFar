import Foundation

struct DiagnosticEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let source: String
    let name: String
    let details: String

    init(source: String, name: String, details: String, date: Date = .now) {
        id = UUID()
        self.date = date
        self.source = source
        self.name = name
        self.details = String(details.prefix(1_000))
    }
}

/// Each process owns one bounded file, so an extension cannot overwrite the app's events.
/// Atomic replacement also lets the app read while an extension is writing.
final class DiagnosticLog {
    static let capacity = 200
    private let directory: URL
    private let fileURL: URL
    private let lock = NSLock()

    init(directory: URL, source: String) {
        self.directory = directory
        fileURL = directory.appendingPathComponent(source).appendingPathExtension("json")
    }

    func append(_ event: DiagnosticEvent) throws {
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var events = FileManager.default.fileExists(atPath: fileURL.path)
            ? try JSONDecoder().decode([DiagnosticEvent].self, from: Data(contentsOf: fileURL)) : []
        events.append(event)
        try JSONEncoder().encode(Array(events.suffix(Self.capacity))).write(to: fileURL, options: .atomic)
    }

    static func read(directory: URL) throws -> [DiagnosticEvent] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .flatMap { try JSONDecoder().decode([DiagnosticEvent].self, from: Data(contentsOf: $0)) }
            .sorted { $0.date < $1.date }
    }
}
