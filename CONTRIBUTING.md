# Mitwirken

Dieser Veröffentlichungsentwurf ist noch nicht freigegeben. Vor der ersten öffentlichen Nutzung wird die Lizenz für eigenen Code festgelegt.

Beschreibe Fehler mit macOS-Version, Mac-Architektur, App-Version und reproduzierbaren Schritten anhand neutraler Beispieldaten. Keine Aufnahmen, privaten Transkripte, Zielinhalte, Benutzerpfade, Schlüssel oder Diagnoseordner hochladen.

Änderungen an Spracherkennung und Texteingabe brauchen gezielte Regressionstests; UI-Änderungen echte Fensterprüfungen in Hell und Dunkel. Ein Screenshot ist kein Funktionsnachweis. Build und Installation bleiben getrennt; bestehende Berechtigungen nicht automatisch zurücksetzen oder anfordern.

`./build.sh --compile-only` kompiliert ohne Installation. `./tools/test.sh` führt die vorhandene Swift-/Python-Prüfsuite aus und erzeugt lokale Artefakte unter checks/. Vollständige signierte App-Builds sind derzeit an die lokale Entwicklungsidentität gebunden. Private Signierschlüssel werden niemals geteilt.
