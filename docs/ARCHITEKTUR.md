# Architektur

SwiftPM-Projekt mit getrennten Modulen:

- CraftVoiceCore: Sitzungszustand, Audio-Restfenster, Modellpfade, Fokus- und Zustellregeln.
- CraftVoiceSpeech: Mikrofonaufnahme, lokaler Tokenizer und WhisperKit-Adapter.
- CraftVoiceIntegration: Zielbindung über Accessibility, globale Kürzel, sichere Texteingabe und optionale Zwischenablage-Transaktionen.
- App: SwiftUI-/AppKit-Oberfläche, Design-Tokens und VoiceRuntime als Koordinator.
- IntegrationProbe, ModelProbe, PlatformProbe: getrennte Diagnoseprogramme; keine gewöhnlichen App-Einstiegspunkte.
- ExampleKit und Tests: vorhandene Vorlagen-/Erscheinungsbildprüfungen.

Die App verbindet Speech und Integration über Core. Nach möglicher Zustellung wird nicht automatisch erneut eingefügt. Diagnosezustände und UI-Snapshots beweisen keine reale Mikrofon- oder externe Eingabefunktion.

Der technische Namensraum ist app.craftvoice.desktop: Produkt-Bundle-ID, Logging-Subsystem und eigener Zwischenablage-Typ sind darauf abgestimmt. Der Testhost verwendet app.craftvoice.desktop.integrationtest. Gegenüber einer App mit anderer Bundle-ID entsteht eine andere Produktidentität; Einstellungen und macOS-Berechtigungen werden nicht automatisch migriert. Diese Variante ist nicht zur Installation über eine anders identifizierte CraftVoice-App vorgesehen.

Der Build ist weiterhin an die lokale Signieridentität gebunden. Der portable lokale Ad-hoc-Entwickler-Build benötigt kein persönliches Signierzertifikat; siehe [Entwickler-Build](ENTWICKLER-BUILD.md). Ein portabler Developer-ID-/Notarisierungsweg für die App-Veröffentlichung fehlt weiterhin. Die Identitätszuordnung wurde statisch und durch gezielte Konfigurationstests geprüft; dies ist keine Abnahme eines unter neuer Identität gebauten App-Bundles.
