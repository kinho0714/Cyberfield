extends CanvasLayer
## Presentation bridge: observes UI visibility only; never reads gameplay/session state.

@onready var mode_ui: CanvasLayer = get_parent().get_node("ModeSelect") as CanvasLayer
@onready var lan_ui: CanvasLayer = get_parent().get_node("LanLobby") as CanvasLayer
@onready var pause_ui: CanvasLayer = get_parent().get_node("PauseMenu") as CanvasLayer
@onready var pause_overlay: ColorRect = pause_ui.get_node("Overlay") as ColorRect
var gameplay_pause_color: Color


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gameplay_pause_color = pause_overlay.color
	_sync_presentation()


func _process(_delta: float) -> void:
	# One sample after UI callbacks: switching pages within a frame never restarts effects.
	_sync_presentation()


func _sync_presentation() -> void:
	var title_options: bool = bool(pause_ui.get("title_settings")) and pause_overlay.visible
	var menu_active: bool = mode_ui.visible or lan_ui.visible or title_options
	if visible != menu_active:
		visible = menu_active
	# Preserve the original gameplay pause surface; only title Options is transparent.
	var target_color: Color = Color(0.0, 0.0, 0.0, 0.0) if title_options else gameplay_pause_color
	if pause_overlay.color != target_color:
		pause_overlay.color = target_color
