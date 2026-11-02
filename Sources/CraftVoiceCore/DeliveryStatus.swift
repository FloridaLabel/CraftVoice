/// Keeps the reason for local-only delivery across asynchronous recognition.
/// Never contains dictated text or the contents of another application's field.
public enum DeliveryStatus: Equatable, Sendable {
    case local, disabled, unavailable(String), captured
    public var message: String {
        switch self {
        case .local: "Lokal im Diktatfenster gestartet. Für die Eingabe in andere Apps das globale Tastenkürzel verwenden."
        case .disabled: "Automatisches Einfügen ist in CraftVoice deaktiviert."
        case .unavailable(let reason): reason
        case .captured: "Ursprüngliches Textfeld erfasst."
        }
    }
    public var retainedResultMessage: String { "Text erkannt und in CraftVoice bereitgestellt. " + message }
}
