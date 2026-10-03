"""Offline contracts; the native popup cycle requires the Godot smoke test."""
import hashlib
import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


class DropdownRainHotfix(unittest.TestCase):
    def test_event_driven_modal_lifecycle(self):
        text = (ROOT / 'scene/main_menu_alive.gd').read_text()
        functions = {m[1]: m[0] for m in re.finditer(r'^func (\w+)\(.*?(?=^func |\Z)', text, re.M | re.S)}
        self.assertIn('about_to_popup.connect(_popup_opening.bind(control))', text)
        self.assertIn('popup_hide.connect(_popup_closed)', text)
        self.assertIn('window_input.connect(_popup_window_input)', text)
        for name in ['_process', '_move_focus']:
            for forbidden in ['show_popup(', '.popup(', 'emulate_mouse_from_touch', '.select(', 'item_selected.emit']:
                self.assertNotIn(forbidden, functions[name])
        self.assertEqual(hashlib.sha256(functions['_move_focus'].encode()).hexdigest(), '586281b7a020297bf693f0e63e5b203f94151ce875c937cc96a9f9dd26e1ede8')
        self.assertIn('Input.emulate_mouse_from_touch = true', functions['_popup_opening'])
        self.assertIn('Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)', functions['_finish_popup_input'])
        for name in ['_finish_popup_input', '_exit_tree']:
            self.assertIn('Input.emulate_mouse_from_touch = previous_mouse_emulation', functions[name])
        self.assertNotIn('var selected := focus.get_selected_items()', text)

    def test_callbacks_and_native_controls_preserved(self):
        pause = (ROOT / 'scene/pause_menu.gd').read_text()
        lan = (ROOT / 'scene/network/lan_lobby.gd').read_text()
        self.assertIn('zoom_option.item_selected.connect(_set_camera_zoom)', pause)
        self.assertIn('zoom_option.show_popup()', pause)
        self.assertIn('difficulty.show_popup()', lan)
        self.assertIn('difficulty.get_item_metadata(difficulty.selected)', lan)
        self.assertIn('pointing/emulate_mouse_from_touch=false', (ROOT / 'project.godot').read_text())

    def test_rain_density(self):
        text = (ROOT / 'scene/animated_menu_background.gd').read_text()
        amount = int(re.search(r'rain_base_amount: int = (\d+)', text)[1])
        self.assertEqual(amount, 560)
        self.assertEqual(int(amount * .25), 140)
        self.assertIn('CPUParticles2D.new()', text)
        self.assertIn('initial_velocity_min = speed * 0.82', text)
        self.assertIn('initial_velocity_max = speed * 1.18', text)


if __name__ == '__main__':
    unittest.main()
