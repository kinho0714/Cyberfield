"""Checkpoint 4: official visual assets and frozen functional contracts.
Run with unittest; requires Pillow, gdtoolkit and godot-parser.
"""
import hashlib
import json
import re
import unittest
from pathlib import Path
from PIL import Image
from godot_parser import GDScene
from gdtoolkit.parser import parser
ROOT = Path(__file__).resolve().parents[1]
FROZEN = {'scene/pause_menu.gd::_input': '69fb54e9988826eb626eae2315871b54fa1a2189763617b20bfb96a1162c8ec5', 'scene/pause_menu.gd::open_title_settings': 'f893a280076b2fedaaa66f9214d012aacfd18876936ef30c337b27b28b66852f', 'scene/pause_menu.gd::_settings_back': 'e74c81d22dcc4e5a21a412be949357746cee65dae42a18e9ce894ac6912926ec', 'scene/pause_menu.gd::toggle_menu': 'ac17f25a76d00e4f01410cc1583f68c8b35d752376acad15f3965ec09bafff69', 'scene/pause_menu.gd::open_menu': '6d1c987cae48f8dc3b6957e025dd5f24d2edcb4f2db4f099b30f3ecc84f70f6f', 'scene/pause_menu.gd::close_menu': '339164a4d9c066e53be9b7573a9041be0c0eca79565954fe1863fddd6d55c87f', 'scene/pause_menu.gd::_block_local_gameplay_input': '39b541075aea553d0f909cab661ea197751b8559c908aacefce416d1f4d3047d', 'scene/pause_menu.gd::_show_main': '81ccbe28ee715064c1771241680e4e6a636b0ecdb57ca43873b5b66aff1dbffc', 'scene/pause_menu.gd::_touch_hits': 'ee94949cd1df9d18c9bfa85f2139f66fa04a82787020dd14793c053a954c1687', 'scene/pause_menu.gd::_update_touch_slider': '5ebdfc18d31771902663f5b77faa15e67d03f9a20ea513173596577836686355', 'scene/pause_menu.gd::_open_inventory': '3569e357d67295cc8a652544520f84f4bfa230160f45c4fb7aedc80763c9edf6', 'scene/pause_menu.gd::_load_controls': 'f2c866aad0167738ebded95437bf758493ef413b5162b2c211c9db78e1f6e490', 'scene/pause_menu.gd::_set_camera_zoom': '04b74ba0cf6ab0cccd17b47263bbdf3da78fc9366a73de1a4c41ed9e0a7edb9a', 'scene/pause_menu.gd::_set_touch_scale': '8e1c0ae8b517e0be126a897f76976cb55d2ab7fd0e7cfcfc745c6c8b85cefd86', 'scene/pause_menu.gd::_set_debug_hud': '91384ef767e4f9f41032e1a54b373a873fb49affdad39feb9b81b3ae2dbe41f1', 'scene/pause_menu.gd::_abandon_run': '22fb3977d59807bbd366882d0964f87ff07f9473ed0f7c2f9820b5995a0857ff', 'scene/pause_menu.gd::_return_to_main_menu': '1e86d52eec23982787c2a270c97f20bbe705bd6505363a54696c39701a1f39c4', 'scene/pause_menu.gd::_set_audio_volume': '7cbd31d6cb994db774a2b9d7efaa81879acaf6f24a09af0ebe92dd3be4621f6a', 'scene/pause_menu.gd::_update_audio_label': '31c701f6640dd2f1f952f557741af597e2190696922d8f90f3f3cf163e9aad8d', 'scene/pause_menu.gd::_handle_options_gesture': '811e6b602224aa1da3bebc981246dfd560fda5ff01c5ee6372d04fa4bda9daa8', 'scene/pause_menu.gd::_cancel_options_gesture': '123caa00ae68d732d8b06c78f6863156a9186f68afd96646027a37d6753281a1', 'scene/inventory_ui.gd::toggle_inventory': '5c8af5f16ad6ea5b697335370c0cc722636989ae9cea66cc705b863e83b8673e', 'scene/inventory_ui.gd::open_from_pause': '12f3ceb50219de939790f0ad5a1296e85fdc702f3c5532a99240c8ea11111ea4', 'scene/inventory_ui.gd::close_inventory': 'c91c6672a5f52ba69f26c2cd3e0a8e371a11a4d766237e696e04b709df9401a9', 'scene/inventory_ui.gd::_select_slot': '19ab8671f1eb60ab59abe5f111f752c969ba81d3e2b95bb048f20065177b8c70', 'scene/inventory_ui.gd::_local_player': '5a10179bf48a8d34678cfc79bdac43cda4bd46a75ad805c7b9f9fd989a8e4daf', 'scene/inventory_ui.gd::_block_local_players': '66b33464c958db8fa7c86e6303d3d4a7266319167cf9eacc113a45a83b88bd81', 'scene/inventory_ui.gd::_touch_hits': 'c7dc54d7c44d14d5d0e01517ed198bb6f8fec2d5d47a069d139a2565d21dd959'}
FILES = {'scene/main_menu_alive.gd': '33f8191a493e3449cae566bebef4d64d84a266b46ebaf4823b60feb083aaee65', 'scene/local_settings.gd': '47ea84edb9eff905c1307b8c8426ff1ab09e6ff9496ae9f9aedd7986ce878715', 'default_bus_layout.tres': 'e9f119bb07e2895d130c9d07d7ad2d05bd4dcf5c67362e08b07814e329e540b4', 'project.godot': '7cb9a081bd12d7d1588559fdba081625810c27facd09b2d56ad3782bc7809254', 'scene/network/lan_session.gd': '2d9cf22ed8d0482bbbae70fbefbefa2151a77aeb66c6598e8e29ffdbb0331e8c', 'ui/mobile_action_button.gd': 'e42037a4cf1ae87ea8f7655d8a4f784fe9136d4e8ee32f89ae8bbeaeb3d20f32', 'scene/run_manager.gd': 'e27b4b12ef20221d055292778d26c50ef084af5b584e4f04da327e5df84f16de', 'scene/room_manager.gd': '99ed152a231c8caa47209805fe1f8b60a2e0a3f4ccfddde48914b19855a753d1'}

class MenuPanels(unittest.TestCase):
    def test_existing_input_callbacks_and_backend(self):
        for key, digest in FROZEN.items():
            path, name = key.split('::')
            functions = {m[1]:m[0].rstrip() for m in re.finditer(r'^func (\w+)\(.*?(?=^func |\Z)', (ROOT/path).read_text(), re.M|re.S)}
            self.assertEqual(hashlib.sha256(functions[name].encode()).hexdigest(), digest, key)
        for path, digest in FILES.items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), digest, path)

    def test_official_assets(self):
        base = ROOT/'assets/ui/menu_panels'
        selected = json.loads((base/'used_assets.json').read_text())
        official = {a['asset_id']:a for a in json.loads((base/'official_manifest.json').read_text())['assets']}
        self.assertEqual(len(selected), 18)
        for a in selected:
            self.assertTrue(a['runtime_ready'])
            self.assertFalse(a['reference_only'] or a['blocked'])
            self.assertEqual({k:v for k,v in a.items() if k!='sha256'}, official[a['asset_id']])
            path = base/a['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), a['sha256'])
            with Image.open(path) as image:
                image.load()
                self.assertEqual(image.mode, 'RGBA')
                self.assertEqual(image.size, (a['width'],a['height']))

    def test_parse_and_presentation_boundary(self):
        for path in ['scene/pause_menu.gd','scene/inventory_ui.gd','ui/menu_panel_presentation.gd']:
            parser.parse((ROOT/path).read_text())
        GDScene.load(str(ROOT/'scene/pause_menu.tscn'))
        skin = (ROOT/'ui/menu_panel_presentation.gd').read_text()
        for forbidden in ['func _process', 'func _input', 'Input.', '.value =', 'LocalSettings', 'WeaponCatalog', 'multiplayer', 'show_popup']:
            self.assertNotIn(forbidden, skin)
        self.assertIn('Control.MOUSE_FILTER_IGNORE', skin)
        self.assertIn('Node2D.new()', skin) # Decoration excluded from VBox layout.
        scene = (ROOT/'scene/pause_menu.tscn').read_text()
        self.assertIn('follow_focus = true', scene)
        self.assertEqual(scene.count('Volume" type="HSlider"'),4)
        inventory = (ROOT/'scene/inventory_ui.gd').read_text()
        self.assertIn('for index in 2:', inventory)
        self.assertIn('WeaponCatalog.get_definition(weapon_id)', inventory)
        for fiction in ['Rasga-Tendão','Granada de Gelo','Coleira do Prisioneiro','Arco do Iniciante']:
            self.assertNotIn(fiction, inventory + skin)

if __name__ == '__main__':
    unittest.main()
