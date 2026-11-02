# Entwickler-Build

Apple Silicon, macOS 26+, Swift 6.2 oder neuer (vorherige Entwicklung: Swift 6.4.2), Python 3 und Xcode Command Line Tools werden benötigt. Netzwerk ist beim ersten SwiftPM-Abhängigkeitsbezug erforderlich. Das Sprachmodell wird weiterhin separat bereitgestellt.

- `./build.sh --compile-only`: Swift kompilieren, kein Bundle und keine Signierung.
- `./build.sh`: lokales Bundle mit expliziter Ad-hoc-Signatur ohne Schlüsselbund oder persönliches Zertifikat.
- `./build.sh --debug`: entsprechender Debug-Build.
- `./build.sh --reuse-executable /Pfad/zum/vorhandenen/Executable`: ausschließlich verpacken und ad-hoc signieren, ohne Swift aufzurufen. Der Aufrufer muss den Quellstand des gewählten Executables kennen; dieser Weg behauptet keine automatische Aktualität. Nicht mit --compile-only kombinierbar.

Neue Build-Artefakte, Modul-/SwiftPM-Caches und App-Bundles liegen im lokalen macOS-Temporärverzeichnis unter CraftVoiceDeveloper/<Projektkennung>, außerhalb des Quellordners. Der genaue Pfad wird ausgegeben. Die Projektkennung wird aus dem Quellpfad abgeleitet; temporäre Dateien können vom Betriebssystem bereinigt werden. Kein automatischer App-Start, keine Installation und keine Änderung vorhandener Ausgaben. Drittanbieterhinweise und Originalicon werden unverändert eingepackt. Bilddateien bleiben vom MIT-Code ausgenommen; es gelten ihre vorhandenen Rechtevorbehalte.

Ad-hoc-signierte Builds sind kein notarisiertes Downloadprodukt. Bei eigenem Start können macOS-Berechtigungen erforderlich sein; deren Speicherung kann sich bei neuen Builds ändern. Das Werkzeug ändert keine Berechtigungen. Diese Variante nicht über die bestehende installierte CraftVoice-App installieren.

## Bestehende lokale Signierwerkzeuge

`./build.sh --local-signed` ruft ausdrücklich den bisherigen lokalen Signierweg auf. tools/build.py, tools/project.py, tools/verify_signature.py, tools/install_app.py und tools/build-integration-host.py sowie ihre Tests enthalten weiterhin den alten Zertifikatsvertrag. Auch install.sh gehört zu diesem alten Weg und akzeptiert den Entwickler-Build nicht. Diese Werkzeuge werden vom neuen Entwickler-Build nicht ausgeführt. Ihr fester Fingerabdruck ist kein privater Schlüssel. Sie sind keine portable Release-Pipeline.

## Späterer Release-Build

Separat erforderlich: konfigurierbare Developer-ID-Identität, Hardened Runtime, sicherer Zeitstempel, geprüfte Entitlements, notarytool, Stapling und Gatekeeper-Abnahme. Kein Ad-hoc-Fallback für Releases. Der Entwickler-Build behauptet keine solche Freigabe.

## Tatsächliche Buildprüfung – aktuelles Ergebnis

Die strenge Signaturprüfung wurde am lokalen temporären Ausgabepfad unmittelbar sowie nach vollständiger Dateisystemprüfung und zwei Sekunden Wartezeit bestanden (je Exit 0). Bundle-ID app.craftvoice.desktop, Architektur arm64 und Signature=adhoc ohne Authority bestätigt. Vorhandenes erfolgreich kompiliertes Executable wiederverwendet; keine Neukompilierung, kein App-Start und keine Installation. Das frühere Dateianbieterproblem im Documents-Ausgabepfad wurde dadurch behoben.

### Vorheriger Befund am verwalteten Quellpfad

Mit Apple Swift 6.4.2 auf arm64/macOS 27.2 wurde `./build.sh --compile-only` tatsächlich erfolgreich ausgeführt. SwiftPM löste WhisperKit 1.1.1 und swift-argument-parser 1.8.2 auf; Package.resolved blieb unverändert. Der Entwickler-Build verwendet nun projektlokale SwiftPM-/Clang-/Swift-Caches. In einer eingeschränkten Agentenumgebung benötigt SwiftPM gegebenenfalls eine erlaubte Ausführung seiner Manifest-Sandbox und Netzwerkzugriff; am normalen Entwicklerrechner ist diese Agentenbeschränkung nicht Teil des Projekts.

`./build.sh` erzeugte ein vollständiges arm64-Bundle mit ID app.craftvoice.desktop und expliziter Ad-hoc-Signatur. Es wurden weder Zertifikatsidentitäten abgefragt noch persönliche Zertifikate ausgewählt. Vorhandene Signierskripte werden nicht aufgerufen; aus tools/build.py wird lediglich die reine Funktion bundle_info importiert. Originalicon und Drittanbietertexte sind im Bundle bytegleich vorhanden.

**Historischer Befund, durch den lokalen Ausgabepfad behoben:** Am endgültigen Ausgabepfad fügt der Dateianbieter dem Bundle nachträglich com.apple.FinderInfo hinzu. Die strenge Prüfung unmittelbar im Build bestand nach Bereinigung des erzeugten Bundles, die unabhängige spätere Prüfung schlug wegen erneut vorhandener Finder-Metadaten fehl. Eine dauerhaft gültige Bundle-Signatur an diesem synchronisierten Speicherort ist damit nicht nachgewiesen. Auch eine spätere Prüfung außerhalb der Agenten-Sandbox bestätigte das Problem. Eine Ad-hoc-Signatur an sich ist vorhanden (Signature=adhoc, keine Authority, keine Team-ID); der Fehler verlangt kein persönliches Zertifikat.

Notwendige Korrekturen beschränkten sich auf tools/developer_build.py: lokale Caches, Übernahme der Lizenzdateien ohne geerbte Dateiattribute und Bereinigung erweiterter Attribute ausschließlich im neu erzeugten Bundle einschließlich Prüfung am endgültigen Ziel. Weder Originaldateien noch installierte Apps werden bereinigt. Keine Synchronisations-, Finder-, Schlüsselbund- oder Berechtigungseinstellungen geändert.

Die anschließende Prüfung mit Ausgabe in das lokale macOS-Temporärverzeichnis ist erfolgt und bestanden. Nur neue Artefakte wurden dorthin geschrieben; vorhandene Ausgaben im alten dist-Verzeichnis wurden nicht gelöscht. Kein App-Start, keine Installation, keine Sprachtests und keine Aussage über Gatekeeper-/Notarisierungsfreigabe.

Details und tatsächliche Prüfergebnisse: [Buildprüfbericht](ENTWICKLER-BUILD-PRUEFUNG.md).
