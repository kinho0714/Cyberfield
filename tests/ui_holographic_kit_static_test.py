"""Static contract for the holographic UI kit and font (Operação Renascimento, 30/10/2026).

Runs without Godot: python3 tests/ui_holographic_kit_static_test.py
"""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class UiHolographicKit(unittest.TestCase):
    def test_global_theme_uses_the_licensed_font(self):
        self.assertIn('theme/custom="res://assets/ui/theme/cyberfield_theme.tres"', (ROOT / "project.godot").read_text())
        theme = (ROOT / "assets/ui/theme/cyberfield_theme.tres").read_text()
        self.assertIn("res://assets/fonts/pixelify_sans/PixelifySans-Regular.woff2", theme)
        self.assertIn("SIL Open Font License", (ROOT / "assets/fonts/pixelify_sans/OFL.txt").read_text())
        for weight in ("Regular", "Bold"):
            data = (ROOT / f"assets/fonts/pixelify_sans/PixelifySans-{weight}.woff2").read_bytes()
            self.assertEqual(data[:4], b"wOF2")

    def test_manifests_match_regenerated_textures(self):
        for base in ("assets/ui/menu_panels", "assets/ui/gameplay_hud"):
            data = json.loads((ROOT / base / "used_assets.json").read_text())
            entries = data if isinstance(data, list) else data.values()
            for entry in entries:
                digest = hashlib.sha256((ROOT / base / entry["file"]).read_bytes()).hexdigest()
                self.assertEqual(digest, entry["sha256"], entry["file"])

    def test_icons_sit_on_the_grid_the_hud_scales(self):
        def size(path):
            raw = (ROOT / path).read_bytes()
            return int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big")
        for name in ("heal_icon", "icon_attr_health", "icon_attr_intelligence", "icon_attr_strength", "money_icon"):
            self.assertEqual(size(f"assets/ui/gameplay_hud/assets/shared/icons/{name}.png"), (48, 48))
        for name in ("attack1_icon", "attack2_icon", "dash_icon", "jump_icon", "use_icon"):
            self.assertEqual(size(f"assets/ui/gameplay_hud/assets/mobile/actions/{name}.png"), (64, 64))


if __name__ == "__main__":
    unittest.main()
