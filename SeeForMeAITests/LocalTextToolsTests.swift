import XCTest
@testable import SeeForMeAI

final class LocalTextToolsTests: XCTestCase {
    func testExpiryNextToKeyword() {
        let s = LocalTextTools.expiry(from: "MFG 01/2024\nBEST BEFORE 12/03/2026\nBatch 22")
        XCTAssertTrue(s?.contains("12/03/2026") == true)
    }
    func testExpiryWithoutKeywordIsHedged() {
        let s = LocalTextTools.expiry(from: "Packed 05/01/2025")
        XCTAssertTrue(s?.contains("none were next to an expiry word") == true)
    }
    func testExpiryNone() { XCTAssertNil(LocalTextTools.expiry(from: "Hello world")) }

    func testReceiptTotalAndItems() {
        let r = LocalTextTools.receipt(from: "Milk 45.00\nBread 30.00\nSubtotal 75.00\nGST 3.75\nTOTAL 78.75")
        XCTAssertEqual(r.total, "78.75")
        XCTAssertEqual(r.items.count, 2)
        XCTAssertNotNil(LocalTextTools.receiptSpoken(r))
    }
    func testReceiptGrandTotalWins() {
        let r = LocalTextTools.receipt(from: "Total 10.00\nGrand Total ₹12.00")
        XCTAssertEqual(r.total, "₹12.00")
    }
    func testPrices() {
        XCTAssertEqual(LocalTextTools.prices(from: "Rice ₹120"), "The price shown is ₹120.")
        XCTAssertNil(LocalTextTools.prices(from: "no numbers here"))
    }
    func testRecipeStepsSplitOnNumbers() {
        let steps = LocalTextTools.recipeSteps(from: ["1. Boil water. 2. Add pasta. 3. Drain."])
        XCTAssertEqual(steps.count, 3)
        XCTAssertTrue(steps[1].contains("Add pasta"))
    }
    func testRecipeStepsFallBackToParagraphs() {
        XCTAssertEqual(LocalTextTools.recipeSteps(from: ["Mix well.", "Bake."]).count, 2)
    }
    func testSpell() { XCTAssertEqual(LocalTextTools.spell("cat"), "cat: C, A, T.") }

    @MainActor func testStepReader() {
        let r = StepReader()
        XCTAssertTrue(r.next().contains("No recipe"))
        r.load(["a", "b"])
        XCTAssertTrue(r.current!.contains("Step 1 of 2"))
        XCTAssertTrue(r.next().contains("Step 2 of 2"))
        XCTAssertEqual(r.next(), "That was the last step.")
        XCTAssertTrue(r.previous().contains("Step 1 of 2"))
    }
}
