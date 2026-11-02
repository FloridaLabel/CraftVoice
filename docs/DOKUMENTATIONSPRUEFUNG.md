# Dokumentationsprüfung und Bildlizenzvorschlag

Stand: 2. November 2026. Diese Prüfung betrifft ausschließlich die Dokumentation der lokalen Kandidatenkopie mit Ausgangscommit 62ba574. Es wurde kein weiterer Commit angelegt. Der Bericht selbst ist eine zusätzliche Dokumentationsdatei.

## Ergebnis und rechtliche Abgrenzung

Die bekannte Iconherkunft ist in [RECHTE.md](RECHTE.md) nachgewiesen als Erklärung des Projekteigentümers: mit ChatGPTs Bildgenerierung für CraftVoice erstellt und als offizielles App-Icon ausgewählt. Das Erklärungsdatum ist kein Nachweis des Generierungsdatums. Originalbild und Screenshots wurden nicht verändert; vorhandene Bildprüfungen wurden nicht unnötig wiederholt.

OpenAIs vertragliche Zuordnung des Outputs an den Nutzer ist von tatsächlichem urheberrechtlichem Schutz und Rechten Dritter zu unterscheiden. Der dokumentierte Herkunftsstand spricht nicht für ein pauschales Verbot öffentlicher Nutzung. Er beweist aber keine exklusiven Bildrechte und keine vollumfängliche Erlaubnis für Weiterverwendung durch Dritte.

Die abschließende Eigentümerentscheidung ersetzt den CC-BY-Vorschlag: Für Icon und Screenshots gilt **All rights reserved**, soweit entsprechende Rechte bestehen. Das Icon dient ausschließlich als offizielles Erkennungszeichen von CraftVoice; eine gesonderte Erlaubnis zur Veränderung oder Verwendung für andere Projekte wird nicht erteilt. MIT gilt weiterhin für eigenen Code und Text, nicht für die Bilddateien.

Die Entscheidung ist in LICENSE-SCOPE.md, docs/RECHTE.md, THIRD_PARTY_NOTICES.md und Icon/source.json konsistent dokumentiert. Der bereits vorhandene README-Verweis wurde lediglich von „Lizenzvorschlag“ auf „Nutzungsbedingungen“ aktualisiert; keine neuen Verwaltungs- oder Hinweisblöcke eingefügt. Die Bilddateien bleiben unverändert. Die vorhergehende Prüfung der Herkunft und ihrer rechtlichen Grenzen bleibt gültig.

## Dokumentierte Änderungen

| Datei | Änderung |
| --- | --- |
| README.md | Bildrechte getrennt von MIT erklärt und auf die Nutzungsbedingungen verwiesen; keine interne Statusbox eingeführt. |
| LICENSE-SCOPE.md | MIT als vorhandene Code-/Textlizenz beschrieben; veraltete Nichtbereitstellungsbehauptung und Privatstatus entfernt; Icon und Screenshots eindeutig ausgegrenzt. |
| THIRD_PARTY_NOTICES.md | Veraltete Formulierung „vorbereitete Lizenz“ korrigiert; Herkunft und getrennten Rechtevorbehalt vereinheitlicht. Alle Komponenten-/Lizenzhinweise erhalten. |
| CONTRIBUTING.md | Überholte Aussage einer erst künftig festzulegenden eigenen Lizenz durch zutreffenden MIT-Verweis ersetzt. |
| SECURITY.md | Interne Veröffentlichungsplanung durch handlungsorientierte Hinweise ersetzt: vertraulichen Meldeweg verwenden, sofern vorhanden; keine nicht eingerichtete Kontaktadresse oder Funktion behauptet. |
| docs/RECHTE.md | Herkunft, gesicherte Angaben, Unsicherheiten und abschließend gewählten Rechtevorbehalt zusammengeführt. Historische Ausnahme zu personenbezogenen IDs im privaten Repository entfernt. Modellpflichten erhalten. |
| docs/MODELL.md | Internen Veröffentlichungsplan durch sachliche Beschreibung des getrennten Direktbezugs ersetzt; fehlende Lizenzdateien des Tokenizers und Modellarchivpflichten beibehalten. |
| docs/ARCHITEKTUR.md | Historischen Änderungsablauf durch Beschreibung der aktuellen technischen IDs ersetzt; Folgen unterschiedlicher App-Identitäten und Signiergrenzen erhalten. |
| design/KIT.md | Überholte Überschrift „Entwurf vor Umsetzung“ in „Aufbau“ geändert. |
| design/DESIGN-SYSTEM.md | Abnahmebezeichnung sachlich gefasst; Verweis auf den nicht mitgelieferten internen Bericht entfernt und durch vorhandene Architektur-/Diagnoseinformationen ersetzt. |
| Icon/source.json | Herkunft und den gewählten Rechtevorbehalt getrennt von der Code-Lizenz dokumentiert. Bildhash unverändert. |
| docs/DOKUMENTATIONSPRUEFUNG.md | Dieser Änderungs- und Entscheidungsnachweis ergänzt. |

## Erhaltene technische Informationen

Keine öffentlichen App-Downloads, kein freigegebener Installer und kein GitHub Release vorhanden; README-Hinweise bleiben bestehen. Swift-Build erzeugt bei compile-only kein startfertiges Bundle. Die feste lokale Signierbindung und das Fehlen eines portablen signierten Buildwegs bleiben sichtbar. Modellgröße, feste Revisionen, bewusster Download, Offline-Verifikation, lokale Verarbeitung, Diagnose-Datenschutz und Eingabegrenzen bleiben dokumentiert.

Die Dokumentation behauptet weder einen bereits eingerichteten öffentlichen Meldekanal noch eine neu geprüfte App-Funktion. Offene rechtliche Entscheidungen werden dort benannt, wo sie die Nutzungsrechte tatsächlich betreffen; sie werden nicht durch Entfernen interner Statusvermerke als erledigt dargestellt.

## Prüfungen

- Alle 99 vorhandenen Dateien vor und nach der Bearbeitung per SHA-256 verglichen: Änderungen ausschließlich an den elf aufgeführten Dokumentations-/Herkunftsdateien. Mit diesem zusätzlichen Bericht enthält die Kopie 100 Arbeitsdateien ohne .git.
- LICENSE und alle vollständigen Lizenz-/Notice-Dateien unter Resources/ThirdParty unverändert. MIT-/BAMA-/WhisperKit- und Apache-Texte nicht neu formuliert oder ersetzt.
- README würdigt Dave Ebbelaar und BAMA weiterhin ausdrücklich als Entwicklungswerkzeug, nicht als Laufzeitabhängigkeit.
- Originalicon und alle drei Screenshots bytegleich erhalten; Iconhash stimmt mit Icon/source.json überein.
- Relative Iconreferenz in README weiterhin Icon/CraftVoice.png. Alle lokalen Markdown-/Bildlinks auf vorhandene Ziele geprüft.
- Git-Diff auf Whitespacefehler geprüft. App-Code, Tests, Werkzeuge, project.json und Package-Dateien unverändert.
- Keine Builds, Tests, Bildschirmaufnahmen, Account-/Repository-Abfragen, Uploads oder GitHub-Schreiboperationen. Arbeit ausschließlich in github-public-kandidat; Originalprojekt, bisheriger Export und installierte App nicht bearbeitet. Keine öffentliche Freigabe und kein Release.

## Abschluss

Die Bildlizenzentscheidung ist dokumentiert; hierzu steht keine Auswahl von CC BY oder CC0 mehr aus. Es wurden keine zusätzlichen Bildrechte eingeräumt und keine vorhandenen Rechte Dritter verändert. Kein neuer Commit, keine Änderung an GitHub, kein Upload, keine öffentliche Freigabe und kein Release. Der laufende Dokumentationsschritt ist abgeschlossen.

Ein tatsächlicher vertraulicher Sicherheitsmeldeweg und die bereits dokumentierten technischen Veröffentlichungsvoraussetzungen bleiben eigenständige Aufgaben. Die Entscheidung zum Bildmaterial behauptet keine absolute rechtliche Sicherheit.

Quelle für die vertragliche Einordnung des KI-Outputs: [OpenAI Europe Terms](https://openai.com/policies/eu-terms-of-use/). Maßgeblich ist der jeweils anwendbare Vertrag, nicht allein das Abrufdatum dieser Dokumentation.
