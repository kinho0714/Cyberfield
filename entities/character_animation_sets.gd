extends RefCounted
## GERADO por tools/visual/character_sheet_import.py — não editar à mão.
## Conjuntos de animação por personagem: células com os pés na última linha, exibidas
## na escala indicada; hands = âncora da mão por quadro (relativa ao centro da célula,
## olhando para a direita) para armas desenhadas separadamente do corpo.

const SETS := {
	&"jhon": {
		"dir": "res://assets/players/jhon/design_b/",
		"scale": 1.0,
		"cell": Vector2(160, 100),
		"anims": {
			&"idle": {"file": "jhon_idle.png", "frames": 8, "fps": 8.0, "loop": true, "hands": []},
			&"walk": {"file": "jhon_walk.png", "frames": 8, "fps": 10.0, "loop": true, "hands": []},
			&"run": {"file": "jhon_run.png", "frames": 8, "fps": 13.0, "loop": true, "hands": []},
			&"jump": {"file": "jhon_jump.png", "frames": 8, "fps": 14.0, "loop": false, "hands": []},
			&"fall": {"file": "jhon_fall.png", "frames": 8, "fps": 12.0, "loop": false, "hands": []},
			&"land": {"file": "jhon_land.png", "frames": 8, "fps": 28.0, "loop": false, "hands": []},
			&"dash": {"file": "jhon_dash.png", "frames": 8, "fps": 40.0, "loop": false, "hands": []},
			&"hurt": {"file": "jhon_hurt.png", "frames": 8, "fps": 24.0, "loop": false, "hands": []},
			&"downed": {"file": "jhon_downed.png", "frames": 8, "fps": 10.0, "loop": false, "hands": []},
			&"get_up": {"file": "jhon_get_up.png", "frames": 8, "fps": 14.0, "loop": false, "hands": []},
			&"aim_pistol": {"file": "jhon_aim_pistol.png", "frames": 8, "fps": 8.0, "loop": true, "hands": [Vector2(38.0, -16.0), Vector2(33.0, -6.0), Vector2(25.0, 5.0), Vector2(29.0, -1.0), Vector2(32.0, -5.0), Vector2(28.0, 2.0), Vector2(33.0, -9.0), Vector2(33.0, -13.0)]},
			&"aim_rifle": {"file": "jhon_aim_rifle.png", "frames": 8, "fps": 8.0, "loop": true, "hands": [Vector2(37.0, -17.0), Vector2(36.0, -11.0), Vector2(31.0, -4.0), Vector2(30.0, -8.0), Vector2(33.0, -13.0), Vector2(29.0, -10.0), Vector2(31.0, -15.0), Vector2(32.0, -14.0)]},
			&"aim_bow": {"file": "jhon_aim_bow.png", "frames": 8, "fps": 8.0, "loop": true, "hands": [Vector2(29.0, -14.0), Vector2(25.0, -6.0), Vector2(23.0, -8.0), Vector2(22.0, -5.0), Vector2(23.0, -3.0), Vector2(20.0, -3.0), Vector2(28.0, -9.0), Vector2(27.0, -10.0)]},
			&"shoot_pistol": {"file": "jhon_shoot_pistol.png", "frames": 8, "fps": 30.0, "loop": false, "hands": [Vector2(29.0, -19.0), Vector2(28.0, -15.0), Vector2(26.0, -11.0), Vector2(25.0, -22.0), Vector2(26.0, -13.0), Vector2(27.0, -14.0), Vector2(26.0, -16.0), Vector2(27.0, -16.0)]},
			&"shoot_rifle": {"file": "jhon_shoot_rifle.png", "frames": 8, "fps": 30.0, "loop": false, "hands": [Vector2(36.0, -13.0), Vector2(35.0, -10.0), Vector2(33.0, -10.0), Vector2(31.0, -16.0), Vector2(26.0, -16.0), Vector2(27.0, -10.0), Vector2(27.0, -10.0), Vector2(28.0, -10.0)]},
			&"shoot_bow": {"file": "jhon_shoot_bow.png", "frames": 8, "fps": 24.0, "loop": false, "hands": [Vector2(30.0, 8.0), Vector2(27.0, 4.0), Vector2(26.0, -4.0), Vector2(30.0, -9.0), Vector2(31.0, -14.0), Vector2(36.0, -16.0), Vector2(39.0, -14.0), Vector2(42.0, -14.0)]},
			&"reload_pistol": {"file": "jhon_reload_pistol.png", "frames": 8, "fps": 8.0, "loop": false, "hands": [Vector2(26.0, 4.0), Vector2(29.0, -6.0), Vector2(20.0, -9.0), Vector2(23.0, -11.0), Vector2(30.0, -12.0), Vector2(29.0, -15.0), Vector2(33.0, -14.0), Vector2(34.0, -14.0)]},
			&"melee_ready_impact": {"file": "jhon_melee_ready_impact.png", "frames": 8, "fps": 12.0, "loop": false, "hands": []},
			&"melee_punch_01": {"file": "jhon_melee_punch_01.png", "frames": 8, "fps": 30.0, "loop": false, "hands": []},
		},
		"rejected": [&"reload_rifle"],
	},
}
