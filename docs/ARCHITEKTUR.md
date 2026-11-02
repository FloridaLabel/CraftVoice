# Architektur

SwiftPM-Projekt mit getrennten Modulen:

- CraftVoiceCore: Sitzungszustand, Audio-Restfenster, Modellpfade, Fokus- und Zustellregeln.
- CraftVoiceSpeech: Mikrofonaufnahme, lokaler Tokenizer und WhisperKit-Adapter.
- CraftVoiceIntegration: Zielbindung über Accessibility, globale Kürzel, sichere Texteingabe und optionale Zwischenablage-Transaktionen.
- App: SwiftUI-/AppKit-Oberfläche, Design-Tokens und VoiceRuntime als Koordinator.
- IntegrationProbe, ModelProbe, PlatformProbe: getrennte Diagnoseprogramme; keine gewöhnlichen App-Einstiegspunkte.
- ExampleKit und Tests: vorhandene Vorlagen-/Erscheinungsbildprüfungen.

Die App verbindet Speech und Integration über Core. Nach möglicher Zustellung wird nicht automatisch erneut eingefügt. Diagnosezustände und UI-Snapshots beweisen keine reale Mikrofon- oder externe Eingabefunktion.

Die öffentliche Kandidatenkopie verwendet den neutralen technischen Namensraum app.craftvoice.desktop. Geändert wurden ausschließlich Produkt-/Probe-Bundle-IDs, Logging-Subsysteme und der eigene Zwischenablage-Typ; die Tests und übrigen Komponenten bleiben unverändert. Die Zuordnung wurde statisch geprüft, es wurde kein App-Build oder Funktionstest durchgeführt. Die lokale Signierbindung bleibt ein separat zu lösendes Build-Thema. Die Kandidatenkopie ist nicht zur Installation über eine vorhandene CraftVoice-App vorgesehen.
