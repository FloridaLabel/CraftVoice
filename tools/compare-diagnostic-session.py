#!/usr/bin/env python3
"""Compare opt-in local artifacts without printing dictated text or field values."""
import argparse
import hashlib
import json
import re
from pathlib import Path

FILES = ["whisper-text.txt", "controller-text.txt", "before-send.txt", "queued-unicode.txt", "readback-latest.txt"]

def compare(folder, marker=None):
    values = {name: (folder / name).read_bytes().decode("utf-8") for name in FILES}
    summary = {name: {"utf16": len(text.encode("utf-16-le")) // 2, "sha256": hashlib.sha256(text.encode()).hexdigest()} for name, text in values.items()}
    checks = {"whisper_equals_controller": values[FILES[0]] == values[FILES[1]],
              "controller_equals_before_send": values[FILES[1]] == values[FILES[2]],
              "before_send_equals_queued": values[FILES[2]] == values[FILES[3]],
              "queued_equals_readback": values[FILES[3]] == values[FILES[4]]}
    normalize = lambda text: re.findall(r"\w+", text.casefold())
    if marker:
        expected = normalize(marker)
        checks["marker_present_at_every_stage"] = all(normalize(value)[-len(expected):] == expected for value in values.values())
    full_payload = all(checks.values())
    expected_file = folder / "expected-field.txt"
    expected_state = expected_file.read_bytes().decode("utf-8") == values[FILES[4]] if expected_file.exists() else None
    result = {"checks": checks, "files": summary, "complete_payload_proved": full_payload,
              "complete_expected_field_state_proved": expected_state}
    for name, key in [("recording.json", "recording"), ("whisper-segments.json", "decoder_coverage")]:
        path = folder / name
        if path.exists():
            data = json.loads(path.read_text())
            result[key] = {k: v for k, v in data.items() if k != "segments"}
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("--marker")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = compare(args.session, args.marker)
    except (OSError, ValueError) as error:
        raise SystemExit("Comparison unavailable: " + type(error).__name__)
    encoded = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(encoded)
        args.output.chmod(0o600)
    print(encoded)
    if not result["complete_payload_proved"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
