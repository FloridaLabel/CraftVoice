import Foundation
import WhisperKit
import CraftVoiceCore

/// Public WhisperTokenizer bridge; WhisperKit 1.1.1's wrapper initializer is internal.
/// No Hub methods, fallback token IDs, or network operations. Word timestamps are disabled.
struct LocalGermanTokenizer: WhisperTokenizer {
    let wrapper: TokenizerWrapper
    let specialTokens: SpecialTokens
    let allLanguageTokens: Set<Int>
    init(wrapper: TokenizerWrapper) throws {
        self.wrapper = wrapper
        func id(_ token: String) throws -> Int {
            guard let value = wrapper.convertTokenToId(token), wrapper.convertIdToToken(value) == token else { throw SpeechFailure.invalidAssets }
            return value
        }
        _ = try id("<|de|>")
        let end = try id("<|endoftext|>")
        let whitespace = wrapper.encode(text: " ", addSpecialTokens: false)
        guard whitespace.count == 1 else { throw SpeechFailure.invalidAssets }
        specialTokens = try SpecialTokens(endToken: end, englishToken: id("<|en|>"),
            noSpeechToken: id("<|nospeech|>"), noTimestampsToken: id("<|notimestamps|>"),
            specialTokenBegin: end, startOfPreviousToken: id("<|startofprev|>"),
            startOfTranscriptToken: id("<|startoftranscript|>"), timeTokenBegin: id("<|0.00|>"),
            transcribeToken: id("<|transcribe|>"), translateToken: id("<|translate|>"),
            whitespaceToken: whitespace[0])
        allLanguageTokens = Set(Constants.languages.values.compactMap { wrapper.convertTokenToId("<|\($0)|>") })
    }
    func encode(text: String) -> [Int] { wrapper.encode(text: text) }
    func decode(tokens: [Int]) -> String { wrapper.decode(tokens: tokens) }
    func convertTokenToId(_ token: String) -> Int? { wrapper.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { wrapper.convertIdToToken(id) }
    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        var words: [String] = []
        var groups: [[Int]] = []
        var pending: [Int] = []
        for token in tokenIds {
            pending.append(token)
            let part = decode(tokens: pending)
            // Keep partial UTF-8 byte tokens together (e.g. German umlauts).
            if part.contains("\u{fffd}") { continue }
            let punctuation = !part.isEmpty && part.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
            if words.isEmpty || part.first?.isWhitespace == true || punctuation || token >= specialTokens.specialTokenBegin {
                words.append(part); groups.append(pending)
            } else {
                words[words.count - 1] += part
                groups[groups.count - 1].append(contentsOf: pending)
            }
            pending.removeAll(keepingCapacity: true)
        }
        if !pending.isEmpty { words.append(decode(tokens: pending)); groups.append(pending) }
        return (words, groups)
    }
}
