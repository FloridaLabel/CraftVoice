import SwiftUI
import AppKit

private enum Palette {
    static let navy = NSColor(srgbRed: 0.035, green: 0.065, blue: 0.13, alpha: 1)
    static let blue = NSColor(srgbRed: 0.065, green: 0.105, blue: 0.19, alpha: 1)
    static let deep = NSColor(srgbRed: 0.025, green: 0.045, blue: 0.095, alpha: 1)
    static let frost = NSColor(srgbRed: 0.94, green: 0.96, blue: 0.985, alpha: 1)
    static let cyan = NSColor(srgbRed: 0.25, green: 0.87, blue: 0.90, alpha: 1)
    static let teal = NSColor(srgbRed: 0.0, green: 0.35, blue: 0.40, alpha: 1)
    static let warningDeep = NSColor(srgbRed: 0.52, green: 0.27, blue: 0.08, alpha: 1)
    static let mutedLight = NSColor(srgbRed: 0.32, green: 0.38, blue: 0.46, alpha: 1)
    static let mutedDark = NSColor(srgbRed: 0.65, green: 0.72, blue: 0.82, alpha: 1)
    static let successDeep = NSColor(srgbRed: 0.0, green: 0.38, blue: 0.24, alpha: 1)
    static let violet = NSColor(srgbRed: 0.67, green: 0.61, blue: 1, alpha: 1)
}
enum Ink {
    private static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    static let canvas = adaptive(Palette.frost, Palette.navy)
    static let panel = adaptive(.white, Palette.blue)
    static let inset = adaptive(Palette.frost, Palette.deep)
    static let accent = Color(nsColor: Palette.cyan)
    static let accentText = adaptive(Palette.teal, Palette.cyan)
    static let identity = adaptive(.systemIndigo, Palette.violet)
    static let onAccent = Color(nsColor: Palette.deep)
    static let text = Color.primary
    static let muted = adaptive(Palette.mutedLight, Palette.mutedDark)
    static let warning = adaptive(Palette.warningDeep, .systemOrange)
    static let success = adaptive(Palette.successDeep, .systemMint)
}
enum KitType {
    static let hero = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let title = Font.system(size: 20, weight: .semibold)
    static let section = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 14)
    static let detail = Font.system(size: 12)
    static let micro = Font.system(size: 11, weight: .medium)
}
enum Metric {
    static let radius: CGFloat = 24
    static let controlRadius: CGFloat = 12
    static let rail: CGFloat = 260
    static let orbit: CGFloat = 120
}
enum KitIcon {
    static let mic = "mic.fill", stop = "stop.fill", ready = "waveform", processing = "sparkles"
    static let offline = "network.slash", model = "cpu", success = "checkmark.circle.fill"
    static let warning = "exclamationmark.circle", error = "exclamationmark.triangle.fill"
    static let copy = "doc.on.doc"
    static let keyboard = "keyboard", settings = "slider.horizontal.3", text = "text.alignleft"
}
