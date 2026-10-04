"""Visual Pass 2: preserve functional baselines, verify presentation boundaries."""
import hashlib
import json
import re
import unittest
from pathlib import Path
from godot_parser import GDScene
from gdtoolkit.parser import parser
ROOT = Path(__file__).resolve().parents[1]
FROZEN = {'scene/room_manager.gd': '99ed152a231c8caa47209805fe1f8b60a2e0a3f4ccfddde48914b19855a753d1', 'scene/run_manager.gd': 'e27b4b12ef20221d055292778d26c50ef084af5b584e4f04da327e5df84f16de', 'scene/network/lan_session.gd': '2d9cf22ed8d0482bbbae70fbefbefa2151a77aeb66c6598e8e29ffdbb0331e8c', 'entities/player.gd': '2fa0e9f711a728eb2881d65f5850b131f8a93a1b89171e3433db5b2c5d8403b0', 'entities/player_character_visual.gd': '25e238a050f521915b08378a99914704faeff7a5ca012ddab55e511e5d137ffa', 'entities/Enemy.gd': '259cf08054172a6e5cc9f0fe7c6553438ad22af6b15a8ebbd91887a7fc115130', 'entities/RangedEnemy.gd': '396809a3c8ef43610e6bdeb20d9bd217c00de95a1f2cea5d9ae2494a3727d223', 'entities/HeavyEnemy.gd': '03d08a1a485ecdf8030bfc319588ec7131276e9cd118b0705434dca14a340aef', 'scene/biomes/biome_generator.gd': 'eb2d3ae138d1a01270c61b4dd6a8f3a1bc6929f61d74af2c4bce0b6f114cb8b1', 'scene/casa_jhon_hub.tscn': '7b7b3986afa4fac95080893b9bea3c51ad3d44bc444ab7a0bbbf1caebbf96e2e', 'scene/main_menu_alive.gd': '33f8191a493e3449cae566bebef4d64d84a266b46ebaf4823b60feb083aaee65', 'scene/local_settings.gd': '47ea84edb9eff905c1307b8c8426ff1ab09e6ff9496ae9f9aedd7986ce878715', 'default_bus_layout.tres': 'e9f119bb07e2895d130c9d07d7ad2d05bd4dcf5c67362e08b07814e329e540b4', 'project.godot': '7cb9a081bd12d7d1588559fdba081625810c27facd09b2d56ad3782bc7809254', 'ui/mobile_action_button.gd': 'e42037a4cf1ae87ea8f7655d8a4f784fe9136d4e8ee32f89ae8bbeaeb3d20f32', 'ui/virtual_joystick.gd': 'cc7530596e44acb881c278963bfe4045fc2cdfebcc9edb8bacb27323fe4c9aae'}

class VisualPass2(unittest.TestCase):
    def test_gameplay_network_geometry_and_modal_frozen(self):
        for path, expected in FROZEN.items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), expected, path)

    def test_environment_composition_is_static_nonphysical(self):
        for path in ['scene/casa_jhon_presentation.gd','scene/biomes/lower_city/lower_city_presentation.gd']:
            text = (ROOT/path).read_text()
            parser.parse(text)
            for forbidden in ['func _process','func _physics_process','CollisionShape','Input.','RandomNumberGenerator']:
                self.assertNotIn(forbidden,text)
            for resource in re.findall(r'preload\("res://([^"\n]+)"\)',text):
                self.assertTrue((ROOT/resource).is_file(), resource)
                self.assertNotIn('reference',resource)
        hub=(ROOT/'scene/casa_jhon_hub.gd').read_text()
        self.assertIn('$Environment.hide()',hub)
        self.assertIn('Rect2(0.0, 0.0, 2560.0, 768.0)',hub)

    def test_preview_and_categories_never_equip_or_change_settings(self):
        inventory=(ROOT/'scene/inventory_ui.gd').read_text()
        funcs={m[1]:m[0] for m in re.finditer(r'^func (\w+)\(.*?(?=^func |\Z)',inventory,re.M|re.S)}
        for name in ['_preview_slot','_show_inventory_tab']:
            self.assertNotRegex(funcs[name], r'active_weapon_slot\s*=(?!=)')
            self.assertNotIn('_select_slot(',funcs[name])
        self.assertIn('player.active_weapon_slot = index',funcs['_select_slot'])
        pause=(ROOT/'scene/pause_menu.gd').read_text()
        category=pause.split('func _select_category(',1)[1].split('func _layout_panels',1)[0]
        for forbidden in ['local_settings.','.value =','Input.','show_popup()']:
            self.assertNotIn(forbidden,category)
        self.assertIn('_cancel_options_gesture()',category)
        self.assertIn('settings_scroll.scroll_vertical = 0',category)
        self.assertIn('["JOGO", "CONTROLES", "ÁUDIO"]',pause)
        self.assertIn('get_parent().abandon_current_run()',pause)
        self.assertIn('get_parent().return_to_main_menu()',pause)

    def test_mobile_feedback_and_layers(self):
        feedback=(ROOT/'ui/mobile_presentation_feedback.gd').read_text()
        for forbidden in ['func _input','Input.','position =','scale =','action_press','touch_radius']:
            self.assertNotIn(forbidden,feedback)
        self.assertIn('active_touch_index >= 0',feedback)
        GDScene.load(str(ROOT/'scene/pause_menu.tscn'))
        GDScene.load(str(ROOT/'scene/main.tscn'))
        hud=(ROOT/'ui/gameplay_hud_presentation.gd').read_text()
        self.assertIn('LOW_HP_RATIO := 0.25',hud)
        self.assertIn('layer.layer = 39',hud)
        self.assertIn('face.region = Rect2',hud)
        self.assertIn('Control.MOUSE_FILTER_IGNORE',hud)

if __name__ == '__main__':
    unittest.main()
