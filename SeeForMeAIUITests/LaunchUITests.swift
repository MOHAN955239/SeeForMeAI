import XCTest

final class LaunchUITests: XCTestCase {
    func testHomeShowsFourPrimaryActions() {
        let app = XCUIApplication(); app.launch()
        for name in ["Describe Scene", "Read Text", "Ask a Question", "Recent Results"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5), "\(name) missing")
        }
    }
    func testNavigateToReaderShowsImageSources() {
        let app = XCUIApplication(); app.launch()
        app.buttons["Read Text"].tap()
        XCTAssertTrue(app.buttons["Choose Photo"].waitForExistence(timeout: 5))
    }
}
