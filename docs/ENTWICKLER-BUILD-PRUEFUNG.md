# Tatsächliche Entwickler-Buildprüfung

Stand: 2. November 2026. Ausschließlich lokale Kandidatenkopie und temporäre lokale Artefakte; kein Commit oder Upload.

## Aktueller Abschluss: Signaturproblem behoben

Das vorhandene arm64-Executable aus dem erfolgreichen Compile-only-Build wurde mit --reuse-executable erneut verpackt. Dabei wurde Swift nicht aufgerufen und nichts neu kompiliert. Neue Caches, Build-Ausgaben und Bundles werden nun standardmäßig unter dem lokalen macOS-Temporärverzeichnis erzeugt. Dieser Ordner liegt außerhalb von Documents/iCloud. Das konkrete Ergebnis wurde zusätzlich auf fehlende FinderInfo- und Dateianbieterattribute geprüft.

`codesign --verify --strict --verbose=2` bestand unmittelbar und erneut nach vollständigem Einlesen aller Bundle-Dateien und zwei Sekunden Wartezeit: jeweils Exit 0, valid on disk und satisfies its Designated Requirement. Zwischen diesen beiden unabhängigen Prüfungen wurden keine Attribute entfernt und nicht erneut signiert.

Bestätigt: Bundle-ID app.craftvoice.desktop, ausschließlich arm64, Signature=adhoc, keine Authority und keine Team-ID. Kein persönliches Zertifikat erforderlich. Icon und alle Drittanbietertexte sind im Bundle bytegleich. Keine Installation, kein App-Start und kein Sprachtest. Dies ist keine Gatekeeper-/Notarisierungsabnahme.

Der vollständige lokale Pfad steht in checks/developer-local-verification.json; er enthält absichtlich keinen dauerhaft zugesicherten Downloadpfad. Lokale Protokolle: checks/developer-local-bundle.log und checks/developer-local-signature.log. Die neuen Ergebnisse ersetzen die folgende historische negative Abnahme am Documents-Ausgabepfad.

## Historische Prüfung am Dateianbieter-Pfad

| Prüfung | Ergebnis |
| --- | --- |
| ./build.sh --compile-only | Erfolgreich, Exit 0; vollständiger echter Release-Compile-Lauf, keine App-Ausführung. |
| ./build.sh | Nach notwendigen Verpackungskorrekturen Exit 0; vollständiges Bundle und Ad-hoc-Signatur erzeugt. |
| Bundle-ID | app.craftvoice.desktop |
| Architektur / Executable | arm64 / Craft829a37ca |
| Icon und vollständige Drittanbietertexte | Bytegleich zu den Quellen; ICNS mit korrektem Dateikopf vorhanden. |
| Persönliches Zertifikat | Nicht erforderlich: explizites codesign --sign -, Signature=adhoc, keine Authority und keine Team-ID. |
| Signatur direkt im Build | codesign --verify --deep --strict am endgültigen Pfad zunächst erfolgreich. |
| Unabhängige spätere Signaturprüfung | Fehlgeschlagen: erneut angehängtes com.apple.FinderInfo am Bundle-Root. |
| Unabhängige Prüfung außerhalb der Agenten-Sandbox | Derselbe FinderInfo-Fehler; kein bloßer Anzeigeeffekt der Agenten-Sandbox. |

Erzeugtes Bundle: dist/developer/build-j2xziz0h/CraftVoice.app. Dieses Artefakt gilt wegen der fehlgeschlagenen späteren Prüfung **nicht als abschließend abgenommen**. Keine Installation oder Startfreigabe aus diesem Bericht ableiten.

## Notwendige Korrekturen

Der erste Compile-Versuch konnte nicht in den globalen Modulcache schreiben. Projektlokale Caches beheben diese Abhängigkeit. Eine verschachtelte SwiftPM-Sandbox konnte innerhalb der Agentenbeschränkung nicht starten; der explizit erlaubte Build außerhalb dieser Beschränkung gelang, ohne die SwiftPM-Sandbox im Skript abzuschalten.

Beim Verpacken wurden Finder-Metadaten und schreibgeschützte Attribute aus Quelldateien übernommen. Lizenztexte werden deshalb über copyfile in das neue Bundle kopiert, ohne den Quellinhalt zu ändern. Das macOS-Werkzeug xattr bereinigt nur das neu erzeugte Bundle, nicht Quellen oder installierte Apps. Das vorher versuchte Python-os.listxattr ist in dieser lokalen Python-Distribution nicht vorhanden und wurde durch das Systemwerkzeug ersetzt.

Der beobachtete Dateianbieter hängt nach dem Verschieben erneut FinderInfo an. Automatisches Bereinigen und sofortiges Prüfen allein garantieren deshalb keinen dauerhaft unveränderten Ausgabezustand. Weitere Buildwiederholungen am selben Pfad würden die Ursache nicht zuverlässig beseitigen. Keine System-/Sync-Einstellung verändert und keine Prüfregel abgeschwächt.

## Zertifikatsunabhängigkeit und Grenzen

Der ausgeführte Entwicklerpfad besteht aus Swift-Kompilierung, Verpackung, xattr und expliziter Ad-hoc-Codesignierung. Er ruft weder security find-identity noch den bisherigen lokalen Zertifikats-Build oder Installer auf. Der Import der reinen Bundle-Metadatenfunktion führt dessen main-Funktion nicht aus. Es fand keine Schlüsselbundinventur oder Zertifikatsauswahl statt. Die beobachtete Ad-hoc-Signatur bestätigt die Zertifikatsunabhängigkeit, ersetzt aber nicht die fehlgeschlagene strenge Ressourcenprüfung.

Technisch kann der Entwickler-Build ohne Craft Code Signing kompilieren und ein Bundle erzeugen. Offen bleibt eine unabhängige Endprüfung an einem lokalen Speicherort ohne nachträgliche Dateianbieter-Metadaten. Voraussetzung bleibt die dokumentierte Swift-/macOS-Toolchain und der erste Netzwerkbezug der festgelegten Abhängigkeiten. Eine Prüfung auf einem fremden Mac ist nicht erfolgt.

Lokale Rohbelege unter checks/: developer-compile-only.log, developer-bundle.log, developer-signature.log, developer-verification.json. Sie enthalten lokale Diagnosepfade und werden nicht versioniert. Fehlgeschlagene Zwischenläufe sind oben eingeordnet; das finale Buildlog allein ist kein dauerhafter Signaturerfolg.

Originalprojekt, installierte App, Bildlizenzen und privates GitHub-Repository unverändert. Keine App gestartet oder installiert; keine Mikrofon-, Diktat- oder Sprachtests, keine Commits oder Releases. Package.resolved unverändert.

## Technische Änderungen zur Behebung

Nur tools/developer_build.py und die betroffenen technischen Anleitungen geändert: lokales temporäres Build-/Cache-/Bundle-Verzeichnis, explizite Wiederverwendung eines vorhandenen Executables mit arm64-Prüfung, Kopie der Executable-Inhalte ohne Dateimetadaten bei erhaltenem Ausführungsbit, strenge Prüfung am endgültigen Ziel. Die bestehende Bereinigung betrifft ausschließlich das neue temporäre Bundle vor der Signierung; nach dem Verschieben wird nur geprüft, nicht erneut bereinigt. Das behebt die Ursache statt die Prüfung zu umgehen.

Die Wiederverwendung ist explizit und prüft keine automatische Quellaktualität. Der hier verwendete Quellstand war bereits erfolgreich kompiliert; seitdem wurden nur Build-/Dokumentationsdateien verändert. Für zukünftige Codeänderungen ist ein normaler Build erforderlich. Der neue Standard-Compilepfad im temporären Verzeichnis wurde gezielt mit gemocktem Swift-Aufruf auf seine Pfadargumente geprüft; keine unnötige vollständige Kompilierung durchgeführt.

Die temporären Ausgaben sind löschbar und nicht dauerhaft archiviert. Das private Repository, Originalprojekt, bestehende Installation, Bildlizenzen und alte Build-Artefakte wurden nicht verändert.
