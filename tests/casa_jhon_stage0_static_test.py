"""Stage 0 asset/scene contracts. Requires godot-parser and Pillow; no Godot claims."""
import hashlib
import json
import unittest
from pathlib import Path
from godot_parser import GDScene
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/environment/casa_jhon'


class CasaStage0(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scene = GDScene.load(str(ROOT / 'scene/casa_jhon_hub.tscn'))
        cls.nodes = {}
        for node in cls.scene.get_nodes():
            h = node.header.attributes
            parent = h.get('parent')
            path = h['name'] if parent == '.' else (parent + '/' + h['name'] if parent else '.')
            cls.nodes[path] = node
        cls.sub = {x.header.attributes['id']: x for x in cls.scene.get_sub_resources()}
        cls.ext = {x.header.attributes['id']: x.header.attributes for x in cls.scene.get_ext_resources()}
        cls.layout = json.loads((BASE / 'layouts/stage0_layout.json').read_text())
        cls.assets = {x['asset_id']: x for x in json.loads((BASE / 'manifests/casa_jhon_master_manifest_v1.json').read_text())['assets']}

    def test_resource_graph_and_hierarchy(self):
        for resource in self.ext.values():
            self.assertTrue((ROOT / resource['path'].removeprefix('res://')).is_file())
        for path, node in self.nodes.items():
            parent = node.header.attributes.get('parent')
            if parent is not None:
                self.assertIn(parent, self.nodes)
            for value in node.properties.values():
                if getattr(value, 'name', '') == 'SubResource':
                    self.assertIn(value.args[0], self.sub)
                if getattr(value, 'name', '') == 'ExtResource':
                    self.assertIn(value.args[0], self.ext)

    def test_all_official_instances_native_and_runtime_ready(self):
        sprites = [n for n in self.scene.get_nodes() if n.header.attributes.get('type') == 'Sprite2D']
        self.assertEqual(len(sprites), 95)
        self.assertEqual(len(sprites), len(self.layout['instances']))
        for node, placement in zip(sprites, self.layout['instances']):
            asset = self.assets[placement['asset_id']]
            self.assertTrue(asset['runtime_ready'])
            self.assertFalse(asset['reference_only'])
            self.assertFalse(asset.get('blocked', False))
            self.assertEqual(node['position'].args, [placement['position_x'], placement['position_y']])
            self.assertEqual(node['offset'].args, [-asset['recommended_origin_x'], -asset['recommended_origin_y']])
            self.assertNotIn('scale', node.properties)
            self.assertEqual(node['z_index'], placement['z_index'])
            self.assertEqual(node['flip_h'], placement['flip_h'])
            self.assertEqual(node['flip_v'], placement['flip_v'])
            atlas = self.sub[node['texture'].args[0]]
            self.assertEqual(atlas['region'].args, asset['region'])
            source = self.ext[atlas['atlas'].args[0]]['path']
            self.assertEqual(source, 'res://assets/environment/casa_jhon/' + asset['source_file'])
            with Image.open(ROOT / source.removeprefix('res://')) as image:
                image.load()
                self.assertEqual(image.mode, 'RGBA')
                x, y, w, h = asset['region']
                self.assertLessEqual(x + w, image.width)
                self.assertLessEqual(y + h, image.height)
        self.assertLess(self.nodes['Environment']['z_index'] + max(n['z_index'] for n in sprites), 0)

    def test_legacy_gameplay_contracts(self):
        for name in ['P1Spawn', 'P2Spawn']:
            self.assertEqual(self.nodes['Gameplay/' + name].header.attributes['type'], 'Marker2D')
        for name, script in [('RunPortal', 'run_portal'), ('MetaTerminal', 'meta_terminal')]:
            node = self.nodes['Gameplay/' + name]
            self.assertEqual(node.header.attributes['type'], 'Area2D')
            self.assertIn('interactable', node.header.attributes['groups'])
            self.assertEqual(node['collision_layer'], 2)
            self.assertEqual(node['collision_mask'], 1)
            self.assertEqual(self.ext[node['script'].args[0]]['path'], 'res://scene/interactables/' + script + '.gd')
            self.assertIn('Gameplay/' + name + '/Prompt', self.nodes)
            self.assertIn('Gameplay/' + name + '/CollisionShape2D', self.nodes)
        room = (ROOT / 'scene/room_manager.gd').read_text()
        self.assertIn('preload("res://scene/casa_jhon_hub.tscn")', room)
        self.assertIn('current_is_hub = true', room)
        self.assertIn('current_is_generated_biome = false', room)
        self.assertIn('run_active = false', (ROOT / 'scene/run_manager.gd').read_text())

    def test_authored_collision_spawns_and_anchors(self):
        floor = self.nodes['Geometry/Floor']
        size = self.sub[floor['shape'].args[0]]['size'].args
        self.assertEqual(size, [2560, 125])
        floor_top = floor['position'].args[1] - size[1] / 2
        self.assertEqual(floor_top, 643)
        p1 = self.nodes['Gameplay/P1Spawn']['position'].args
        p2 = self.nodes['Gameplay/P2Spawn']['position'].args
        # Existing RoomManager adds 44px per extra participant after P2.
        spawns = [p1, p2, [p2[0] + 44, p2[1]], [p2[0] + 88, p2[1]]]
        for x, y in spawns:
            self.assertTrue(16 < x < 2544)
            self.assertLessEqual(y + 16, floor_top)
        self.assertEqual(len({tuple(p) for p in spawns}), 4)
        for name in ['Floor', 'LeftWall', 'RightWall', 'Ceiling']:
            self.assertIn('Geometry/' + name, self.nodes)
        for anchor in self.layout['anchors']:
            self.assertEqual(self.nodes['Anchors/' + anchor['id']]['position'].args, anchor['position'])
        self.assertEqual(self.layout['dimensions'], [2560, 768])
        self.assertEqual(self.nodes['.']['texture_filter'], 1)


if __name__ == '__main__':
    unittest.main()
