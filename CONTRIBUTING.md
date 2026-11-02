# Mitwirken

Eigener Quellcode und Textdokumentationen stehen unter der [MIT-Lizenz](LICENSE). Für Bildmaterial und Drittanbieter gelten die getrennten Hinweise im [Lizenzumfang](LICENSE-SCOPE.md).

Beschreibe Fehler mit macOS-Version, Mac-Architektur, App-Version und reproduzierbaren Schritten anhand neutraler Beispieldaten. Keine Aufnahmen, privaten Transkripte, Zielinhalte, Benutzerpfade, Schlüssel oder Diagnoseordner hochladen.

Änderungen an Spracherkennung und Texteingabe brauchen gezielte Regressionstests; UI-Änderungen echte Fensterprüfungen in Hell und Dunkel. Ein Screenshot ist kein Funktionsnachweis. Build und Installation bleiben getrennt; bestehende Berechtigungen nicht automatisch zurücksetzen oder anfordern.

`./build.sh --compile-only` kompiliert ohne Installation. `./tools/test.sh` führt die vorhandene Swift-/Python-Prüfsuite aus und erzeugt lokale Artefakte unter checks/. Der Standard-Entwickler-Build erstellt ein lokal ad-hoc-signiertes App-Bundle ohne persönliches Signierzertifikat. Nur der ausdrücklich gewählte alte Signierweg (--local-signed) bleibt an die lokale Entwicklungsidentität gebunden. Private Signierschlüssel werden niemals geteilt.
