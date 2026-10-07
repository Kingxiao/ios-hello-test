import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "export_evidence", Path(__file__).resolve().parents[1] / "export-evidence.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class EvidenceTests(unittest.TestCase):
    def fixture(self, raw):
        attachments = []
        for language in ("en", "zh-Hans"):
            for size in ("default", "ax-xxxl"):
                for state in ("count-2", "reset-0"):
                    name = f"probe-{language}-{size}-{state}"
                    filename = str(len(attachments)) + ".png"
                    (raw / filename).write_bytes(b"\x89PNG\r\n\x1a\nfixture")
                    attachments.append({
                        "exportedFileName": filename,
                        "suggestedHumanReadableName": name + "_1_11111111-1111-1111-1111-111111111111.png",
                    })
        (raw / "manifest.json").write_text(json.dumps([{"attachments": attachments}]))
        return attachments

    def test_complete_matrix_exports_named_files(self):
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory)
            self.fixture(raw)
            exported = module.export(raw, raw / "output", "probe")
            self.assertEqual(len(exported), 8)
            self.assertTrue((raw / "output/probe-zh-Hans-ax-xxxl-reset-0.png").exists())

    def test_missing_screenshot_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory)
            attachments = self.fixture(raw)
            attachments.pop()
            (raw / "manifest.json").write_text(json.dumps([{"attachments": attachments}]))
            with self.assertRaisesRegex(ValueError, "Missing screenshots"):
                module.export(raw, raw / "output", "probe")

    def test_flow_evidence_required_when_requested(self):
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory)
            self.fixture(raw)
            with self.assertRaisesRegex(ValueError, "flow-01-launch"):
                module.export(raw, raw / "output", "probe", with_flow=True)

    def test_corrupt_attachment_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory)
            self.fixture(raw)
            (raw / "0.png").write_bytes(b"not a screenshot")
            with self.assertRaisesRegex(ValueError, "Invalid PNG"):
                module.export(raw, raw / "output", "probe")
