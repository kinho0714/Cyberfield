"""Casa Jhon house stages 0-3 (Operação Renascimento): art exists for every stage, the
presentation and the hub pick it from MetaProgression.house_stage, and the frozen hub
scene is untouched."""
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    assert head[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II', head[16:24])


class HubHouseStagesTest(unittest.TestCase):
    def test_every_stage_has_art_and_lights(self):
        text = (ROOT / 'scene/casa_jhon_presentation.gd').read_text()
        for kind in ('back', 'lights'):
            paths = re.findall(r'"res://(assets/environment/hub/hub_stage(\d)_%s\.png)"' % kind, text)
            self.assertEqual([int(n) for _, n in paths], [0, 1, 2, 3], kind)
            for path, _ in paths:
                self.assertEqual(png_size(ROOT / path), (1280, 384), path)

    def test_stage_selection_is_presentation_only(self):
        presentation = (ROOT / 'scene/casa_jhon_presentation.gd').read_text()
        self.assertIn('static func house_stage_of(state: Dictionary) -> int:', presentation)
        self.assertNotIn('save_profile', presentation)
        self.assertNotIn('set_house_stage', presentation)
        hub = (ROOT / 'scene/casa_jhon_hub.gd').read_text()
        self.assertIn('PRESENTATION.house_stage_of(progression)', hub)
        self.assertIn('PRESENTATION.STAGE_LIGHTS[house_stage]', hub)
        self.assertNotIn('set_house_stage', hub)

    def test_preview_scene_is_outside_the_game_flow(self):
        preview = 'res://tests/visual/hub_house_stages_preview.tscn'
        for path in ROOT.glob('scene/**/*'):
            if path.suffix in ('.gd', '.tscn', '.tres'):
                self.assertNotIn(preview, path.read_text(errors='ignore'), path)
        self.assertNotIn('meta_progression', (ROOT / 'tests/visual/hub_house_stages_preview.gd').read_text())


if __name__ == '__main__':
    unittest.main()
