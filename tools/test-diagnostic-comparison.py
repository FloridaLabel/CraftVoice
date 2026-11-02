#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("diagnostic_comparison", Path(__file__).with_name("compare-diagnostic-session.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ComparisonTests(unittest.TestCase):
    def fixture(self, folder, text="Anfang. Ende."):
        for name in module.FILES:
            (folder / name).write_text(text)
        (folder / "expected-field.txt").write_text(text + "ChatGPT fragen\n")

    def test_payload_and_original_field_state_are_distinct(self):
        with tempfile.TemporaryDirectory() as path:
            folder = Path(path); self.fixture(folder)
            result = module.compare(folder, "Ende.")
            self.assertTrue(result["complete_payload_proved"])
            self.assertFalse(result["complete_expected_field_state_proved"])

    def test_missing_end_is_not_accepted_even_if_transfer_is_lossless(self):
        with tempfile.TemporaryDirectory() as path:
            folder = Path(path); self.fixture(folder, "Anfang.")
            result = module.compare(folder, "Ende.")
            self.assertFalse(result["complete_payload_proved"])
            self.assertTrue(result["checks"]["before_send_equals_queued"])
            self.assertFalse(result["checks"]["marker_present_at_every_stage"])

    def test_truncated_event_payload_is_detected(self):
        with tempfile.TemporaryDirectory() as path:
            folder = Path(path); self.fixture(folder)
            (folder / "queued-unicode.txt").write_text("Anfang.")
            result = module.compare(folder)
            self.assertFalse(result["complete_payload_proved"])
            self.assertFalse(result["checks"]["before_send_equals_queued"])

    def test_line_ending_difference_is_not_silently_normalized(self):
        with tempfile.TemporaryDirectory() as path:
            folder = Path(path); self.fixture(folder, "Anfang.\r\nEnde.")
            (folder / "readback-latest.txt").write_text("Anfang.\nEnde.")
            result = module.compare(folder)
            self.assertFalse(result["complete_payload_proved"])
            self.assertFalse(result["checks"]["queued_equals_readback"])

    def test_missing_artifacts_cannot_produce_success(self):
        with tempfile.TemporaryDirectory() as path:
            with self.assertRaises(FileNotFoundError): module.compare(Path(path))

if __name__ == "__main__":
    unittest.main(verbosity=2)
