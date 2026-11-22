extends Node
## Ajustes globales: calidad gráfica, FPS, idioma y controles.
## Se guardan en user://settings.cfg

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["low", "medium", "high", "ultra"]

var quality := 1          # 0 bajo · 1 medio · 2 alto · 3 ultra
var fps := 60
var lang := "es"
var render_scale := 1.0
var show_fps := false
var sensitivity := 1.0
var music := 0.7
var first_run := true

func _ready() -> void:
	_setup_input()
	_load()
	apply()

# ---------- calidad ----------
func grass_density() -> float: return [0.22, 0.45, 0.75, 1.1][quality]
func grass_range() -> float: return [42.0, 62.0, 90.0, 130.0][quality]
func tree_range() -> float: return [170.0, 260.0, 380.0, 560.0][quality]
func tree_density() -> float: return [0.55, 0.8, 1.0, 1.25][quality]
func shadows() -> bool: return quality >= 1
func shadow_distance() -> float: return [0.0, 70.0, 110.0, 160.0][quality]
func glow() -> bool: return quality >= 1
func far_clip() -> float: return [650.0, 900.0, 1300.0, 1800.0][quality]

func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func apply() -> void:
	Engine.max_fps = fps
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
		vp.msaa_3d = Viewport.MSAA_4X if quality == 3 else (Viewport.MSAA_2X if quality == 2 else Viewport.MSAA_DISABLED)
	changed.emit()

func set_quality(q: int) -> void:
	quality = clampi(q, 0, 3)
	save()
	apply()

# ---------- guardado ----------
func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		quality = c.get_value("video", "quality", quality)
		fps = c.get_value("video", "fps", fps)
		render_scale = c.get_value("video", "render_scale", render_scale)
		show_fps = c.get_value("video", "show_fps", show_fps)
		lang = c.get_value("general", "lang", lang)
		sensitivity = c.get_value("general", "sensitivity", sensitivity)
		music = c.get_value("audio", "music", music)
		first_run = false
	else:
		_autodetect()

func save() -> void:
	var c := ConfigFile.new()
	c.set_value("video", "quality", quality)
	c.set_value("video", "fps", fps)
	c.set_value("video", "render_scale", render_scale)
	c.set_value("video", "show_fps", show_fps)
	c.set_value("general", "lang", lang)
	c.set_value("general", "sensitivity", sensitivity)
	c.set_value("audio", "music", music)
	c.save(PATH)

## Primera vez: elige calidad según el equipo (gama baja / media / alta)
func _autodetect() -> void:
	var cores := OS.get_processor_count()
	var mobile := OS.has_feature("mobile")
	if mobile:
		quality = 0 if cores <= 4 else 1
		render_scale = 0.8 if cores <= 4 else 0.9
		fps = 30 if cores <= 4 else 60
	else:
		quality = 2
		render_scale = 1.0
		fps = 60
	var l := OS.get_locale_language()
	lang = l if l in ["es", "en"] else "en"

# ---------- controles ----------
func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("sprint", [KEY_SHIFT])
	_key("jump", [KEY_SPACE])
	_key("attack", [KEY_J])
	_key("toggle_cam", [KEY_V])
	_key("map", [KEY_M, KEY_TAB])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("interact", [KEY_E])
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)

func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
