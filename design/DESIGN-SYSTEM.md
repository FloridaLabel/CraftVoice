# CraftVoice · Studio-Designsystem

## Leitbild
Ruhig, präzise, souverän. Eigenständiges Design nach den installierten BAMA-Skills und dem BAMA-Repository (https://github.com/daveebbelaar/bama); keine Übernahme fremder Screenshots oder Assets. Das vorhandene Icon bleibt bytegleich und liefert Cyan, Blau und Violett als Richtung.

## Drei Ebenen
- Palette in Sources/App/DesignKit/Tokens.swift: Rohfarben ausschließlich dort. Tiefblau für dunkle Grundflächen, Frost für helle; Cyan als Aktionsfläche, tiefer Teal für hellen Akzenttext, Violett als Identität, dunkles Grün für lesbare helle Erfolgstexte.
- Ink: canvas, panel, inset, accent, accentText, identity, onAccent, text, muted, warning, success. Views verwenden nur diese Bedeutungen. Primärtext bleibt systemsemantisch; eigene Meta-/Warnfarben sind pro Modus kontraststärker abgestimmt. Erhöhter Kontrast verstärkt die Panelkontur.
- KitType, Metric, Space: Systemschrift nach Rolle, 4-pt-Raster, 20-pt-Fensterrand, 16-pt-Kartenrand, konzentrische Karten-/Innenradien. Keine verteilten Rohfarben.

## Typografie
hero 28/semibold/rounded (Galerie), title 20/semibold, section 14/semibold, body 14, detail 12, micro 11/medium. Fließtext mit großzügigem Zeilenabstand. Meta erklärt, überschreibt aber keine Statusmeldung der Laufzeit. Native Menü-/Form-Controltypografie bleibt systemgeführt.

## Flächen und Komponenten
StudioPanel ist eine opake Inhaltsfläche mit feiner Kontur; kein Glas über Text. Mikrofon-Orbit mit radialem Licht und feinen konzentrischen Konturen. Keine unechte Pegelanzeige. StudioActionStyle stylt echte Buttons mit Hover, Pressed, Disabled; Tastatur und Accessibility bleiben SwiftUI-Controlverhalten. Keine eigenen Bewegungsanimationen, daher keine Schleifen bei Reduce Motion. StatusBadge verwendet immer Symbol plus Wort, nicht nur Farbe. ShortcutTile zeigt echte konfigurierte Kürzel.

## Darstellung und Einstellungen
Dunkel bleibt bevorzugt, bestehende gespeicherte Erscheinungsbildwahl bleibt erhalten. Heller Modus ist eigenständig. Bestehende Systemeinstellungsoption bleibt erhalten. Kein neuer Accent-Picker und keine Migration von Benutzereinstellungen. Native Fenstertitelleiste, Ampeln, Menüleiste, Formcontrols und Scrollbars bleiben erhalten. Einstellungen passen ihre Höhe den drei Tabs an.

## Visuelle Prüfung
Galerie per APP_KIT_GALLERY=1 im Snapshotmodus; echte Fensteraufnahmen mit tools/snapshot-redesign.py. Erfolgs-/Warnzustände, lange Texte, Einstellungen in Hell und Dunkel prüfen. Keine Screenshots fremder Fenster, keine Rechteanforderungen. Die vorhandenen Ansichten zeigen synthetische Diagnosezustände; sie sind kein Nachweis einer realen Aufnahme oder externer Texteingabe. Technische Grenzen stehen in der [Architektur](../docs/ARCHITEKTUR.md).
