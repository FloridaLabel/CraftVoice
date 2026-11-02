import AppKit
import CraftVoiceCore

public struct ClipboardSnapshot: Sendable {
    public let changeCount: Int
    public let items: [[String: Data]]
    public init(changeCount: Int, items: [[String: Data]]) { self.changeCount = changeCount; self.items = items }
}
public struct ClipboardOwnership: Sendable {
    public let changeCount: Int
    public let marker: String
    public init(changeCount: Int, marker: String) { self.changeCount = changeCount; self.marker = marker }
}
@MainActor public protocol ClipboardAccess: AnyObject {
    func snapshot() -> ClipboardSnapshot?
    func publish(_ text: String, replacing snapshot: ClipboardSnapshot) -> ClipboardOwnership?
    func restore(_ snapshot: ClipboardSnapshot, ownership: ClipboardOwnership) -> Bool
    func owns(_ ownership: ClipboardOwnership) -> Bool
}

@MainActor public final class SystemClipboard: ClipboardAccess {
    private let board: NSPasteboard
    private static let marker = NSPasteboard.PasteboardType("app.craftvoice.desktop.transaction")
    public init(board: NSPasteboard = .general) { self.board = board }
    public func snapshot() -> ClipboardSnapshot? {
        let count = board.changeCount
        let items = board.pasteboardItems ?? []
        guard items.count <= 32 else { return nil }
        var result: [[String: Data]] = []
        var bytes = 0
        for item in items {
            guard item.types.count <= 64,
                  !item.types.contains(where: { $0.rawValue.lowercased().contains("promise") || $0.rawValue == "org.nspasteboard.ConcealedType" }) else { return nil }
            var data: [String: Data] = [:]
            for type in item.types {
                guard let value = item.data(forType: type) else { return nil }
                bytes += value.count
                guard bytes <= 32 * 1_024 * 1_024 else { return nil }
                data[type.rawValue] = value
            }
            result.append(data)
        }
        guard board.changeCount == count else { return nil }
        return ClipboardSnapshot(changeCount: count, items: result)
    }
    public func publish(_ text: String, replacing snapshot: ClipboardSnapshot) -> ClipboardOwnership? {
        guard board.changeCount == snapshot.changeCount else { return nil }
        let marker = UUID().uuidString
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setString(marker, forType: Self.marker)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        // Prevent Universal Clipboard publication of dictated text.
        board.prepareForNewContents(with: .currentHostOnly)
        guard board.writeObjects([item]) else { return nil }
        return ClipboardOwnership(changeCount: board.changeCount, marker: marker)
    }
    public func owns(_ ownership: ClipboardOwnership) -> Bool {
        board.changeCount == ownership.changeCount && board.string(forType: Self.marker) == ownership.marker
    }
    public func restore(_ snapshot: ClipboardSnapshot, ownership: ClipboardOwnership) -> Bool {
        guard ClipboardPolicy.mayRestore(ownedChangeCount: ownership.changeCount, currentChangeCount: board.changeCount),
              board.string(forType: Self.marker) == ownership.marker else { return false }
        let items = snapshot.items.map { data in
            let item = NSPasteboardItem()
            for (type, value) in data { item.setData(value, forType: NSPasteboard.PasteboardType(type)) }
            return item
        }
        // NSPasteboard has no cross-process compare-and-swap. Do not claim atomicity.
        guard board.changeCount == ownership.changeCount else { return false }
        board.prepareForNewContents(with: .currentHostOnly)
        return items.isEmpty || board.writeObjects(items)
    }
}

@MainActor public final class ClipboardTransaction {
    private let clipboard: any ClipboardAccess
    private let snapshot: ClipboardSnapshot
    private let ownership: ClipboardOwnership
    public private(set) var finished = false
    private init(clipboard: any ClipboardAccess, snapshot: ClipboardSnapshot, ownership: ClipboardOwnership) {
        self.clipboard = clipboard; self.snapshot = snapshot; self.ownership = ownership
    }
    public static func begin(text: String, clipboard: any ClipboardAccess) -> ClipboardTransaction? {
        guard let snapshot = clipboard.snapshot(), let ownership = clipboard.publish(text, replacing: snapshot) else { return nil }
        return ClipboardTransaction(clipboard: clipboard, snapshot: snapshot, ownership: ownership)
    }
    public var stillOwned: Bool { !finished && clipboard.owns(ownership) }
    /// Called only after observed paste consumption, before any dispatch, or by explicit user request.
    @discardableResult public func restore() -> Bool {
        guard !finished else { return false }
        finished = true
        return clipboard.restore(snapshot, ownership: ownership)
    }
}
