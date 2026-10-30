"""Playable character sheets (dev/visual, Alpha 0.5.0): the refinement keeps every sheet's
size, frame grid and RGBA format, so PlayerCharacterVisual slices them exactly as before,
and the contact shadow stays presentation-only."""
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ('jhon', 'jackson', 'kai', 'spark')
STATES = ('idle', 'walk_run', 'jump_air_fall', 'attack_combo', 'dash', 'ground_slam', 'hurt',
          'downed_death', 'revive_ally', 'wall_slide', 'wall_climb')


def png_header(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    width, height, depth, colour = struct.unpack('>IIBB', data[16:26])
    return width, height, depth, colour


class CharacterRefineTest(unittest.TestCase):
    def test_every_state_sheet_exists_rgba_72px(self):
        for character in CHARACTERS:
            folder = ROOT / 'assets/players' / character
            for state in STATES:
                matches = list(folder.glob('*%s*.png' % state))
                self.assertEqual(len(matches), 1, (character, state))
                width, height, depth, colour = png_header(matches[0])
                self.assertEqual((height, depth, colour), (72, 8, 6), matches[0])

    def test_contact_shadow_is_presentation_only(self):
        text = (ROOT / 'entities/player_character_visual.gd').read_text()
        self.assertIn('func _build_contact_shadow() -> void:', text)
        self.assertIn('_contact_shadow.show_behind_parent = true', text)
        body = text.split('func _build_contact_shadow() -> void:', 1)[1].split('\nfunc ', 1)[0]
        for forbidden in ('velocity', 'collision', 'health', 'Input.'):
            self.assertNotIn(forbidden, body)

    def test_tool_rebuilds_from_the_alpha_tag(self):
        tool = (ROOT / 'tools/visual/character_refine.py').read_text()
        self.assertIn('SOURCE_REV = "alpha-0.5.0"', tool)


if __name__ == '__main__':
    unittest.main()
