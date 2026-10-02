"""Structural/numeric checks only. These do not validate Godot runtime or appearance."""
import math
import re
import unittest
from pathlib import Path
from animated_menu_background_static_test import node_blocks

ROOT = Path(__file__).resolve().parents[1]


class Pass6Contract(unittest.TestCase):
    def test_cover_shift_has_no_empty_edge(self):
        for width, height in [(1280, 720), (1536, 689), (1605, 720), (1920, 1080), (1024, 768)]:
            scale = max(width / 1664, height / 936)
            excess = max(0, 936 * scale - height)
            x = (width - 1664 * scale) / 2
            y = min(0, max(-excess, -excess / 2 + 24 * height / 720))
            self.assertLessEqual(x, 1e-8)
            self.assertLessEqual(y, 0)
            self.assertGreaterEqual(x + 1664 * scale + 1e-8, width)
            self.assertGreaterEqual(y + 936 * scale + 1e-8, height)
            if width * 9 == height * 16:
                self.assertAlmostEqual(y, 0)

    def test_settings_paths_and_scroll(self):
        scene = (ROOT / 'scene/pause_menu.tscn').read_text()
        nodes = node_blocks(scene)
        script = (ROOT / 'scene/pause_menu.gd').read_text()
        for path in re.findall(r'\$([\w/]+)', script):
            self.assertIn(path, nodes, path)
        content = 'Overlay/Center/SettingsPage/Scroll/Content/'
        for bus in ['Master', 'Music', 'SFX', 'Dialogue']:
            self.assertIn(content + bus + 'Label', nodes)
            slider = nodes[content + bus + 'Volume']
            self.assertIn('max_value = 100.0', slider)
            self.assertIn('Vector2(560, 56)', slider)
        self.assertIn('follow_focus = true', nodes['Overlay/Center/SettingsPage/Scroll'])
        self.assertIn('Overlay/Center/SettingsPage/Back', nodes)
        self.assertIn('settings_scroll.get_global_rect().has_point(position)', script)

    def test_buses_and_safe_conversion(self):
        layout = (ROOT / 'default_bus_layout.tres').read_text()
        self.assertEqual(re.findall(r'bus/\d/name = &"(.*?)"', layout), ['Master', 'Music', 'SFX', 'Dialogue'])
        self.assertEqual(layout.count('/send = &"Master"'), 3)
        settings = (ROOT / 'scene/local_settings.gd').read_text()
        self.assertIn('config.get_value("audio", String(bus), 1.0)', settings)
        self.assertIn('config.set_value("audio", String(bus), audio_volumes[bus])', settings)
        self.assertIn('AudioServer.set_bus_mute(index, volume <= 0.0)', settings)
        self.assertIn('linear_to_db(maxf(volume, 0.0001))', settings)
        for value in [0, .01, .25, .5, 1]:
            db = 20 * math.log10(max(value, .0001))
            self.assertTrue(math.isfinite(db))
            if value:
                self.assertAlmostEqual(10 ** (db / 20), value)

    def test_dropdown_semantics(self):
        pause = (ROOT / 'scene/pause_menu.gd').read_text()
        lan = (ROOT / 'scene/network/lan_lobby.gd').read_text()
        self.assertIn('zoom_option.show_popup()', pause)
        self.assertIn('difficulty.show_popup()', lan)
        self.assertNotIn('_cycle_camera_zoom', pause)
        self.assertNotIn('difficulty.select(wrapi', lan)
        menu = (ROOT / 'scene/main_menu_alive.gd').read_text()
        self.assertNotIn('var selected := focus.get_selected_items()', menu)
        self.assertNotIn('focus.ensure_current_is_visible()', menu)

    def test_environment_tuning_and_cloud_masks(self):
        script = (ROOT / 'scene/animated_menu_background.gd').read_text()
        self.assertIn('var rain_base_amount: int = 400', script)
        self.assertIn('int(rain_base_amount * 0.25)', script)
        self.assertIn('var cloud_back_speed: float = 7.0', script)
        self.assertIn('var cloud_front_speed: float = 11.5', script)
        scene = (ROOT / 'scene/animated_menu_background.tscn').read_text()
        for name in ['back_lightmask', 'front_lightmask']:
            block = re.search(r'\[sub_resource type="ShaderMaterial" id="' + name + r'"\](.*?)(?=\n\[)', scene, re.S)[1]
            self.assertNotIn('density_curve', block)
        self.assertIn('shader_parameter/density_curve = 1.35', scene)


if __name__ == '__main__':
    unittest.main()
