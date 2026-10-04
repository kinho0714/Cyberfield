"""Import gate regression using an existing asset; creates no artwork."""
import copy
import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("validator", ROOT / "tools/validate_visual_asset_manifest.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class ImportContract(unittest.TestCase):
    def setUp(self):
        path = "assets/ui/gameplay_hud/assets/shared/icons/heal_icon.png"
        width, height, _ = VALIDATOR.png_info(ROOT / path)
        self.manifest = {"assets": [{"id": "test_icon", "category": "ui", "stage": "runtime",
            "runtime_approved": True, "source": "existing test fixture", "version": "test",
            "intended_runtime_use": "test only", "path": path, "dimensions": [width, height],
            "requires_transparency": True, "no_embedded_text": True, "no_concept_border": True,
            "no_accidental_matte": True, "safe_bounds": [0, 0, width, height], "padding": [0, 0, 0, 0]}]}

    def test_existing_rgba_png(self):
        self.assertEqual(VALIDATOR.validate(self.manifest), [])

    def test_rejected_contracts(self):
        for change in [{"stage": "concept"}, {"runtime_approved": False}, {"no_embedded_text": False},
                       {"dimensions": [1, 1]}, {"sha256": "incorrect"}, {"id": "Localized Name"},
                       {"path": "../outside.png"}, {"frame_count": 999999, "cell_size": [1, 1]},
                       {"safe_bounds": [0, 0, 999999, 1]}]:
            with self.subTest(change=change):
                altered = copy.deepcopy(self.manifest)
                altered["assets"][0].update(change)
                self.assertTrue(VALIDATOR.validate(altered))

    def test_duplicate_ids(self):
        self.manifest["assets"].append(copy.deepcopy(self.manifest["assets"][0]))
        self.assertTrue(VALIDATOR.validate(self.manifest))


if __name__ == "__main__":
    unittest.main()
