import AppKit
import Testing
import CraftVoiceCore
@testable import CraftVoiceIntegration

@MainActor private final class BoardDouble: ClipboardAccess {
    var count = 1
    var text = "vorher"
    var restores = 0
    var publishes = 0
    var refuses = false
    func snapshot() -> ClipboardSnapshot? {
        refuses ? nil : ClipboardSnapshot(changeCount: count, items: [["public.utf8-plain-text": Data(text.utf8)]])
    }
    func publish(_ text: String, replacing snapshot: ClipboardSnapshot) -> ClipboardOwnership? {
        guard count == snapshot.changeCount else { return nil }
        self.text = text; count += 1; publishes += 1
        return ClipboardOwnership(changeCount: count, marker: "owned")
    }
    func owns(_ ownership: ClipboardOwnership) -> Bool { count == ownership.changeCount }
    func restore(_ snapshot: ClipboardSnapshot, ownership: ClipboardOwnership) -> Bool {
        guard owns(ownership) else { return false }
        restores += 1; count += 1
        text = String(decoding: snapshot.items[0]["public.utf8-plain-text"]!, as: UTF8.self)
        return true
    }
}
@MainActor private final class TargetDouble: InsertionTargetAccess {
    let originalValue = "Vorher nachher"
    let insertionRange = NSRange(location: 7, length: 0)
    var direct = true
    var acceptsNewlines = true
    var unicodeResult = UnicodeDispatchResult.posted
    var unicodePosts = 0
    var onUnicode: (() -> Void)?
    var allowed = true
    var secureInput = false
    var canPost = false
    var matches = true
    var identity = true
    var confirmed = true
    var writeResult = DirectWriteResult.accepted
    var readbackOverride: InsertionReadback?
    var reads = 0
    var confirmAfter = 0
    var expectedOverride: String?
    var postSucceeds = true
    var writes = 0
    var posts = 0
    var onPost: (() -> Void)?
    var onWrite: (() -> Void)?
    func matchesOriginal() -> Bool { matches }
    func matchesIdentity() -> Bool { identity }
    func observeInsertion(expected: String, inserted: String) -> InsertionReadback {
        reads += 1
        if let readbackOverride { return readbackOverride }
        return confirmed && reads > confirmAfter && expected == (expectedOverride ?? "Vorher Diktatnachher") ? .confirmed : .unchanged
    }
    func writeSelectedText(_ text: String) -> DirectWriteResult { writes += 1; onWrite?(); return writeResult }
    func postPaste() -> Bool { posts += 1; onPost?(); return postSucceeds }
    func postUnicode(_ text: String) -> UnicodeDispatchResult { unicodePosts += 1; onUnicode?(); return unicodeResult }
}

@Suite @MainActor struct InsertionTests {
    @Test func directInsertionDoesNotUseClipboardAndCannotRepeat() async {
        let board = BoardDouble(); let target = TargetDouble()
        let service = TextInsertion(clipboard: board)
        var ticket = InsertionTicket()
        let first = await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        let second = await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(first == .inserted); #expect(second == .blocked)
        #expect(target.writes == 1); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test(arguments: [0, 1, 2, 3, 4]) func blocksUnsafeTarget(_ scenario: Int) async {
        let board = BoardDouble(); let target = TargetDouble()
        if scenario == 0 { target.matches = false }
        if scenario == 1 { target.allowed = false }
        if scenario == 2 { target.secureInput = true }
        var ticket = InsertionTicket()
        if scenario == 3 { ticket.invalidate() }
        let outcome = await TextInsertion(clipboard: board).insert(scenario == 4 ? " " : "Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(outcome == .blocked); #expect(target.writes == 0); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func neverFallsBackAfterUncertainDirectDispatch() async {
        let board = BoardDouble(); let target = TargetDouble(); target.writeResult = .indeterminate(-25204); target.readbackOverride = .targetLost
        var ticket = InsertionTicket()
        let result = await TextInsertion(clipboard: board).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(result == .uncertain); #expect(ticket.consumed)
        #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func capturedFieldReadbackCanConfirmAfterFocusMovesFollowingWrite() async {
        let board = BoardDouble(); let target = TargetDouble()
        target.onWrite = { target.identity = false }
        let service = TextInsertion(clipboard: board)
        var ticket = InsertionTicket()
        let result = await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(result == .inserted)
        #expect(target.writes == 1); #expect(target.posts == 0)
        #expect(board.publishes == 0)
    }
    @Test func explicitWriteRejectionIsFailureAndNeverRetriesOrFallsBack() async {
        let board = BoardDouble(); let target = TargetDouble(); target.writeResult = .rejected(-25205)
        let service = TextInsertion(clipboard: board)
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .writeRejected)
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.writes == 1); #expect(target.reads == 0)
        #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test(arguments: [InsertionReadback.unchanged, .different, .unreadable(-25204), .targetLost])
    func acceptedWriteWithoutProofIsUnverifiableNotFailed(_ readback: InsertionReadback) async {
        let board = BoardDouble(); let target = TargetDouble(); target.readbackOverride = readback
        let service = TextInsertion(clipboard: board)
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .acceptedUnverified)
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.writes == 1); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func ambiguousAXErrorCanStillBeConfirmedByCapturedFieldReadback() async {
        let target = TargetDouble(); target.writeResult = .indeterminate(-25204)
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble()).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .inserted)
        #expect(target.writes == 1); #expect(target.posts == 0)
    }
    @Test func delayedReadbackConfirmsWithoutAnotherWrite() async {
        let target = TargetDouble(); target.confirmAfter = 2
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble()).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .inserted)
        #expect(target.reads == 3); #expect(target.writes == 1)
    }
    @Test func focusLostBeforeWriteStillBlocksAllInput() async {
        let target = TargetDouble(); target.matches = false
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble()).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.writes == 0); #expect(target.reads == 0)
    }
    @Test func longDictationDispatchesOnlyOneBatchEvenWhenResultIsReadRepeatedly() async {
        let text = String(repeating: "Längeres Diktat mit Umlauten, Fachbegriffen und Zahlen 123. ", count: 256)
        let board = BoardDouble(); let target = TargetDouble(); target.canPost = true
        target.expectedOverride = ExpectedInsertion.replacing(value: target.originalValue, location: 7, length: 0, text: text)
        target.confirmAfter = 3
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        #expect(await service.insert(text, target: target, ticket: &ticket, allowClipboard: true) == .inserted)
        #expect(await service.insert(text, target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 1); #expect(target.reads == 4)
        #expect(target.writes == 0); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func unicodePrimaryNeverAttemptsAXOrClipboardAndCannotRepeat() async {
        let board = BoardDouble(); let target = TargetDouble(); target.canPost = true
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .inserted)
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 1); #expect(target.writes == 0); #expect(target.posts == 0)
        #expect(board.publishes == 0)
    }
    @Test(arguments: [UnicodeDispatchResult.partial, .posted])
    func unverifiedUnicodeNeverRetriesOrUsesAnotherMethod(_ result: UnicodeDispatchResult) async {
        let board = BoardDouble(); let target = TargetDouble(); target.canPost = true
        target.unicodeResult = result; target.readbackOverride = .targetLost
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == (result == .partial ? .interrupted : .inputUnverified))
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 1); #expect(target.writes == 0); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func unicodeRequiresExistingPostingPermissionAndOriginalFocus() async {
        let target = TargetDouble(); target.direct = false; target.canPost = false
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble(), modifiersReleased: { true }).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 0); #expect(target.writes == 0)
        target.canPost = true; target.matches = false
        var second = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble(), modifiersReleased: { true }).insert("Diktat", target: target, ticket: &second, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 0)
    }
    @Test func focusChangeWhileReleasingModifiersPreventsUnicodeDispatch() async {
        let target = TargetDouble(); target.canPost = true
        let service = TextInsertion(clipboard: BoardDouble(), modifiersReleased: { target.matches = false; return true })
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 0); #expect(target.writes == 0)
    }
    @Test func completePayloadProofDoesNotClaimOriginalStateAndCannotResend() async {
        let board = BoardDouble(); let target = TargetDouble(); target.canPost = true
        target.readbackOverride = .payloadPresent
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .payloadPresent)
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 1); #expect(target.writes == 0); #expect(board.publishes == 0)
    }
    @Test func zeroEventPreparationFailureAllowsExactlyOneAXFallback() async {
        let board = BoardDouble(); let target = TargetDouble(); target.canPost = true; target.unicodeResult = .notSent
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .inserted)
        #expect(await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.unicodePosts == 1); #expect(target.writes == 1); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func zeroEventsDoNotAuthorizeFallbackAfterFocusChange() async {
        let target = TargetDouble(); target.canPost = true; target.unicodeResult = .notSent
        target.onUnicode = { target.matches = false }
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble(), modifiersReleased: { true }).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .blocked)
        #expect(target.writes == 0); #expect(target.posts == 0)
    }
    @Test func postedButUnchangedIsNeverEvidenceOfNoInput() async {
        let board = BoardDouble(); let target = TargetDouble(); target.canPost = true; target.readbackOverride = .unchanged
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: board, modifiersReleased: { true }).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .inputUnverified)
        #expect(target.unicodePosts == 1); #expect(target.writes == 0); #expect(target.posts == 0); #expect(board.publishes == 0)
    }
    @Test func interruptedDispatchCannotBeDeclaredSuccessfulByLaterReadback() async {
        let target = TargetDouble(); target.canPost = true; target.unicodeResult = .partial
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble(), modifiersReleased: { true }).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true) == .interrupted)
        #expect(target.unicodePosts == 1); #expect(target.writes == 0)
    }
    @Test func multilineUsesLiteralAXWithoutKeyboardOrClipboardWhenNotOptedIn() async {
        let target = TargetDouble(); target.canPost = true
        let text = "Erste Zeile\nZweite Zeile"
        target.expectedOverride = ExpectedInsertion.replacing(value: target.originalValue, location: 7, length: 0, text: text)
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble()).insert(text, target: target, ticket: &ticket, allowClipboard: false) == .inserted)
        #expect(target.unicodePosts == 0); #expect(target.writes == 1); #expect(target.posts == 0)
    }
    @Test func singleLineRejectsNewlinesWithoutAnyMutation() async {
        let target = TargetDouble(); target.canPost = true; target.acceptsNewlines = false
        var ticket = InsertionTicket()
        #expect(await TextInsertion(clipboard: BoardDouble()).insert("eins\nzwei", target: target, ticket: &ticket, allowClipboard: true) == .unsupportedPayload)
        #expect(target.unicodePosts == 0); #expect(target.writes == 0); #expect(target.posts == 0)
    }
    @Test func confirmedPasteRestoresClipboardOnce() async {
        let board = BoardDouble(); let target = TargetDouble(); target.direct = false; target.canPost = true; target.unicodeResult = .notSent
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        let result = await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(result == .inserted); #expect(target.posts == 1)
        #expect(board.restores == 1); #expect(board.text == "vorher"); #expect(service.pendingClipboard == nil)
    }
    @Test func changedClipboardIsNeverOverwritten() async {
        let board = BoardDouble(); let target = TargetDouble(); target.direct = false; target.canPost = true; target.unicodeResult = .notSent
        target.onPost = { board.text = "fremde Kopie"; board.count += 1 }
        var ticket = InsertionTicket()
        let result = await TextInsertion(clipboard: board, modifiersReleased: { true }).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(result == .inserted); #expect(board.text == "fremde Kopie"); #expect(board.restores == 0)
    }
    @Test func uncertainPasteRequiresExplicitRestoreAndCannotRetry() async {
        let board = BoardDouble(); let target = TargetDouble(); target.direct = false; target.canPost = true; target.unicodeResult = .notSent
        target.confirmed = false; target.identity = false
        let service = TextInsertion(clipboard: board, modifiersReleased: { true })
        var ticket = InsertionTicket()
        let first = await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        let second = await service.insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(first == .clipboardUnrestored); #expect(second == .blocked)
        #expect(board.restores == 0); #expect(target.posts == 1)
        let restored = service.restoreClipboard()
        #expect(restored); #expect(board.text == "vorher")
    }
    @Test func noPostingWhenClipboardRefusesSnapshot() async {
        let board = BoardDouble(); board.refuses = true
        let target = TargetDouble(); target.direct = false; target.canPost = true; target.unicodeResult = .notSent
        var ticket = InsertionTicket()
        let result = await TextInsertion(clipboard: board, modifiersReleased: { true }).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        #expect(result == .clipboardChanged); #expect(target.posts == 0)
    }
    @Test(arguments: [false, true]) func fallbackRequiresBothUserChoiceAndPostingPermission(_ permission: Bool) async {
        let target = TargetDouble(); target.direct = false; target.canPost = true; target.unicodeResult = .notSent; target.canPost = permission
        var ticket = InsertionTicket()
        let result = await TextInsertion(clipboard: BoardDouble()).insert("Diktat", target: target, ticket: &ticket, allowClipboard: !permission)
        #expect(result == .blocked); #expect(target.posts == 0)
    }
    @Test func cancelledTaskNeverMutatesTarget() async {
        let target = TargetDouble()
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            var ticket = InsertionTicket()
            return await TextInsertion(clipboard: BoardDouble()).insert("Diktat", target: target, ticket: &ticket, allowClipboard: true)
        }
        #expect(await task.value == .blocked); #expect(target.writes == 0)
    }
    @Test func utf16ReplacementProtectsEmojiAndSelection() {
        #expect(ExpectedInsertion.replacing(value: "A😀B", location: 1, length: 2, text: "Grüße") == "AGrüßeB")
        #expect(ExpectedInsertion.replacing(value: "A😀B", location: 2, length: 1, text: "X") == nil)
        #expect(ExpectedInsertion.replacing(value: "A", location: -1, length: 1, text: "X") == nil)
        #expect(ExpectedInsertion.replacing(value: "A", location: 0, length: Int.max, text: "X") == nil)
    }
    @Test func systemClipboardPreservesMultipleFormatsAndForeignChanges() throws {
        let board = NSPasteboard(name: .init("CraftVoice.test.\(UUID())"))
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Hallo", forType: .string)
        item.setData(Data("{\rtf1 Hallo}".utf8), forType: .rtf)
        board.clearContents(); #expect(board.writeObjects([item]))
        let adapter = SystemClipboard(board: board)
        let transaction = try #require(ClipboardTransaction.begin(text: "Diktat", clipboard: adapter))
        #expect(board.string(forType: .string) == "Diktat")
        let restored = transaction.restore()
        #expect(restored)
        #expect(board.string(forType: .string) == "Hallo")
        #expect(board.data(forType: .rtf) == Data("{\rtf1 Hallo}".utf8))
        let transaction2 = try #require(ClipboardTransaction.begin(text: "Neu", clipboard: adapter))
        board.clearContents(); board.setString("Andere App", forType: .string)
        let refused = transaction2.restore()
        #expect(!refused); #expect(board.string(forType: .string) == "Andere App")
    }
    @Test func concealedClipboardIsNotReadOrReplaced() {
        let board = NSPasteboard(name: .init("CraftVoice.secret-test.\(UUID())"))
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem(); item.setString("privat", forType: .string)
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        board.clearContents(); _ = board.writeObjects([item])
        #expect(SystemClipboard(board: board).snapshot() == nil)
        #expect(board.string(forType: .string) == "privat")
    }
}
