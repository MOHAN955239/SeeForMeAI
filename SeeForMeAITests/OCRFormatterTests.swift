import XCTest
@testable import SeeForMeAI

final class OCRFormatterTests: XCTestCase {
    private func line(_ t: String, y: CGFloat, x: CGFloat = 0.1, c: Float = 0.9) -> OCRLine {
        OCRLine(text: t, box: CGRect(x: x, y: y, width: 0.3, height: 0.03), confidence: c)
    }
    func testEmptyReturnsNil() {
        XCTAssertNil(OCRFormatter.format([]))
        XCTAssertNil(OCRFormatter.format([line("   ", y: 0.5)]))
    }
    func testTopToBottomOrder() {
        let r = OCRFormatter.format([line("second", y: 0.80), line("first", y: 0.85)])!
        XCTAssertEqual(r.text, "first second")
    }
    func testSameRowLeftToRight() {
        let r = OCRFormatter.format([line("world", y: 0.5, x: 0.5), line("hello", y: 0.5, x: 0.1)])!
        XCTAssertEqual(r.text, "hello world")
    }
    func testParagraphBreakOnLargeGap() {
        let r = OCRFormatter.format([line("A", y: 0.9), line("B", y: 0.5)])!
        XCTAssertEqual(r.paragraphs, ["A", "B"])
    }
    func testLowConfidenceAddsGuidance() {
        XCTAssertNotNil(OCRFormatter.format([line("x", y: 0.5, c: 0.2)])!.guidance)
        XCTAssertNil(OCRFormatter.format([line("x", y: 0.5, c: 0.95)])!.guidance)
    }
}
