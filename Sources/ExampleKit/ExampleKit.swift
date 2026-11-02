public enum AppearanceChoice: String, CaseIterable, Sendable {
    case dark, light, system
    public static let defaultChoice: Self = .dark
    public var title: String {
        switch self {
        case .dark: "Dunkel"
        case .light: "Hell"
        case .system: "Systemeinstellung"
        }
    }
}
