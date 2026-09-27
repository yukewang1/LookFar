import XCTest
@testable import RestCore

final class DiagnosticLogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testPersistsAcrossInstancesAndCombinesProcessLogsChronologically() throws {
        let app = DiagnosticLog(directory: directory, source: "app")
        let monitor = DiagnosticLog(directory: directory, source: "monitor")
        let early = DiagnosticEvent(source: "app", name: "register", details: "", date: Date(timeIntervalSince1970: 100))
        let later = DiagnosticEvent(source: "monitor", name: "callback", details: "minute=1", date: Date(timeIntervalSince1970: 160))
        try monitor.append(later)
        try app.append(early)
        let latest = DiagnosticEvent(source: "app", name: "refresh", details: "", date: Date(timeIntervalSince1970: 200))
        try DiagnosticLog(directory: directory, source: "app").append(latest)

        XCTAssertEqual(try DiagnosticLog.read(directory: directory), [early, later, latest])
    }

    func testRetentionIsBoundedPerProcessAndKeepsNewestEvents() throws {
        let app = DiagnosticLog(directory: directory, source: "app")
        let monitor = DiagnosticLog(directory: directory, source: "monitor")
        let callback = DiagnosticEvent(source: "monitor", name: "callback", details: "")
        try monitor.append(callback)
        for index in 0..<(DiagnosticLog.capacity + 3) {
            try app.append(DiagnosticEvent(source: "app", name: "event", details: "\(index)", date: Date(timeIntervalSince1970: Double(index))))
        }
        let events = try DiagnosticLog.read(directory: directory)
        XCTAssertEqual(events.count, DiagnosticLog.capacity + 1)
        XCTAssertEqual(events.first?.details, "3")
        XCTAssertTrue(events.contains(callback))
    }

    func testMissingLogsAreEmptyButCorruptLogsAreReportedAndNotOverwritten() throws {
        XCTAssertTrue(try DiagnosticLog.read(directory: directory).isEmpty)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("app.json")
        let corrupt = Data("invalid".utf8)
        try corrupt.write(to: file)
        XCTAssertThrowsError(try DiagnosticLog.read(directory: directory))
        XCTAssertThrowsError(try DiagnosticLog(directory: directory, source: "app").append(
            DiagnosticEvent(source: "app", name: "event", details: "")
        ))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
}
