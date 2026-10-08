"""Presentation regression; requires gdtoolkit and Pillow, not Godot runtime."""
import hashlib
import json
import re
import unittest
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/environment/cidade_baixa'


class CidadePresentation(unittest.TestCase):
    def test_official_files_and_paths(self):
        for manifest in ASSETS.glob('*/manifest.json'):
            data = json.loads(manifest.read_text())
            files = data['files']
            entries = files.items() if isinstance(files, dict) else [(x['filename'], x) for x in files]
            for name, meta in entries:
                path = manifest.parent / name
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), meta['sha256'])
                with Image.open(path) as image:
                    image.load()
                    self.assertEqual(image.mode, 'RGBA')
        script = (ROOT / 'scene/biomes/lower_city/lower_city_presentation.gd').read_text()
        for path in re.findall(r'preload\("res://([^"]+)"\)', script):
            self.assertTrue((ROOT / path).is_file())
        self.assertNotIn('reference', script.lower())

    def test_run_visuals_detached_without_removing_base_geometry(self):
        generator_text = (ROOT / 'scene/biomes/biome_generator.gd').read_text()
        self.assertNotIn('CITY_PRESENTATION', generator_text)
        self.assertIn('module.add_child(background)', generator_text)
        self.assertIn('body.add_child(visual)', generator_text)
        self.assertIn('shape_node.one_way_collision = one_way', generator_text)
        self.assertIn('EXIT_SCENE.instantiate()', generator_text)
        room_manager_text = (ROOT / 'scene/room_manager.gd').read_text()
        self.assertIn('if current_is_hub and is_instance_valid(current_room)', room_manager_text)
        self.assertIn('backdrop.profile_id = "house"', room_manager_text)

    def test_static_native_presentation(self):
        text = (ROOT / 'scene/biomes/lower_city/lower_city_presentation.gd').read_text()
        for forbidden in ['func _process', 'func _physics_process', 'RandomNumberGenerator', 'CollisionShape2D.new(', 'Area2D.new(', 'Input.']:
            self.assertNotIn(forbidden, text)
        # The source renderer remains archived but no active generator loads it.
        self.assertIn('TEMP_ENV.paint(self, id, room_role, protected)', text)
        self.assertNotIn('lower_city_presentation.gd', (ROOT / 'scene/biomes/biome_generator.gd').read_text())
        # Original background assets remain available for a separately authorized future pass.
        data = json.loads((ASSETS / 'backgrounds/manifest.json').read_text())
        for entry in data['files']:
            self.assertEqual(entry['repeatability'], 'NON_REPEATABLE')
            self.assertEqual(entry['extraction_status'], 'COMPLETED')
            self.assertEqual(entry['resampling'], 'NONE')


if __name__ == '__main__':
    unittest.main()
