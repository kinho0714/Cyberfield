"""Presentation regression; requires gdtoolkit and Pillow, not Godot runtime."""
import hashlib
import json
import re
import unittest
from pathlib import Path
from PIL import Image
from gdtoolkit.parser import parser
import tempfile
parser._cache_dirpath = str(Path(tempfile.gettempdir()) / 'cidade-test-parser')
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

    def test_generator_gameplay_ast_unchanged(self):
        # Remove ONLY the four newly added presentation blocks. All original
        # function syntax trees must remain identical, including physics/AI/RNG.
        tree = parser.parse((ROOT / 'scene/biomes/biome_generator.gd').read_text())
        count = 0
        for function in tree.find_data('func_def'):
            keep = []
            for statement in function.children:
                if getattr(statement, 'data', '') == 'if_stmt' and 'CITY_PRESENTATION' in str(statement):
                    count += 1
                else:
                    keep.append(statement)
            function.children = keep
        self.assertEqual(count, 4)
        signature = '\n'.join(str(f) for f in tree.find_data('func_def'))
        self.assertEqual(hashlib.sha256(signature.encode()).hexdigest(), '1182e9cd8818fb62ea58d70b2277cc2ad434a05abe4f82bd80234525a5ee63cb')

    def test_static_native_presentation(self):
        text = (ROOT / 'scene/biomes/lower_city/lower_city_presentation.gd').read_text()
        parser.parse(text)
        for forbidden in ['func _process', 'func _physics_process', 'RandomNumberGenerator', 'CollisionShape', 'Area2D', 'Input.']:
            self.assertNotIn(forbidden, text)
        self.assertIn('TEXTURE_FILTER_NEAREST', text)
        self.assertIn('minf(region.size.x, surface.end.x - x)', text)
        self.assertIn('minf(region.size.y, surface.end.y - y)', text)
        self.assertIn('z_index = -8 if kind == "module" else -2', text)
        # Finite backgrounds retain their exact source dimensions/non-repeatability.
        data = json.loads((ASSETS / 'backgrounds/manifest.json').read_text())
        for entry in data['files']:
            self.assertEqual(entry['repeatability'], 'NON_REPEATABLE')
            self.assertEqual(entry['extraction_status'], 'COMPLETED')
            self.assertEqual(entry['resampling'], 'NONE')


if __name__ == '__main__':
    unittest.main()
