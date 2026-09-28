import hashlib
import tempfile
import unittest
from pathlib import Path

from scripts.verify_artifact import validate_record


class VerifyArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        payload = b"known n200 artifact\n"
        (self.root / "downloads").mkdir()
        (self.root / "downloads" / "boot.img").write_bytes(payload)
        self.good = {
            "name": "lineage-recovery-boot",
            "path": "downloads/boot.img",
            "sha256": hashlib.sha256(payload).hexdigest(),
            "device": "dre",
            "role": "boot",
            "source_url": "https://download.lineageos.org/devices/dre/builds",
        }

    def tearDown(self):
        self.temp.cleanup()

    def test_valid_record_has_no_errors(self):
        self.assertEqual(validate_record(self.good, self.root), [])

    def test_wrong_hash_is_rejected(self):
        record = {**self.good, "sha256": "0" * 64}
        self.assertIn("sha256 mismatch", validate_record(record, self.root))

    def test_missing_file_is_rejected(self):
        record = {**self.good, "path": "downloads/missing.img"}
        self.assertIn("artifact is missing", validate_record(record, self.root))

    def test_n100_target_is_rejected(self):
        record = {**self.good, "device": "billie2"}
        self.assertIn("device must be dre or DE2117", validate_record(record, self.root))

    def test_missing_source_url_is_rejected(self):
        record = {**self.good, "source_url": ""}
        self.assertIn("source_url must use https", validate_record(record, self.root))

    def test_unknown_role_is_rejected(self):
        record = {**self.good, "role": "dtbo"}
        self.assertIn("role is not allowed", validate_record(record, self.root))

    def test_path_outside_project_is_rejected(self):
        record = {**self.good, "path": "../boot.img"}
        self.assertIn("path leaves project root", validate_record(record, self.root))


if __name__ == "__main__":
    unittest.main()
