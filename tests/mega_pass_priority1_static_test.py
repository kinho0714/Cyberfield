from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

generator = (ROOT / "scene/biomes/biome_generator.gd").read_text(encoding="utf-8")
director = (ROOT / "scene/biomes/room_director.gd").read_text(encoding="utf-8")
settings = (ROOT / "scene/local_settings.gd").read_text(encoding="utf-8")
buses = (ROOT / "default_bus_layout.tres").read_text(encoding="utf-8")
main = (ROOT / "scene/main.tscn").read_text(encoding="utf-8")
player = (ROOT / "entities/player.gd").read_text(encoding="utf-8")
enemy = (ROOT / "entities/Enemy.gd").read_text(encoding="utf-8")
ranged_enemy = (ROOT / "entities/RangedEnemy.gd").read_text(encoding="utf-8")
room_manager = (ROOT / "scene/room_manager.gd").read_text(encoding="utf-8")
audio_service = (ROOT / "scene/audio_service.gd").read_text(encoding="utf-8")
progression = (ROOT / "scene/gameplay_progression_foundation.gd").read_text(encoding="utf-8")
meta = (ROOT / "scene/meta_progression.gd").read_text(encoding="utf-8")

assert "_build_exploration_layout" in generator
assert "RoomDirector" in generator
assert "max_vertical_chain" in generator
assert "vertical_edge_ratio" in generator
assert "direction_history" in director
assert "intent_history" in director
assert "module_history" in director
assert 'id="19_audio"' in main
assert 'name="AudioService"' in main
for name in ["Master", "Music", "SFX", "Dialogue"]:
    assert f'&"{name}"' in settings
    assert f'name = &"{name}"' in buses
assert "AudioServer.set_bus_mute" in settings
assert "linear_to_db" in settings
for event in ["player_jump", "player_dash", "player_attack", "player_hurt", "player_downed", "player_revive"]:
    assert event in player
for event in ["enemy_telegraph", "enemy_attack", "enemy_hurt", "enemy_death"]:
    assert event in enemy or event in ranged_enemy
assert '_set_music_context(&"main_menu", 0.35)' in room_manager
assert "node_added.connect" in audio_service
assert "MAX_NORMAL_WEAPON_BUFFS := 2" in progression
assert 'FUTURE_SPECIAL_QUALITY: StringName = &"adaptive"' in progression
for slot in ["head_neural", "arms", "torso", "legs"]:
    assert f'&"{slot}"' in progression
assert "recovered_models" in meta
assert "blueprints" in meta
assert "study_blueprint" in meta
assert "house_stage" in meta
assert "hub_progression" in meta
print("MEGA_PASS_PRIORITY1_STATIC_TEST_OK")
