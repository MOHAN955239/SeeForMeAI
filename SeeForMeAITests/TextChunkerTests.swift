import XCTest
@testable import SeeForMeAI

final class TextChunkerTests: XCTestCase {
    func testParagraphsSplit() { XCTAssertEqual(TextChunker.chunks("One.\n\nTwo."), ["One.", "Two."]) }
    func testLongParagraphSplitsOnSentences() {
        let s = (1...20).map { "This is sentence number \($0)." }.joined(separator: " ")
        let c = TextChunker.chunks(s, maxLength: 100)
        XCTAssertGreaterThan(c.count, 1)
        XCTAssertTrue(c.allSatisfy { $0.count <= 100 })
    }
    func testEmpty() { XCTAssertTrue(TextChunker.chunks("  \n\n ").isEmpty) }
}
