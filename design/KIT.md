# CraftVoice Design Kit
Ruhig · präzise · souverän. Eigenständige Oberfläche nach den installierten BAMA design-kit/mac-design-Anleitungen; keine Kopie fremder Screenshots.

## Entwurf vor Umsetzung
Menüleisten-App mit Diktatfenster und drei Einstellungsseiten. Oben kompakte Marke und Offline-Siegel; darunter Zweispaltenkomposition: links Aufnahme mit ruhigem Mikrofon-Orbit und eindeutigem Hauptbutton, rechts großzügiges Transkript. Unten Modell und Kürzel. Einzige dominante Fläche: cyanfarbene Hauptaktion. Violett nur für lokale Verarbeitung und Identität. Native Fensterknöpfe, Menüs, Scrollbars und Einstellungscontrols bleiben erhalten.

## Tokens
Palette ausschließlich in Tokens.swift. Semantik: canvas (tiefblau/hellblau), panel (erhöht), inset (Textfläche), accent (Cyan mit dunkler Textfarbe), identity (Violett), warning, success, ink und muted. Heller und dunkler Modus, erhöhte Kontraste über Systemtext und stärkeres Konturlinien-Token. Schriftrollen: hero, title, section, body, detail, micro. Systemschrift, Fließtext 14 pt, Meta mindestens 11 pt. 4-pt-Abstände, 20-pt-Fensterrand, 16-pt-Kartenrand, 24-pt-Kartenradius.

## Komponenten
- Panel: opaker Lesebereich, feine Kontur, keine Glasstapelung.
- ActionStyle: echter Button, Cyan/dunkle Tinte; Hover-Kontur, gedrückter dunklerer Füllstand, reduzierter Disabled-Kontrast, systemeigener Tastaturfokus. Keine Bewegungsanimation.
- StatusBadge: Symbol und Text zusätzlich zur semantischen Farbe; bereit, Aufnahme, Verarbeitung, erkannt, eingefügt, unbestätigt, Fehler.
- Mikrofon-Orbit: statische konzentrische Konturen, keine erfundenen Audiopegel. Aufnahme wechselt Symbol und Farbe. Keine Aufnahme-/ASR-Änderung nur für Visualisierung.
- ShortcutTile: Bezeichnung und echte konfigurierte Tastenkombination.
- Einstellungen: Markenheader, native Tabs/Formulare auf abgestimmter Grundfläche, bestehende Bindings unverändert.

## UX
Fensteraufnahme bleibt lokal; das wird neben dem Hauptbutton erklärt. Globale Aufnahme erfolgt im Zielprogramm. Transkript bleibt selektierbar und scrollbar. Keine automatische Zwischenablageaktion. Escape bricht ab; vorhandene Menüs und Kürzel unverändert. Lange Fehlermeldungen umbrechen. Keine Farbe als einziger Statusnachweis. Galerie per APP_KIT_GALLERY=1 innerhalb Snapshot-Diagnose.
