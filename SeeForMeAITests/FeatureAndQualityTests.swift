import XCTest
@testable import SeeForMeAI

@MainActor
final class FeatureAndQualityTests: XCTestCase {
    func testCatalogIDsUniqueAndNonEmpty() {
        let ids = FeatureCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThan(ids.count, 40)
    }
    func testAIFeaturesHaveInstructions() {
        for f in FeatureCatalog.all {
            switch f.engine {
            case .vision, .textAI, .textOnly: XCTAssertFalse(f.instruction.isEmpty, f.id)
            default: break
            }
            if f.instruction.contains("{input}") { XCTAssertNotNil(f.inputPrompt, f.id) }
        }
    }
    func testHazardAndSensitiveFeaturesCarryCautions() {
        for id in ["obstacles", "stairs", "curb", "crossing", "smoke-fire", "doorway", "medicine", "currency", "food", "plant"] {
            XCTAssertNotNil(FeatureCatalog.feature(id)?.caution, id)
        }
        for f in FeatureCatalog.features(in: .hazards) { XCTAssertNotNil(f.caution, f.id) }
    }
    func testNoFeatureInstructionPromisesSafety() {
        for f in FeatureCatalog.all {
            let t = f.instruction.lowercased()
            XCTAssertFalse(t.contains("is safe to") && !t.contains("never"), f.id)
        }
    }
    func testResolvedInstruction() {
        XCTAssertTrue(FeatureCatalog.feature("find-object")!.resolvedInstruction(input: "cup").contains("cup"))
    }

    func testQualityDarkBrightBlur() {
        let n = 32 * 32
        XCTAssertFalse(PhotoQualityChecker.analyze(gray: [UInt8](repeating: 10, count: n), width: 32, height: 32).isGood)
        XCTAssertFalse(PhotoQualityChecker.analyze(gray: [UInt8](repeating: 250, count: n), width: 32, height: 32).isGood)
        // flat mid-grey = no edges = looks blurry
        XCTAssertTrue(PhotoQualityChecker.analyze(gray: [UInt8](repeating: 128, count: n), width: 32, height: 32).tips.first?.contains("blurry") == true)
        // checkerboard = strong edges = sharp
        var checker = [UInt8](); for y in 0..<32 { for x in 0..<32 { checker.append((x + y) % 2 == 0 ? 60 : 200) } }
        XCTAssertTrue(PhotoQualityChecker.analyze(gray: checker, width: 32, height: 32).isGood)
    }

    func testStyleInstruction() {
        let s = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertNil(s.languageID.hasPrefix("en") && s.verbosity == .normal ? s.styleInstruction : nil)
        s.verbosity = .brief; s.languageID = "kn-IN"
        XCTAssertTrue(s.styleInstruction!.contains("Kannada"))
        XCTAssertTrue(s.styleInstruction!.contains("short"))
    }
    func testFavoritesToggle() {
        let s = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        s.toggleFavorite("menu"); XCTAssertEqual(s.favoriteIDs, ["menu"])
        s.toggleFavorite("menu"); XCTAssertTrue(s.favoriteIDs.isEmpty)
    }

    func testNoteListStore() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let s = NoteListStore(fileURL: url)
        s.add(.shopping, text: "milk"); s.add(.budget, text: "groceries", amount: 250); s.add(.budget, text: "bus", amount: 20)
        s.add(.lastSeen, text: "keys on the hall table")
        XCTAssertEqual(s.budgetTotal(), 270)
        XCTAssertEqual(s.find("keys").count, 1)
        XCTAssertEqual(NoteListStore(fileURL: url).items(.shopping).first?.text, "milk")   // persisted
        s.delete(.shopping, id: s.items(.shopping)[0].id); XCTAssertTrue(s.items(.shopping).isEmpty)
        s.clearAll(); XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testTimerDescribe() {
        XCTAssertEqual(TimerService.describe(90), "1 minute 30 seconds")
        XCTAssertEqual(TimerService.describe(3600), "1 hour")
    }

    func testBarcodeSpokenHandlesMissingProduct() {
        XCTAssertTrue(BarcodeService.spoken(code: "123", response: nil).contains("not in the public product database"))
        let r = BarcodeService.Response(status: 1, product: .init(product_name: "Oats", brands: "Acme", quantity: "500 g"))
        XCTAssertTrue(BarcodeService.spoken(code: "123", response: r).contains("Oats"))
    }

    func testPromptIncludesInstructionAndStyle() {
        let r = AnalysisRequest(imageJPEG: nil, contextText: nil, question: nil, history: [], detailed: false,
                                instruction: "Read the price tag.", style: "Keep it short.")
        let p = ClaudeVisionProvider.currentPrompt(for: r)
        XCTAssertTrue(p.contains("Read the price tag.") && p.contains("Keep it short."))
    }
}
