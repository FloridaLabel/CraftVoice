#!/usr/bin/env python3
"""Opt-in real-model regression; local existing model only, no app input/downloads.
Fixtures must be synthetic/non-personal: speech starts at 30s with a subsecond
ending word, and the same prefix followed by silence. Output remains local.
"""
import argparse
from pathlib import Path
import subprocess
import json
import os
import re

parser = argparse.ArgumentParser()
parser.add_argument("--speech-fixture", type=Path, required=True)
parser.add_argument("--silence-fixture", type=Path, required=True)
parser.add_argument("--noise-fixture", type=Path)
parser.add_argument("--output-dir", type=Path, required=True)
parser.add_argument("--word", default="Ende")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
probe = root / ".build/release/CraftVoiceModelProbe"
args.output_dir.mkdir(mode=0o700, parents=True, exist_ok=True)

def replay(name, audio, legacy=False):
    output = args.output_dir / (name + ".txt")
    with (args.output_dir / (name + ".log")).open("w") as log:
        subprocess.run([str(probe), "--audio", str(audio.resolve()), "--output", str(output.resolve())] + (["--legacy-windows"] if legacy else []), stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
    os.chmod(output, 0o600)
    return output.read_text()

old = replay("legacy-windows", args.speech_fixture, True)
fixed = replay("balanced-windows", args.speech_fixture)
silence = replay("silence-balanced", args.silence_fixture)
ends = lambda text: text.casefold().rstrip(" .!?\n").endswith(args.word.casefold())
checks = {"old_setting_omits_end_word": not ends(old), "fixed_setting_preserves_end_word": ends(fixed), "silent_tail_does_not_add_text": silence == old}
observations = {}
if args.noise_fixture:
    noise = replay("noise-balanced", args.noise_fixture)
    old_words = re.findall(r"\w+", old.casefold())
    noise_words = re.findall(r"\w+", noise.casefold())
    # ASR can change word forms or numeric spelling at a different window boundary.
    # This negative control checks for extra/duplicated output and the intact ending,
    # not byte-identical recognition of the same speech in different contexts.
    checks["quiet_noise_tail_does_not_append_or_duplicate_text"] = len(noise_words) == len(old_words) and noise_words[-8:] == old_words[-8:]
    observations["quiet_noise_full_transcript_identical"] = noise == old
    observations["baseline_word_count"] = len(old_words)
    observations["quiet_noise_word_count"] = len(noise_words)
(args.output_dir / "result.json").write_text(json.dumps({"checks": checks, "observations": observations}, indent=2))
print(json.dumps(checks, sort_keys=True))
if not all(checks.values()):
    raise SystemExit("FAIL real-model tail regression; inspect local artifacts")
print("PASS real-model tail regression; no target-app input")
