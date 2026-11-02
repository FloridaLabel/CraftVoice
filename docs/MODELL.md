# Lokales Sprachmodell

CraftVoice lädt zur Laufzeit ausschließlich lokale Assets. Das separate Python-Werkzeug benötigt Internetzugang und verwendet feste Quellen:

- Core ML: `argmaxinc/whisperkit-coreml`, Revision `0f63a7800b00dd0226abd051b906c246e1907482`, Unterordner `openai_whisper-large-v3-v20240930_turbo`.
- Tokenizer und Konfiguration: `openai/whisper-large-v3-turbo`, Revision `41f01f3fe87f28c78e2fbf8b568835947dd65ed9`.
- Erwarteter Bestand: 24 Core-ML-/Metadatendateien und neun OpenAI-Dateien, insgesamt 1.643.030.255 Byte laut vorhandener Bereitstellungsdokumentation. Keine Gewichte im Repository.

Benötigt werden MelSpectrogram, AudioEncoder, TextDecoder und kompatible lokale Tokenizerdaten. Das Werkzeug übernimmt zusätzlich den vollständigen festgelegten Variantenbestand einschließlich optionalem ContextPrefill. Gleichnamige Metadaten liegen getrennt in coreml-metadata. Das Manifest protokolliert Größe, Quellrevision und Hash; --verify-only prüft ohne Netzwerk.

```sh
python3 tools/provision-local-model.py
python3 tools/provision-local-model.py --verify-only
```

Alternativer Zielordner: `--folder /Pfad/zum/Modellordner`. Die App startet das Werkzeug niemals selbst. Bei einem bereits vollständigen Ordner genügt die lokale Auswahl in CraftVoice.

Geplanter öffentlicher Weg: kleine App getrennt vom Modell, dokumentierter bewusster Download aus offiziellen Quellen. Noch kein eigener Modellmirror und kein Modell-Release. Vor der Weitergabe eines Modellarchivs sind die Lizenztexte und Notices der exakten beiden Revisionen beizulegen, der Bestand auf einem weiteren Mac zu prüfen und eine SHA-256-Prüfsumme zu veröffentlichen. Das aktuelle Werkzeug lädt nicht automatisch die repositoryweiten Lizenzdateien des Tokenizers mit; diese Distributionslücke bleibt vor einem eigenen Modellpaket zu schließen. Siehe THIRD_PARTY_NOTICES.md.
