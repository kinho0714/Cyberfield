"""Offline asset/scene contracts. Requires Pillow; NOT a Godot runtime test."""
from pathlib import Path
import hashlib
import re
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets/ui/menu/animated/v3'


def node_blocks(text):
    result = {}
    for match in re.finditer(r'\[node name="([^"]+)"([^\n]*)\]\n(.*?)(?=\[node |\Z)', text, re.S):
        parent = re.search(r'parent="([^"]+)"', match[2])
        path = ((parent[1] + '/') if parent and parent[1] != '.' else '') + match[1]
        result[path] = match[3]
    return result


class AnimatedMenuBackgroundContract(unittest.TestCase):
    def test_package_hashes(self):
        entries = (PACK / 'SHA256SUMS.txt').read_text().splitlines()
        self.assertEqual(len([s for s in entries if s.strip()]), 24)
        for line in entries:
            if line.strip():
                expected, name = line.split()
                self.assertEqual(hashlib.sha256((PACK / name).read_bytes()).hexdigest(), expected, name)

    def test_texture_canvases_alpha(self):
        drops = {'rain_back_drop_v3.png': (6, 22), 'rain_front_drop_v3.png': (9, 34)}
        for path in PACK.rglob('*.png'):
            with Image.open(path) as image:
                image.load()
                self.assertEqual(image.format, 'PNG')
                self.assertEqual(image.size, ((1280, 720) if path.name == 'concept_master_v3_1280x720.png' else drops.get(path.name, (1664, 936))))
                if path.name.startswith('concept_master_'):
                    self.assertEqual(image.mode, 'RGB')
                else:
                    self.assertEqual(image.mode, 'RGBA')
                    low, high = image.getchannel('A').getextrema()
                    self.assertLess(low, high)
                    self.assertGreater(high, 0)

    def test_resource_graph(self):
        for filename in ('scene/animated_menu_background.tscn', 'scene/animated_menu_background.gd', 'scene/main.tscn'):
            text = (ROOT / filename).read_text()
            for path in re.findall(r'res://([^"\s]+)', text):
                self.assertTrue((ROOT / path).is_file(), path)
        scene = (ROOT / 'scene/animated_menu_background.tscn').read_text()
        ids = set(re.findall(r'\[ext_resource [^\n]*id="([^"]+)"', scene))
        self.assertTrue(set(re.findall(r'ExtResource\("([^"]+)"\)', scene)) <= ids)
        self.assertIn('menu_clouds.gdshader', scene)
        self.assertNotIn('/v2/', scene)
        self.assertNotIn('/v1/', scene)
        self.assertNotIn('.jpg', scene)
        self.assertNotIn('animated_menu_background.gdshader', scene)

    def test_overlay_alignment(self):
        nodes = node_blocks((ROOT / 'scene/animated_menu_background.tscn').read_text())
        for name in ('BackgroundBase', 'Cyan', 'CityGlow', 'Atmosphere', 'LightningFlash', 'Large1', 'Large2', 'Large3', 'Short1', 'Short2', 'Short3'):
            block = nodes['Composition/' + name]
            self.assertIn('centered = false', block)
            self.assertNotIn('position =', block)
            self.assertNotIn('scale =', block)
        for prefix, regions in (('Magenta', [(0,832),(832,832)]), ('Windows', [(0,555),(555,555),(1110,554)])):
            for i, (x, width) in enumerate(regions):
                block = nodes['Composition/' + prefix + str(i)]
                self.assertIn(f'position = Vector2({x}, 0)', block)
                self.assertIn(f'region_rect = Rect2({x}, 0, {width}, 936)', block)
            self.assertEqual(sum(w for x,w in regions), 1664)

    def test_uniform_cover_and_lightning(self):
        text = (ROOT / 'scene/animated_menu_background.gd').read_text()
        self.assertIn('maxf(size.x / MASTER_SIZE.x, size.y / MASTER_SIZE.y)', text)
        for width, height in ((1280, 720), (1600, 720), (1280, 800)):
            scale = max(width / 1664, height / 936)
            x, y = (width - 1664 * scale) / 2, (height - 936 * scale) / 2
            self.assertLessEqual(x, 0)
            self.assertLessEqual(y, 0)
            self.assertGreaterEqual(x + 1664 * scale, width)
            self.assertGreaterEqual(y + 936 * scale, height)
            if (width, height) == (1280, 720):
                self.assertEqual((x, y, scale), (0, 0, 10 / 13))
        nodes = node_blocks((ROOT / 'scene/animated_menu_background.tscn').read_text())
        for name in ('Large1', 'Large2', 'Large3', 'Short1', 'Short2', 'Short3', 'LightningFlash'):
            self.assertIn('modulate = Color(1, 1, 1, 0)', nodes['Composition/' + name])
        self.assertIn('if index != selected_bolt:', text)
        self.assertIn('3 if rng.randf() < 0.65 else 0', text)
        self.assertIn('bolts[index].modulate.a = flash_strength if index == selected_bolt else 0.0', text)
        # Mathematical envelope has no residual after the finite event, including double flash.
        for double in (False, True):
            for age in (0.51, 1.0, 30.0):
                strength = max(0, 1 - age / .22)
                if double and age >= .34:
                    strength = max(0, 1 - (age - .34) / .14) * .45
                self.assertEqual(strength, 0)
        self.assertIn('initial_velocity_min = speed * 0.82', text)
        self.assertIn('initial_velocity_max = speed * 1.18', text)
        self.assertIn('lifetime_randomness = 0.08', text)

    def test_cloud_loop_depth_and_idle(self):
        scene = (ROOT / 'scene/animated_menu_background.tscn').read_text()
        nodes = node_blocks(scene)
        order = list(nodes)
        for name in ('Large1','Large2','Large3','Short1','Short2','Short3'):
            self.assertLess(order.index('Composition/' + name), order.index('Composition/BackA'))
        for name in ('BackMask','FrontMask'):
            self.assertIn('modulate = Color(1, 1, 1, 0)', nodes['Composition/' + name])
        for name in ('BackA','BackB','FrontA','FrontB'):
            self.assertIn('centered = false', nodes['Composition/' + name])
        shader = (ROOT / 'scene/menu_clouds.gdshader').read_text()
        self.assertIn('fract(UV.x - scroll)', shader)
        self.assertIn('fract(u + 0.5)', shader)
        def smooth(a,b,x):
            t = min(1,max(0,(x-a)/(b-a)))
            return t*t*(3-2*t)
        def weight(x):
            return smooth(0,.15,x)*(1-smooth(.85,1,x))
        for i in range(10001):
            u = i / 10000
            # Every phase retains a non-seam sample, including both wrap boundaries.
            self.assertGreaterEqual(weight(u)+weight((u+.5)%1), 1-1e-10)
        script = (ROOT / 'scene/animated_menu_background.gd').read_text()
        self.assertIn('cloud_back_speed: float = 7.0', script)
        self.assertIn('cloud_front_speed: float = 11.5', script)
        self.assertIn('rng.randf_range(0.02, 0.06)', script)
        for previous in range(6):
            for first in (0,3):
                candidates = [i for i in range(first,first+3) if i != previous]
                self.assertNotIn(previous,candidates)
                self.assertGreaterEqual(len(candidates),2)

    def test_one_shared_instance_and_ui_layers(self):
        main = (ROOT / 'scene/main.tscn').read_text()
        nodes = node_blocks(main)
        self.assertEqual(main.count('instance=ExtResource("animated_menu")'), 1)
        self.assertIn('MenuEnvironment/AnimatedMenuBackground', nodes)
        self.assertIn('layer = 89', nodes['MenuEnvironment'])
        self.assertIn('layer = 90', nodes['ModeSelect'])
        self.assertIn('color = Color(0, 0, 0, 0)', nodes['ModeSelect/Overlay'])
        self.assertNotIn('[node name="MenuPanel"', main)
        bridge = (ROOT / 'scene/menu_environment.gd').read_text()
        self.assertIn('mode_ui.visible or lan_ui.visible or title_options', bridge)
        self.assertIn('else gameplay_pause_color', bridge)
        for forbidden in ('RunManager', 'RoomManager', 'mode_selected', 'run_active', 'lan_session', 'instantiate('):
            self.assertNotIn(forbidden, bridge)
        # PASS 6 keeps the phone repair and delegates open dropdowns to their popup.
        menu = (ROOT / 'scene/main_menu_alive.gd').read_text()
        move = re.search(r'^func _move_focus\([^\n]*\n.*?(?=^func |\Z)', menu, re.M | re.S)[0]
        self.assertIn('focus is OptionButton and focus.get_popup().visible:', move)
        self.assertNotIn('focus.select(', move)
        self.assertNotIn('focus.item_selected.emit(', move)
        self.assertIn('child.disabled', move)
        self.assertIn('grab_focus()', move)
        self.assertNotIn('var selected := focus.get_selected_items()', menu)

    def test_modules_and_native_rain(self):
        text = (ROOT / 'scene/animated_menu_background.gd').read_text()
        for module in ('rain', 'lights', 'atmosphere', 'lightning', 'clouds'):
            self.assertIn(f'@export var {module}_enabled: bool', text)
            self.assertIn(f'if {module}_enabled:', text)
        self.assertIn('CPUParticles2D.new()', text)
        self.assertIn('emitter.texture = FRONT_DROP if front else BACK_DROP', text)
        self.assertIn('emitter.preprocess = emitter.lifetime', text)
        self.assertIn('emitter.queue_free()', text)
        for name in ('rain', 'lights', 'lightning'):
            self.assertIn(f'@export var debug_force_{name}: bool = false', text)
        self.assertIn('debug_force_lightning = false', text)
        for forbidden in ('GPUParticles2D', 'GradientTexture2D', 'RunManager', 'LanSession', 'await ', 'create_tween', 'get_parent()'):
            self.assertNotIn(forbidden, text)
        shader = (ROOT / 'scene/menu_rain.gdshader').read_text()
        self.assertIn('mix(1.0, 0.55, smoothstep', shader)


if __name__ == '__main__':
    unittest.main()
