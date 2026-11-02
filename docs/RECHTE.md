# Rechteprüfung vor Bereitstellung

Stand: 2. November 2026. Dokumentation der vorhandenen Nachweise; keine Behauptung eines geklärten Rechts an allen Assets.

## Originales CraftVoice-Icon

Datei: Icon/CraftVoice.png. SHA-256: ada778578ee6fffad886ee6cdb610cbf298d997828000c33b83c93b153c916c3. Das Bild wurde bytegleich aus dem bestehenden Projekt übernommen und visuell als weißes Mikrofon auf blau-cyan-violettem Hintergrund geprüft. Es wurde nicht neu erzeugt oder durch ein Profilbild ersetzt.

Der Projekteigentümer hat am 2. November 2026 erklärt: Das Icon wurde mit ChatGPTs Bildgenerierung speziell für CraftVoice erstellt und anschließend von ihm als offizielles CraftVoice-App-Icon ausgewählt. Er erlaubt die unveränderte Verwendung des Icons. Diese Herkunftsangabe beruht auf seiner Erklärung; eine erneute Bildgenerierung wurde nicht durchgeführt.

Damit ist die Verwendung des Originalicons einschließlich seiner Darstellung in den vorhandenen Screenshots für die vorbereitete private GitHub-Bereitstellung freigegeben. Eine öffentliche Veröffentlichung wird dadurch nicht freigegeben. Die spätere öffentliche Rechteprüfung einschließlich des Lizenzumfangs für Bildmaterial bleibt ausdrücklich offen. Die MIT-Lizenz für den eigenen Code wird nicht pauschal auf das Icon erstreckt.

## Technische Kennungen im privaten Repository

Der Projekteigentümer erlaubt ausdrücklich, vorhandene personenbezogene technische Kennungen vorerst im PRIVATEN Repository beizubehalten. Bundle-IDs, Signierungskennungen, Log-Subsysteme, Zwischenablage-Typen und verwandte technische Bezeichner bleiben unverändert. Diese Ausnahme gilt ausschließlich für technische Kennungen, nicht für private Aufnahmen, Diagnosen, Schlüssel oder andere private Daten. Vor einer öffentlichen Veröffentlichung werden die Kennungen erneut geprüft. Es besteht keine Freigabe für eine öffentliche Veröffentlichung oder einen GitHub Release.

## Sprachmodell und Tokenizer

- OpenAI whisper-large-v3-turbo, Revision 41f01f3fe87f28c78e2fbf8b568835947dd65ed9: Die spezifische revisionsgebundene Modellkarte kennzeichnet MIT. Nicht mit der Karte des Basismodells large-v3 gleichsetzen.
- Argmax whisperkit-coreml, Revision 0f63a7800b00dd0226abd051b906c246e1907482, Variante openai_whisper-large-v3-v20240930_turbo: Aktuelle offizielle Repository-Kennzeichnung MIT. Die Karten-/API-Abrufe für genau diese Revision konnten über das Webwerkzeug erneut nicht abgerufen werden. Der revisionsgenaue Nachweis zusätzlicher Lizenz-/Notice-Dateien bleibt offen; dies ist eine Abrufgrenze und kein Beweis einer ungültigen Revision.
- Das Exportverzeichnis enthält keine Modellgewichte und keine heruntergeladenen Tokenizerdateien. Es enthält nur Bereitstellungswerkzeug, Quellverweise und Drittanbieter-Lizenztexte. Ein eigenes Modellpaket wird in dieser Phase nicht verteilt.

MIT erlaubt grundsätzlich Nutzung, Änderung und Weitergabe mit Erhalt der erforderlichen Urheber- und Lizenzhinweise. Vor einem eigenen Modellarchiv sind die vollständigen, zum konkreten Artefakt gehörenden Lizenz-/Notice-Texte der beiden Quellen zu archivieren und beizulegen. Das bestehende Werkzeug lädt die repositoryweiten Tokenizer-Lizenzdateien nicht automatisch mit. Die aktuelle Quellcodebereitstellung ist keine Modell-Weitergabe; die offene Modellpaket-Frage allein würde einen privaten Quellcode-Upload daher nicht blockieren.

Quellen: [OpenAI-Modellkarte der festgelegten Revision](https://huggingface.co/openai/whisper-large-v3-turbo/blob/41f01f3fe87f28c78e2fbf8b568835947dd65ed9/README.md), [Argmax-Modellrepository](https://huggingface.co/argmaxinc/whisperkit-coreml), [OpenAI-Whisper-Lizenz](https://github.com/openai/whisper/blob/main/LICENSE), [MIT-Standardtext](https://opensource.org/license/mit).
