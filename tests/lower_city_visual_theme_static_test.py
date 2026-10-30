"""Static contract for the in-game Lower City night theme (30/10/2026).

Runs without Godot: python3 tests/lower_city_visual_theme_static_test.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEME = ROOT / "scene/biomes/lower_city/lower_city_visual_theme.gd"
GENERATOR = ROOT / "scene/biomes/biome_generator.gd"


def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


class LowerCityVisualTheme(unittest.TestCase):
    def test_theme_assets_exist_and_are_original(self):
        text = THEME.read_text(encoding="utf-8")
        paths = re.findall(r'preload\("res://([^"]+)"\)', text)
        self.assertGreaterEqual(len(paths), 13)
        for path in paths:
            self.assertTrue(path.startswith("assets/experimental/lower_city_concept/"), path)
            self.assertTrue((ROOT / path).is_file(), path)
        tiles = ROOT / "assets/experimental/lower_city_concept"
        self.assertEqual(png_size(tiles / "street_tile.png"), (64, 60))
        self.assertEqual(png_size(tiles / "catwalk_tile.png"), (64, 20))
        self.assertEqual(png_size(tiles / "wall_tile.png"), (18, 64))

    def test_presentation_only(self):
        text = THEME.read_text(encoding="utf-8")
        for forbidden in ["RandomNumberGenerator", "randf", "randi", "CollisionShape2D.new(", "Area2D.new(",
                          "StaticBody2D.new(", "Input.", "rpc", "persistent_id", "queue_free", "set_meta(\"collision_role\""]:
            self.assertNotIn(forbidden, text)
        self.assertIn("layer.layer = BACKDROP_LAYER", text)
        self.assertRegex(text, r"const BACKDROP_LAYER := -\d+")

    def test_generator_hook_is_data_driven_and_after_signature(self):
        text = GENERATOR.read_text(encoding="utf-8")
        body = text[text.index("func _build_world("):text.index("func _sync_runtime_debug_visibility(")]
        self.assertLess(body.index("generation_signature = _build_generation_signature()"), body.index("_apply_visual_theme()"))
        self.assertLess(body.index("_spawn_required_content(rng, run_manager)"), body.index("_apply_visual_theme()"))
        self.assertIn('&"lower_city_night": preload("res://scene/biomes/lower_city/lower_city_visual_theme.gd")', text)
        # Earlier contracts: the archived temporary renderer stays detached.
        self.assertNotIn("CITY_PRESENTATION", text)
        self.assertNotIn("lower_city_presentation.gd", text)
        self.assertNotIn("TemporaryParallax", THEME.read_text(encoding="utf-8"))

    def test_only_lower_city_enables_the_theme(self):
        self.assertIn("@export var visual_theme: StringName", (ROOT / "scene/biomes/biome_definition.gd").read_text())
        self.assertIn('visual_theme = &"lower_city_night"', (ROOT / "scene/biomes/lower_city/lower_city.tres").read_text())
        for other in ROOT.glob("scene/biomes/*/*.tres"):
            if other.name != "lower_city.tres":
                self.assertNotIn("visual_theme", other.read_text(encoding="utf-8"), other)

    def test_no_private_assets(self):
        text = THEME.read_text(encoding="utf-8")
        for private in ["assets/audio/menu/", "temporary_items/pixelexplosive", "temporary_environment/architecture"]:
            self.assertNotIn(private, text)


if __name__ == "__main__":
    unittest.main()
