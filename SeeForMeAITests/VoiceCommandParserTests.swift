import XCTest
@testable import SeeForMeAI

final class VoiceCommandParserTests: XCTestCase {
    func testCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("Describe this scene."), .describeScene)
        XCTAssertEqual(VoiceCommandParser.parse("What is in front of me?"), .describeScene)
        XCTAssertEqual(VoiceCommandParser.parse("Read this text"), .readText)
        XCTAssertEqual(VoiceCommandParser.parse("Explain the image in more detail"), .explainMore)
        XCTAssertEqual(VoiceCommandParser.parse("Repeat that"), .repeatLast)
        XCTAssertEqual(VoiceCommandParser.parse("Stop speaking."), .stopSpeaking)
        XCTAssertEqual(VoiceCommandParser.parse("stop"), .stopSpeaking)
    }
    func testColorQuestionPassesThrough() {
        XCTAssertEqual(VoiceCommandParser.parse("What color is this object?"), .question("What color is this object?"))
    }
}

extension VoiceCommandParserTests {
    func testTimerAndReminder() {
        XCTAssertEqual(VoiceCommandParser.parse("Set a timer for 10 minutes"), .setTimer(seconds: 600, label: "Timer"))
        XCTAssertEqual(VoiceCommandParser.parse("set a timer for five minutes"), .setTimer(seconds: 300, label: "Timer"))
        XCTAssertEqual(VoiceCommandParser.parse("remind me in 20 minutes to call home"), .remind(seconds: 1200, text: "call home"))
    }
    func testLists() {
        XCTAssertEqual(VoiceCommandParser.parse("add milk to my shopping list"), .addNote(.shopping, text: "milk", amount: nil))
        XCTAssertEqual(VoiceCommandParser.parse("read my shopping list"), .readList(.shopping))
        XCTAssertEqual(VoiceCommandParser.parse("I spent 250 on groceries"), .addNote(.budget, text: "groceries", amount: 250))
        XCTAssertEqual(VoiceCommandParser.parse("I left my keys on the hall table"), .addNote(.lastSeen, text: "I left my keys on the hall table", amount: nil))
        XCTAssertEqual(VoiceCommandParser.parse("where are my keys?"), .whereIsMy("keys"))
    }
    func testSteps() {
        XCTAssertEqual(VoiceCommandParser.parse("next step"), .nextStep)
        XCTAssertEqual(VoiceCommandParser.parse("previous step"), .previousStep)
    }
    func testFeaturePhrasesAndInput() {
        XCTAssertEqual(VoiceCommandParser.parse("find my cup"), .runFeature(id: "find-object", input: "cup"))
        XCTAssertEqual(VoiceCommandParser.parse("read the menu"), .runFeature(id: "menu", input: nil))
        XCTAssertEqual(VoiceCommandParser.parse("find the door"), .runFeature(id: "door-window", input: nil))
        XCTAssertEqual(VoiceCommandParser.parse("spell necessary"), .runFeature(id: "spelling", input: "necessary"))
    }
}

extension VoiceCommandParserTests {
    func testCalendarBriefingContacts() {
        XCTAssertEqual(VoiceCommandParser.parse("What's on my calendar?"), .calendar)
        XCTAssertEqual(VoiceCommandParser.parse("Give me my daily briefing"), .briefing)
        XCTAssertEqual(VoiceCommandParser.parse("phone number for Priya"), .findContact("priya"))
    }
}

final class ContactsSpokenTests: XCTestCase {
    func testSpoken() {
        XCTAssertEqual(ContactsService.spoken([]), "I could not find that contact.")
        XCTAssertEqual(ContactsService.spellDigits("+91 98765"), "plus 9 1 9 8 7 6 5")
        XCTAssertTrue(ContactsService.spoken([ContactMatch(name: "Priya", numbers: [])]).contains("no phone number"))
    }
}
