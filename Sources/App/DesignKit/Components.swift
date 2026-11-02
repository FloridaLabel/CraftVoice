import SwiftUI

struct StudioPanel: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.padding(Space.lg)
            .background(Ink.panel, in: RoundedRectangle(cornerRadius: Metric.radius))
            .overlay(RoundedRectangle(cornerRadius: Metric.radius).strokeBorder(Ink.muted.opacity(contrast == .increased ? 0.6 : 0.16)))
    }
}
extension View { func studioPanel() -> some View { modifier(StudioPanel()) } }
struct StudioActionStyle: ButtonStyle {
    var prominent = true
    var forcedHover = false
    var forcedPressed = false
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(KitType.section)
            .frame(maxWidth: .infinity).padding(.vertical, Space.md).padding(.horizontal, Space.lg)
            .foregroundStyle(prominent ? Ink.onAccent : Ink.text)
            .background(prominent ? Ink.accent : Ink.inset, in: RoundedRectangle(cornerRadius: Metric.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: Metric.controlRadius).strokeBorder(Ink.accentText.opacity(hover || forcedHover ? 0.7 : 0)))
            .brightness(configuration.isPressed || forcedPressed ? -0.08 : 0)
            .opacity(enabled ? 1 : 0.4)
            .onHover { hover = $0 }
    }
}
struct StatusBadge: View {
    let title: String
    let symbol: String
    var color: Color = Ink.accentText
    var body: some View {
        Label(title, systemImage: symbol).font(KitType.micro).foregroundStyle(color)
            .padding(.horizontal, Space.md).padding(.vertical, Space.sm)
            .background(color.opacity(0.10), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}
struct ShortcutTile: View {
    let title: String
    let shortcut: String
    var body: some View {
        HStack(spacing: Space.sm) {
            Text(title).foregroundStyle(Ink.muted)
            Spacer(minLength: Space.sm)
            Text(shortcut).font(KitType.detail).monospaced()
                .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                .background(Ink.inset, in: RoundedRectangle(cornerRadius: Space.sm))
        }.font(KitType.detail)
    }
}
struct KitGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Text("CraftVoice · Komponenten").font(KitType.hero)
            HStack { StatusBadge(title: "Bereit", symbol: KitIcon.ready); StatusBadge(title: "Aufnahme", symbol: KitIcon.mic, color: Ink.warning); StatusBadge(title: "Erkennung", symbol: KitIcon.processing) }
            HStack { StatusBadge(title: "Text erkannt", symbol: KitIcon.success, color: Ink.success); StatusBadge(title: "Eingefügt", symbol: KitIcon.success, color: Ink.success); StatusBadge(title: "Nicht bestätigt", symbol: KitIcon.warning, color: Ink.warning); StatusBadge(title: "Fehler", symbol: KitIcon.error, color: Ink.warning) }
            HStack {
                Button("Aufnahme starten") {}.buttonStyle(StudioActionStyle())
                Button("Hover") {}.buttonStyle(StudioActionStyle(forcedHover: true))
                Button("Gedrückt") {}.buttonStyle(StudioActionStyle(forcedPressed: true))
                Button("Nicht verfügbar") {}.buttonStyle(StudioActionStyle()).disabled(true)
            }
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Erkannter Text").font(KitType.section)
                Text("Präzise Worte. Vollständig lokal.").font(KitType.body)
                ShortcutTile(title: "Umschalten", shortcut: "⌃⌥Leertaste")
            }.studioPanel()
        }.padding(Space.margin).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Ink.canvas)
    }
}
