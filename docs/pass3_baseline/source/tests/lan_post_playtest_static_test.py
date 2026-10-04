"""Regression boundaries and network presentation contract; not runtime approval."""
import hashlib
import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read(name): return (ROOT / name).read_text()
def function(text, name):
    return re.search(r'^func '+name+r'\(.*?(?=^func |\Z)', text, re.M | re.S)[0].rstrip()
class Stabilization(unittest.TestCase):
    def test_camera_without_physical_tether(self):
        text=read('scene/room_manager.gd')
        for token in ['_apply_coop_distance_limits','_find_safe_tether_position','COOP_SOFT_LIMIT','COOP_HARD_LIMIT']:
            self.assertNotIn(token,text)
        camera=function(text,'_update_coop_camera')
        self.assertIn('_maximum_player_separation',camera)
        self.assertIn('clampf(desired_zoom, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)',camera)
        self.assertNotIn('player.velocity',camera)
        self.assertNotIn('player.global_position =',camera)
    def test_downed_authority_and_active_prediction(self):
        text=read('entities/player.gd')
        apply=function(text,'apply_network_state')
        self.assertLess(apply.index('snapshot_epoch < network_world_epoch'),apply.index('global_position = network_position'))
        self.assertIn('if incoming_downed or is_downed:',apply)
        self.assertIn('network_has_pending_snap = false',apply)
        self.assertIn('elif predicted_local:',apply)
        self.assertIn('prediction_error >= 192.0',apply)
        self.assertIn('prediction_error >= 18.0',apply)
        physics=function(text,'_physics_process')
        self.assertIn('network_remote_replica or (network_prediction_only and is_downed)',physics)
        self.assertIn('velocity = Vector2.ZERO',function(text,'revive'))
    def test_semantic_presentation(self):
        player=read('entities/player.gd'); visual=read('entities/player_character_visual.gd')
        for key in ['is_reviving','is_hurt']:
            self.assertIn('"'+key+'":',function(player,'get_network_state'))
            self.assertIn('state.get("'+key+'"',function(player,'apply_network_state'))
        self.assertIn('network_is_reviving',function(visual,'_resolve_state'))
        self.assertNotIn('player_2',function(visual,'_resolve_state'))
        for state in ['idle','walk','air','attack','dash','ground_slam','hurt','downed','revive','wall_slide','wall_climb']:
            self.assertIn('&"'+state+'"',visual)
        self.assertIn('network_visual_frame',function(visual,'_update_presentation'))
    def test_enemy_replica_presentation_and_hp(self):
        for file in ['entities/Enemy.gd','entities/RangedEnemy.gd']:
            text=read(file)
            self.assertIn('"presentation_state": get_visual_state()',text)
            self.assertIn('not is_physics_processing() and not network_presentation_state.is_empty()',text)
            self.assertIn('health < previous_health',text)
            self.assertIn('health_bar_visible_timer = 2.5',text)
        visual=read('entities/enemy_character_visual.gd')
        self.assertIn('bar.z_index = z_index + 1',visual)
        self.assertIn('texture.get_height()',visual)
        self.assertIn('top - 12.0',visual)
        self.assertIn('not is_boss()',read('entities/Enemy.gd'))
    def test_telegraph_and_projectile_authority(self):
        text=read('entities/RangedEnemy.gd')
        self.assertIn('"aim_points": aim_line.points',text)
        self.assertIn('aim_line.points = points',text)
        self.assertNotIn('_update_aim(',function(text,'apply_network_state'))
        session=read('scene/network/lan_session.gd')
        for name in ['_spawn_network_projectile','_impact_network_projectile','_despawn_network_projectile']:
            self.assertIn(name,session)
        projectile=read('entities/ranged_projectile.gd')
        self.assertRegex(projectile,r'if network_visual_only:\n\t\tglobal_position \+= direction \* speed \* delta\n\t\treturn')
        for path in ['entities/ranged_projectile.tscn','entities/heavy_projectile.tscn']:
            self.assertIn('z_index = 4',read(path))
    def test_options_only_visual_and_rain_frozen(self):
        menu=read('scene/main_menu_alive.gd')
        self.assertIn('0.82 if options_legibility else 0.10',menu)
        scene=read('scene/pause_menu.tscn')
        self.assertEqual(scene.count('options_legibility = true'),2)
        style=function(read('scene/pause_menu.gd'),'_style_audio_slider')
        self.assertIn('39dff2',style)
        for mutation in ['.value =','min_value','max_value','LocalSettings','Input.']:
            self.assertNotIn(mutation,style)
        self.assertIn('rain_base_amount: int = 560',read('scene/animated_menu_background.gd'))
        self.assertNotIn('var selected := focus.get_selected_items()',menu)
    def test_approved_input_audio_functions_byte_preserved(self):
        expected = {('scene/pause_menu.gd', '_input'): '69fb54e9988826eb626eae2315871b54fa1a2189763617b20bfb96a1162c8ec5', ('scene/pause_menu.gd', '_handle_options_gesture'): '811e6b602224aa1da3bebc981246dfd560fda5ff01c5ee6372d04fa4bda9daa8', ('scene/pause_menu.gd', '_cancel_options_gesture'): '123caa00ae68d732d8b06c78f6863156a9186f68afd96646027a37d6753281a1', ('scene/pause_menu.gd', '_update_touch_slider'): '5ebdfc18d31771902663f5b77faa15e67d03f9a20ea513173596577836686355', ('scene/pause_menu.gd', '_set_audio_volume'): '7cbd31d6cb994db774a2b9d7efaa81879acaf6f24a09af0ebe92dd3be4621f6a', ('scene/pause_menu.gd', '_set_camera_zoom'): '04b74ba0cf6ab0cccd17b47263bbdf3da78fc9366a73de1a4c41ed9e0a7edb9a', ('scene/main_menu_alive.gd', '_move_focus'): '0e2a93bf0edeef7f0d6039169805f263773c06a6635cba63433efbbe90d125e1', ('scene/main_menu_alive.gd', '_popup_opening'): '72119dd5c4ed0dfc984b9769d5cccad049af99d43f9fd699ad6cfb03dfbcc1c4', ('scene/main_menu_alive.gd', '_popup_closed'): '00a9e2714cc3c087a3124570e8901f0a856f24d6af5b7c23ba6f42194f66fa00', ('scene/main_menu_alive.gd', '_finish_popup_input'): 'bc9ff43e283dbcdca4a984c23e1b5fedc0fbfd3cabdcf868f4fc948b97c22e14', ('scene/main_menu_alive.gd', '_style_dropdown'): 'ecc47191b84a6f24eba0f37406b8e13d6a52333c8097034272b6960d39069dd7'}
        for (path, name), digest in expected.items():
            self.assertEqual(hashlib.sha256(function(read(path), name).encode()).hexdigest(), digest, name)
if __name__=='__main__': unittest.main()
