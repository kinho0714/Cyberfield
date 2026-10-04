"""HUD presentation boundaries. Requires Pillow, gdtoolkit, godot-parser."""
from pathlib import Path
import hashlib
import json
import tempfile
import unittest
from PIL import Image
from godot_parser import GDScene
from gdtoolkit.parser import parser
parser._cache_dirpath = str(Path(tempfile.gettempdir()) / 'hud3-test-cache')
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/ui/gameplay_hud'
EXPECTED = {'scene/run_debug_hud.gd': '74bee5e1d74f14bf81a5c6327ba00c443dcd6aff9323b0cc7e9f571c3ad673c6', 'scene/biomes/biome_minimap.gd': 'c254db37bc7c84eea7a85fbe225130710a87686a908a1591cafa0f78b1e5c57d', 'ui/virtual_joystick.gd': '3688a1ca5ce4005ea8cc9e92bcc9639de8c1fff79a70afb9b4bc47a9c1d07752', 'ui/touch_controls.gd': '1bef10b7fa5c5bc744419e436ce4633d101a31b170e42c0730f395f99adbfcb7'}
TOUCH_SCENE = '644b34b9bdbfe091f8e1cd73abb97446559a45c0f351f0af6dc1b8775eceb8b7'


class HudPresentation(unittest.TestCase):
    def test_official_assets(self):
        used = json.loads((ASSETS / 'used_assets.json').read_text())
        official = {a['asset_id']: a for a in json.loads((ASSETS / 'official_manifest.json').read_text())['assets']}
        self.assertEqual(len(used), 23)
        for id, entry in used.items():
            asset = official[id]
            self.assertTrue(asset['runtime_ready'])
            self.assertFalse(asset['reference_only'] or asset['blocked'])
            data = ASSETS / entry['file']
            self.assertEqual(hashlib.sha256(data.read_bytes()).hexdigest(), entry['sha256'])
            with Image.open(data) as image:
                image.load()
                self.assertEqual(image.mode, 'RGBA')
                self.assertEqual(image.size, (asset['width'], asset['height']))

    def test_input_timer_map_and_network_contracts(self):
        for path, expected in EXPECTED.items():
            tree = parser.parse((ROOT / path).read_text())
            functions = []
            for function in tree.find_data('func_def'):
                name = str(function.children[0].children[0])
                if name in ['_ready', '_draw', '_update_local_player_hud']:
                    continue
                # Only new presentation call is removed; original data/input AST stays.
                function.children = [s for s in function.children if 'official_hud' not in str(s)]
                functions.append(str(function))
            signature = hashlib.sha256('\n'.join(functions).encode()).hexdigest()
            self.assertEqual(signature, expected, path)

    def test_touch_scene_functional_nodes(self):
        scene = GDScene.load(str(ROOT / 'ui/touch_controls.tscn'))
        rows = []
        for node in scene.get_nodes():
            if node.header.attributes['name'] in ['Visual', 'Label', 'Icon']:
                continue
            rows.append((dict(node.header.attributes), {k:str(v) for k,v in node.properties.items()}))
        self.assertEqual(hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest(), TOUCH_SCENE)
        for resource in scene.get_ext_resources():
            self.assertTrue((ROOT / resource.header.attributes['path'].removeprefix('res://')).exists())

    def test_low_hp_and_real_data(self):
        text = (ROOT / 'ui/gameplay_hud_presentation.gd').read_text()
        parser.parse(text)
        self.assertIn('LOW_HP_RATIO := 0.25', text)
        self.assertIn('_ratio <= LOW_HP_RATIO', text)
        self.assertIn('layer.layer = 39', text)
        self.assertIn('_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE', text)
        self.assertIn('_vignette.visible = hud_visible and _critical', text)
        self.assertIn('_vignette.modulate.a = 0.30', text)
        for key in ['health', 'max_health', 'heal_doses', 'max_heal_doses', 'health_attribute', 'intellect', 'strength']:
            self.assertIn('player.' + key, text)
        for forbidden in ['Input.', 'func _process', 'func _physics_process', 'equipped_weapons']:
            self.assertNotIn(forbidden, text)
        # The selector of local participant remains protected by AST test above.
        self.assertIn('official_hud.update_state(local_player, run_manager.dirty_money',
                      (ROOT / 'scene/run_debug_hud.gd').read_text())


if __name__ == '__main__':
    unittest.main()
