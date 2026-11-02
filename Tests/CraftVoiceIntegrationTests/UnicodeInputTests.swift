import Testing
import CoreGraphics
@testable import CraftVoiceIntegration

struct UnicodeInputTests {
    @Test func chunksPreserveLongGermanTextAndSurrogates() throws {
        let text = String(repeating: "Grüße 😀 ÄÖÜß! ", count: 8)
        let chunks = try #require(UnicodeInputPayload.chunks(text))
        #expect(chunks.allSatisfy { $0.count <= 20 && !$0.isEmpty })
        #expect(String(decoding: chunks.flatMap { $0 }, as: UTF16.self) == text)
        #expect(chunks.allSatisfy { !(0xD800...0xDBFF).contains($0.last!) && !(0xDC00...0xDFFF).contains($0.first!) })
        #expect(UnicodeInputPayload.chunks("escape\u{1B}") == nil)
    }
    @Test func unicodeEventsHaveNoShortcutFlagsOrReturnKey() throws {
        let events = try #require(UnicodeInputPayload.events("Grüße 😀 Zweite Zeile"))
        for (down, up) in events {
            #expect(down.type == .keyDown); #expect(up.type == .keyUp)
            #expect(down.flags.isEmpty); #expect(up.flags.isEmpty)
            #expect(down.getIntegerValueField(.keyboardEventKeycode) == 0)
            #expect(up.getIntegerValueField(.keyboardEventKeycode) == 0)
        }
    }
    @Test func longQuartzPayloadRoundTripsCompletelyWithoutDuplicateDownEvents() throws {
        let text = String(repeating: "Grüße aus Köln, Maßprüfung 12,5 mm und Emoji 😀. ", count: 256)
        let chunks = try #require(UnicodeInputPayload.chunks(text))
        let events = try #require(UnicodeInputPayload.events(text))
        #expect(events.count == chunks.count)
        var reconstructed: [UniChar] = []
        for (index, pair) in events.enumerated() {
            for event in [pair.0, pair.1] {
                var length = 0
                var units = [UniChar](repeating: 0, count: 32)
                event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
                #expect(Array(units.prefix(length)) == chunks[index])
                #expect(event.getIntegerValueField(.keyboardEventAutorepeat) == 0)
                if event.type == .keyDown { reconstructed.append(contentsOf: units.prefix(length)) }
            }
        }
        #expect(reconstructed == Array(text.utf16))
    }

}
