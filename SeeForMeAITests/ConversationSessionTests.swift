import XCTest
import UIKit
@testable import SeeForMeAI

final class ConversationSessionTests: XCTestCase {
    private func img() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 40, height: 40)) }
    }
    func testNewImageClearsTurnsAndText() throws {
        let s = ConversationSession()
        try s.setImage(img()); s.setContextText("hi"); s.append(user: "a", assistant: "b")
        try s.setImage(img())
        XCTAssertTrue(s.turns.isEmpty); XCTAssertNil(s.contextText); XCTAssertTrue(s.hasContext)
    }
    func testTurnsCapped() {
        let s = ConversationSession()
        for i in 0..<20 { s.append(user: "q\(i)", assistant: "a\(i)") }
        XCTAssertEqual(s.turns.count, ConversationSession.maxTurns)
        XCTAssertEqual(s.turns.last?.text, "a19")
    }
    func testResetClearsEverything() throws {
        let s = ConversationSession(); try s.setImage(img()); s.reset()
        XCTAssertFalse(s.hasContext); XCTAssertNil(s.image)
    }
}
