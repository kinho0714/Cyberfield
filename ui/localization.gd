extends RefCounted
## Godot translations; source messages remain stable keys, never internal IDs.
const PT = preload("res://assets/localization/ui.pt_BR.tres")
const EN = preload("res://assets/localization/ui.en.tres")


static func initialize(locale: String) -> void:
	TranslationServer.add_translation(PT)
	TranslationServer.add_translation(EN)
	TranslationServer.set_locale(locale)
