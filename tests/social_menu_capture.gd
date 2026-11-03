extends SceneTree
## Evidência visual (03/11) do fluxo REAL de main.tscn: menu reorganizado, campanhas,
## social e cooperativo privado. Dados em namespace descartável; nada toca saves reais.
## Precisa de display (ex.: xvfb-run):
##   godot --path . --script res://tests/social_menu_capture.gd -- <out_dir> [largura altura]
var game: Node
var out_dir := "user://social_menu_captures"


func _initialize() -> void:
	call_deferred("_run")


func _capture(label: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	print("SOCIAL_MENU_CAPTURE ", label)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(int(args[1]), int(args[2])) if args.size() > 2 else Vector2i(1600, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ns := "user://capture_" + Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(ns)
	game = load("res://scene/main.tscn").instantiate()
	game.get_node("LocalSettings").settings_path = ns.path_join("settings.cfg")
	game.get_node("MetaProgression").save_path = ns.path_join("legacy.json")
	root.add_child(game)
	await process_frame
	var campaigns: Node = game.campaigns
	campaigns.store.root_path = ns.path_join("campaigns")
	campaigns.profile.initialize(ns.path_join("profile"))
	campaigns.private_panel.settings_path = ns.path_join("coop.cfg")
	var mode: Node = game.mode_select
	await _capture("01_menu_principal")
	mode.play_button.pressed.emit()
	await _capture("02_jogar")
	mode.solo_button.pressed.emit()
	await _capture("03_campanha_solo_vazia")
	mode.create_button.pressed.emit()
	await _capture("04_nova_campanha")
	campaigns.panel.name_field.text = "Noite em Low City"
	campaigns.panel._create()
	await _wait_game()
	game.get_players()[0].health = 71
	game.get_node("MetaProgression").credits = 340
	campaigns.save_now()
	await game.return_to_main_menu()
	await campaigns.start_new("Rota do Porto")
	await game.return_to_main_menu()
	mode.play_button.pressed.emit()
	mode.solo_button.pressed.emit()
	await _capture("05_campanha_solo_continuar")
	mode.get_node("Overlay/Center/SoloPage/Manage").pressed.emit()
	await _capture("06_gerenciar_campanhas")
	campaigns.panel._delete(campaigns.panel.selected_id)
	await _capture("07_confirmar_exclusao")
	campaigns.panel._cancel_delete()
	campaigns.panel.close()
	mode.show_main_page()
	var profile: Node = campaigns.profile
	profile.rename("Kinho")
	profile.add_local_contact("a1b2c3d4e5f60718", "Dani")
	profile.receive_request({"public_id": "0f1e2d3c4b5a6978", "name": "Rafa", "avatar": "spark"})
	profile.request_contact("1234567890abcdef", "Lu")
	profile.block("fedcba0987654321")
	mode.social_button.pressed.emit()
	await _capture("08_social")
	mode.get_node("Overlay/Center/SocialPage/Profile").pressed.emit()
	await _capture("09_meu_perfil")
	campaigns.social_panel.select_tab("friends")
	await _capture("10_amigos")
	campaigns.social_panel.select_tab("requests")
	await _capture("11_solicitacoes")
	campaigns.social_panel.select_tab("blocked")
	await _capture("12_bloqueados")
	campaigns.social_panel.close()
	mode.show_main_page()
	mode.play_button.pressed.emit()
	mode.coop_button.pressed.emit()
	await _capture("13_cooperativo")
	mode.get_node("Overlay/Center/CoopPage/PrivateCreate").pressed.emit()
	await _capture("14_criar_sessao")
	campaigns.private_panel.select_tab("join")
	campaigns.private_panel.code_field.text = "CF1-invalido"
	campaigns.private_panel._join_code()
	await _capture("15_entrar_codigo_invalido")
	campaigns.private_panel.select_tab("room")
	await _capture("16_sala_offline")
	campaigns.private_panel.close()
	await campaigns.continue_latest()
	await _wait_game()
	campaigns.services.open()
	await _capture("17_hub_mundo_sessao")
	campaigns.services.close()
	game.queue_free()
	await process_frame
	print("SOCIAL_MENU_CAPTURE_OK")
	quit()


func _wait_game() -> void:
	for i in 600:
		await process_frame
		if game.mode_selected and not game.is_transitioning:
			return
