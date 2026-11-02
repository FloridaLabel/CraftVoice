# Drittanbieter und Herkunft

Stand: 2. November 2026. Diese Hinweise dokumentieren Drittanbieterrechte. Die vorbereitete Lizenz des eigenen Codes steht in LICENSE; Abgrenzungen stehen in LICENSE-SCOPE.md.

| Bestandteil | Stand | Lizenz / Pflicht |
| --- | --- | --- |
| WhisperKit / ArgmaxCore | 1.1.1, Revision `1bbc57cb7fe6410248a685b1c5a3c6d56adc2ed4` | MIT; Copyright und vollständigen Lizenztext beilegen. |
| Aus swift-transformers abgeleitete Teile in ArgmaxCore/External | in dieser WhisperKit-Version enthalten | Apache-2.0; vollständige Lizenz und bestehende Hinweise/Änderungsmarkierungen erhalten. In WhisperKit-NOTICES enthalten. |
| swift-argument-parser | 1.8.2, Revision `6a52f3251125d74daf04fcbd5e6f08a75d074382` | Apache-2.0; als aufgelöste Paketabhängigkeit dokumentiert. Das Produkt ArgumentParser ist keine direkte CraftVoice-App-Abhängigkeit, sondern wird upstream vom CLI verwendet. |
| BAMA-Vorlagenbestandteile | installierte Pluginversion 1.0.0 | MIT, Copyright 2026 Dave Ebbelaar; vollständiger Text zusätzlich beigelegt. |
| OpenAI Whisper large-v3-turbo und Tokenizer | getrennte Modellbereitstellung | MIT laut spezifischer Modellkarte; bei Weitergabe Lizenz und Urheberhinweise des exakten Bestands beilegen. Nicht mit der anders lizenzierten large-v3-Modellkarte gleichsetzen. |
| Argmax Core-ML-Konvertierung | getrennte Modellbereitstellung | Modellrepository als MIT gekennzeichnet; genaue Revisionshinweise vor Modellpaket-Veröffentlichung archivieren. |

Vollständige bereits vorliegende Texte in `Resources/ThirdParty/`: WhisperKit-LICENSE.txt, WhisperKit-NOTICES.txt (einschließlich Apache-2.0), swift-argument-parser-LICENSE.txt, BAMA-LICENSE.txt und OpenAI-Whisper-LICENSE.txt. Der OpenAI-Text basiert auf der offiziellen Whisper-Lizenz (Copyright 2022 OpenAI); er ersetzt keine abschließende Prüfung zusätzlicher Notices im konkret verteilten Modellpaket.

BAMA wurde als Entwicklungswerkzeug genutzt und ist keine Laufzeitabhängigkeit. Direkter Vergleich mit der installierten Vorlage: `Sources/App/UI/WindowBehavior.swift` und `tools/grid-lint.sh` sind bytegleich; `Sources/App/UI/Grid.swift` und `tools/check-layout.swift` nahezu identisch. Die BAMA-Lizenz wird vorsorglich für alle aus dieser Vorlage abgeleiteten Bestandteile mitgeführt. Die Vorlage darf nicht pauschal als ausschließlich eigener Code bezeichnet werden.

Apple-Systemframeworks (SwiftUI, AppKit, AVFoundation, Core ML, Carbon, ApplicationServices, WebKit u. a.) werden über das SDK eingebunden; keine separat kopierten Apple-Frameworks oder SF-Symbol-Bilddateien wurden im getrackten Bestand gefunden. Die eigene Lizenz kann Rechte an Apple-SDKs oder Markenzeichen nicht vergeben. Keine weiteren SwiftPM-Pins im vorhandenen Package.resolved; optionale upstream Server-/Pro-Produkte werden nicht vom App-Target eingebunden.

Das originale CraftVoice-Icon wurde nach Erklärung des Projekteigentümers mit ChatGPTs Bildgenerierung speziell für CraftVoice erstellt und von ihm als offizielles App-Icon ausgewählt. Er erlaubt die unveränderte Verwendung für die private Bereitstellung. Das Icon wird nicht pauschal unter die MIT-Lizenz für den eigenen Code gestellt. Die Rechteprüfung und der Lizenzumfang für eine spätere öffentliche Veröffentlichung bleiben offen; siehe docs/RECHTE.md.

Quellen: [WhisperKit-Lizenz](https://github.com/argmaxinc/WhisperKit/blob/v1.1.1/LICENSE), [WhisperKit-NOTICES](https://github.com/argmaxinc/WhisperKit/blob/v1.1.1/NOTICES), [swift-argument-parser](https://github.com/apple/swift-argument-parser/blob/1.8.2/LICENSE.txt), [BAMA](https://github.com/daveebbelaar/bama/blob/main/LICENSE), [Whisper](https://github.com/openai/whisper/blob/main/LICENSE), [OpenAI-Modellkarte](https://huggingface.co/openai/whisper-large-v3-turbo/tree/41f01f3fe87f28c78e2fbf8b568835947dd65ed9), [Argmax-Modellrepository](https://huggingface.co/argmaxinc/whisperkit-coreml).
