import Testing
@testable import ExampleKit
@Test("Neue Apps starten standardmäßig dunkel")
func defaultAppearance() { #expect(AppearanceChoice.defaultChoice == .dark) }
@Test("Alle Darstellungen sind deutsch beschriftet", arguments: [
    (AppearanceChoice.dark, "Dunkel"), (.light, "Hell"), (.system, "Systemeinstellung")
])
func germanAppearance(_ choice: AppearanceChoice, title: String) {
    #expect(choice.title == title)
    #expect(AppearanceChoice(rawValue: choice.rawValue) == choice)
}
