import unittest
import re
import hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
FROZEN = {'_move_focus': '0e2a93bf0edeef7f0d6039169805f263773c06a6635cba63433efbbe90d125e1', '_popup_opening': '72119dd5c4ed0dfc984b9769d5cccad049af99d43f9fd699ad6cfb03dfbcc1c4', '_popup_window_input': '2c9a97a7df6a8634fdec745f8b99ed9e4a991e7c82124d9c549644fc86298c59', '_popup_closed': '00a9e2714cc3c087a3124570e8901f0a856f24d6af5b7c23ba6f42194f66fa00', '_finish_popup_input': 'bc9ff43e283dbcdca4a984c23e1b5fedc0fbfd3cabdcf868f4fc948b97c22e14', '_exit_tree': '0ccb343ea858071519a9c00f5186141c607226b93308cc154bdb9e4cdc4193a2'}


class Hotfix2(unittest.TestCase):
    def test_approved_modal_unchanged(self):
        text = (ROOT / 'scene/main_menu_alive.gd').read_text()
        functions = {m[1]:m[0] for m in re.finditer(r'^func (\w+)\(.*?(?=^func |\Z)', text, re.M | re.S)}
        for name, expected in FROZEN.items():
            self.assertEqual(hashlib.sha256(functions[name].rstrip().encode()).hexdigest(), expected, name)

    def test_gesture_direction_and_no_press_mutation(self):
        text = (ROOT / 'scene/pause_menu.gd').read_text()
        gesture = text.split('func _handle_options_gesture', 1)[1].split('func _cancel_options_gesture', 1)[0]
        press = gesture.split('if event.pressed:', 1)[1].split('if event.index != options_touch_index:', 1)[0]
        self.assertNotIn('_update_touch_slider(', press)
        self.assertNotIn('grab_focus()', press)
        self.assertIn('options_gesture = 1', gesture)
        self.assertIn('options_gesture = 2', gesture)
        self.assertIn('options_scroll_origin - int(round(displacement.y))', gesture)
        self.assertIn('not event.canceled', gesture)
        self.assertIn('follow_focus = true', (ROOT / 'scene/pause_menu.tscn').read_text())

    def test_shared_popup_style_only(self):
        text = (ROOT / 'scene/main_menu_alive.gd').read_text()
        self.assertIn('_style_dropdown(control.get_popup())', text)
        style = text.split('func _style_dropdown', 1)[1]
        for key in ['panel', 'hover', 'font_color', 'font_hover_color', 'font_disabled_color']:
            self.assertIn('"' + key + '"', style)
        for forbidden in ['show_popup(', '.connect(', 'Input.', '.select(', '.hide(']:
            self.assertNotIn(forbidden, style)


if __name__ == '__main__':
    unittest.main()
