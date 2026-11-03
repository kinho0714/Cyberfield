extends RefCounted
## Kit visual compartilhado pelas telas de campanha, social e cooperativo (03/11).
## Só apresentação: cada tela continua dona da lógica, do input e dos dados.
## Reaproveita as texturas oficiais de `assets/ui/menu_panels` e o tema do projeto.
const PRESENTATION := preload("res://ui/menu_panel_presentation.gd")
const TEXT_SAFETY := preload("res://scene/social/text_safety.gd")

const CYAN := Color("39dff2")
const MAGENTA := Color("ff4fc8")
const RED := Color("ff5d73")
const AMBER := Color("ffc857")
const GREEN := Color("6cf2b0")
const WHITE := Color("f2f7ff")
const TEXT := Color("c9d8e4")
const DIM := Color("7f97a8")
const BACKDROP := Color(0.012, 0.02, 0.04, 0.965)

const TITLE_SIZE := 30
const HEADING_SIZE := 22
const BODY_SIZE := 19
const META_SIZE := 16
const BUTTON_SIZE := 19
## Alvo de toque: 52 px na base 1280×720 (≈ 9 mm num 20:9 de 6,5").
const TOUCH_HEIGHT := 52.0

const CHARACTERS := {
	"jhon": {"name": "JHON", "file": "res://assets/players/jhon/design_b/jhon_idle.png", "frames": 8},
	"jackson": {"name": "JACKSON", "file": "res://assets/players/jackson/jackson_idle_v1.png", "frames": 4},
	"kai": {"name": "KAI", "file": "res://assets/players/kai/kai_idle_v1.png", "frames": 4},
	"spark": {"name": "SPARK", "file": "res://assets/players/spark/spark_idle_v1.png", "frames": 4},
}
const AVATAR_ORDER := ["jhon", "jackson", "kai", "spark"]


static func label(text: String, size: int = BODY_SIZE, color: Color = TEXT, wrap := true) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	if wrap:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


static func heading(text: String, color: Color = CYAN) -> Label:
	return label(text, HEADING_SIZE, color, true)


## Botão com as linhas oficiais do menu de pausa. `kind`: normal, primary, danger, quiet.
static func button(text: String, action: Callable, kind := "normal", min_width := 0.0) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(min_width, TOUCH_HEIGHT)
	item.clip_text = false
	PRESENTATION.style_button(item)
	item.add_theme_font_size_override("font_size", BUTTON_SIZE)
	item.add_theme_stylebox_override("disabled", PRESENTATION.style("pause/pause_row_normal", 10, 12))
	match kind:
		"primary":
			item.add_theme_color_override("font_color", CYAN)
		"danger":
			item.add_theme_color_override("font_color", RED)
			item.add_theme_color_override("font_hover_color", Color("ff9aa8"))
			item.add_theme_color_override("font_focus_color", Color("ff9aa8"))
		"quiet":
			item.add_theme_color_override("font_color", DIM)
	item.add_theme_color_override("font_disabled_color", Color(DIM, 0.55))
	if action.is_valid():
		item.pressed.connect(action)
	return item


## Aba com as texturas oficiais das Configurações.
static func tab(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.toggle_mode = false
	item.custom_minimum_size = Vector2(0, 46)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ContentRegistry.apply_ui_theme(item)
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	set_tab_selected(item, false)
	item.pressed.connect(action)
	return item


static func set_tab_selected(item: Button, selected: bool) -> void:
	var normal := PRESENTATION.style("settings/settings_tab_selected" if selected else "settings/settings_tab_normal", 8, 8)
	var hover := PRESENTATION.style("settings/settings_tab_selected", 8, 8)
	item.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "hover_pressed"]:
		item.add_theme_stylebox_override(state, hover)
	item.add_theme_color_override("font_color", WHITE if selected else DIM)
	item.add_theme_color_override("font_hover_color", CYAN)
	item.add_theme_color_override("font_focus_color", CYAN)
	item.set_meta("cyber_tab_selected", selected)


## Cartão (slot oficial do inventário, 9-slice). Retorna o VBox interno.
static func card(parent: Node, highlighted := false) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", PRESENTATION.style("inventory/slot_selected" if highlighted else "inventory/slot_normal", 10, 16))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(box)
	return box


## Painel de detalhe (borda magenta oficial) para colunas laterais.
static func detail_panel(parent: Node) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PRESENTATION.style("inventory/detail_panel", 14, 18))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(box)
	return box


static func row(parent: Node, separation := 8) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", separation)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


## Fluxo de botões que quebra linha em telas estreitas.
static func actions(parent: Node) -> HFlowContainer:
	var item := HFlowContainer.new()
	item.add_theme_constant_override("h_separation", 8)
	item.add_theme_constant_override("v_separation", 8)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


## Etiqueta de estado (OFFLINE, LOCAL, ATIVA…), com borda na cor do estado.
static func badge(text: String, color: Color) -> PanelContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.12)
	style.border_color = Color(color, 0.85)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text_label := label(text, META_SIZE, color, false)
	text_label.name = "Text"
	frame.add_child(text_label)
	return frame


static func set_badge(frame: PanelContainer, text: String, color: Color) -> void:
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = Color(color, 0.12)
		style.border_color = Color(color, 0.85)
	var text_label := frame.get_node("Text") as Label
	text_label.text = text
	text_label.add_theme_color_override("font_color", color)


static func field(placeholder: String, value := "", secret := false, max_length := 40) -> LineEdit:
	var item := LineEdit.new()
	item.placeholder_text = placeholder
	item.text = value
	item.secret = secret
	item.max_length = max_length
	item.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.virtual_keyboard_enabled = true
	item.context_menu_enabled = not secret
	ContentRegistry.apply_ui_theme(item)
	item.add_theme_font_size_override("font_size", BODY_SIZE)
	var surface := PRESENTATION.style("settings/option_row_normal", 8, 14)
	var focused := PRESENTATION.style("settings/option_row_focused", 8, 14)
	item.add_theme_stylebox_override("normal", surface)
	item.add_theme_stylebox_override("focus", focused)
	item.add_theme_stylebox_override("read_only", surface)
	item.add_theme_color_override("font_color", WHITE)
	item.add_theme_color_override("font_placeholder_color", Color(DIM, 0.8))
	item.add_theme_color_override("caret_color", CYAN)
	return item


static func divider(parent: Node, color: Color = CYAN) -> void:
	var line := ColorRect.new()
	line.color = Color(color, 0.28)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


static func spacer(parent: Node, height := 6.0) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)


static func expand(parent: Node) -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)
	return gap


## Retrato a partir do 1º quadro do idle oficial do personagem (sem arte nova).
static func avatar_texture(character: String) -> Texture2D:
	var entry: Dictionary = CHARACTERS.get(character, CHARACTERS["jhon"])
	var sheet := load(String(entry.file)) as Texture2D
	if sheet == null:
		return null
	var frame_width := sheet.get_width() / int(entry.frames)
	var frame := Rect2i(0, 0, frame_width, sheet.get_height())
	var image := sheet.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var used := image.get_region(frame).get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			# Busto: largura útil inteira e a parte superior do corpo.
			var side := mini(used.size.x, used.size.y)
			frame = Rect2i(used.position.x, used.position.y, side, mini(side, used.size.y))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame)
	return atlas


static func avatar(character: String, side := 88.0) -> TextureRect:
	var frame := TextureRect.new()
	frame.texture = avatar_texture(character)
	frame.custom_minimum_size = Vector2(side, side)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


const LOCATION_KINDS := {"world": "MUNDO", "state": "ESTADO", "city": "CIDADE", "municipality": "MUNICÍPIO", "neighborhood": "BAIRRO", "room": "SALA"}
const NARRATIVE_STATUS := {"confirmed": "confirmado", "proposed": "provisório", "reserved": "reservado"}


static func location_kind(kind: String) -> String:
	return String(LOCATION_KINDS.get(kind, kind.to_upper()))


static func narrative_status(status: String) -> String:
	return String(NARRATIVE_STATUS.get(status, status))


## Data/hora local legível a partir do carimbo UTC gravado pelos saves.
static func local_time(utc: String) -> String:
	if utc.is_empty():
		return "—"
	var unix := Time.get_unix_time_from_datetime_string(utc)
	if unix <= 0:
		return "—"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var local := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%02d/%02d/%04d %02d:%02d" % [local.day, local.month, local.year, local.hour, local.minute]


## Remove controles, quebras e marcas bidi; limita o tamanho. Para nomes exibidos.
static func clean_name(value: String, limit := 24) -> String:
	return TEXT_SAFETY.clean_name(value, limit)
