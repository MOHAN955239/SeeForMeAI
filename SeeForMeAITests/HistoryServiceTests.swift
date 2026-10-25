import XCTest
@testable import SeeForMeAI

@MainActor
final class HistoryServiceTests: XCTestCase {
    private var url: URL!
    private var defaults: UserDefaults!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }
    override func tearDown() { try? FileManager.default.removeItem(at: url) }

    func testOffByDefaultAndNothingWritten() {
        let h = HistoryService(fileURL: url, defaults: defaults)
        h.add(kind: .scene, summary: "x", spokenText: "x")
        XCTAssertTrue(h.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testPersistsWhenEnabled() {
        let h = HistoryService(fileURL: url, defaults: defaults); h.isEnabled = true
        h.add(kind: .text, summary: "hello", spokenText: "hello")
        XCTAssertEqual(HistoryService(fileURL: url, defaults: defaults).items.count, 1)
    }
    func testDeleteOne() {
        let h = HistoryService(fileURL: url, defaults: defaults); h.isEnabled = true
        h.add(kind: .scene, summary: "a", spokenText: "a"); h.add(kind: .scene, summary: "b", spokenText: "b")
        h.delete(id: h.items[0].id)
        XCTAssertEqual(h.items.map(\.summary), ["a"])
    }
    func testClearAllRemovesFile() {
        let h = HistoryService(fileURL: url, defaults: defaults); h.isEnabled = true
        h.add(kind: .scene, summary: "a", spokenText: "a"); h.clearAll()
        XCTAssertTrue(h.items.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testCap() {
        let h = HistoryService(fileURL: url, defaults: defaults); h.isEnabled = true
        for i in 0..<(HistoryService.maxItems + 5) { h.add(kind: .scene, summary: "\(i)", spokenText: "") }
        XCTAssertEqual(h.items.count, HistoryService.maxItems)
    }
}
