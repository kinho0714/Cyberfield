extends SceneTree

func _initialize() -> void:
	var translation: Translation = load("res://assets/localization/ui.pt_BR.tres")
	print("PROPERTIES ", translation.get_property_list())
	print("LOCALE ", translation.locale, " COUNT ", translation.get_message_count(), " COMMON ", translation.get_message("COMMON"))
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("pt_BR")
	print("TRANSLATED ", TranslationServer.translate("COMMON"))
	quit()
