"""Sprite-sheet integrity (Operação Renascimento, 30/10/2026).

Regression guard for the audit defects: poses cut by the cell grid (wall slide),
generation debris and broken Heavy sheets. Needs Pillow:
    python3 tests/sprite_sheet_integrity_static_test.py
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER_FRAMES = {"idle": 4, "walk_run": 6, "jump_air_fall": 4, "dash": 4, "ground_slam": 5, "hurt": 2,
                 "downed_death": 3, "revive_ally": 5, "wall_slide": 4, "wall_climb": 4}
HEAVY_FRAMES = {"idle": 4, "walk_run": 6, "attack_shoot": 6, "jump_air_fall": 4, "hurt": 2, "death": 3}


def frames(path, count):
    from PIL import Image
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    assert width % count == 0, f"{path}: width {width} not divisible by {count}"
    cell = width // count
    return [image.crop((i * cell, 0, (i + 1) * cell, height)) for i in range(count)]


class SpriteSheetIntegrity(unittest.TestCase):
    def setUp(self):
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest("Pillow not installed")

    def assert_whole_frames(self, path, count, check_edges=True):
        for index, frame in enumerate(frames(path, count)):
            alpha = frame.getchannel("A")
            box = alpha.point(lambda v: 255 if v > 16 else 0).getbbox()
            self.assertIsNotNone(box, f"{path.name} frame {index} is empty")
            if check_edges:
                self.assertGreater(box[0], 0, f"{path.name} frame {index} touches the left cell edge")
                self.assertLess(box[2], frame.width, f"{path.name} frame {index} touches the right cell edge")

    def test_player_sheets(self):
        for character in ("jhon", "jackson", "kai", "spark"):
            for path in sorted((ROOT / "assets/players" / character).glob("*.png")):
                key = next((k for k in PLAYER_FRAMES if k in path.name), None)
                if key is None:
                    continue
                self.assert_whole_frames(path, PLAYER_FRAMES[key], check_edges=key == "wall_slide")

    def test_heavy_sheets_are_rebuilt_whole(self):
        for key, count in HEAVY_FRAMES.items():
            path = ROOT / f"assets/enemies/heavy/heavy_{key}_v1.png"
            self.assert_whole_frames(path, count)
            # No leftover cyan caption text from the corrupted generation sheets.
            from PIL import Image
            pixels = Image.open(path).convert("RGBA").getdata()
            caption = sum(1 for r, g, b, a in pixels if a > 200 and b > 180 and g > 180 and r < 100)
            self.assertEqual(caption, 0, f"{path.name}: caption-coloured pixels")


if __name__ == "__main__":
    unittest.main()
