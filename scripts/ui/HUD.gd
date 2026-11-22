class_name HUD
extends CanvasLayer
## Interfaz en el juego: minimapa (gira y hace zoom solo), ruta, reloj, zona, controles táctiles y pausa.

signal to_title

var world: World
var player: Player
var nav: Navigator
var map_screen: MapScreen
var font: Font
var font_b: Font
var font_m: Font

var root: Control
var minimap: ColorRect
var mm_mat: ShaderMaterial
var mm_overlay: Control
var mm_span := 0.11
var clock: Label
var zone: Label
var route_lbl: Label
var toast: Label
var fps_lbl: Label
var hint: Label
var pause_panel: Control
var _zone_name := ""
var _toast_t := 0.0

# táctil
var touch := false
var joy_base := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_index := -1
var look_index := -1
var joy_ctrl: Control
var buttons: Array = []   # {rect, action}
var sprint_btn_lbl: Label

const MM_SIZE := 210.0

func setup(w: World, p: Player, n: Navigator) -> void:
	world = w
	player = p
	nav = n
	font = load("res://fonts/Inter-Regular.otf")
	font_b = load("res://fonts/Poppins-Bold.ttf")
	font_m = load("res://fonts/DejaVuSansMono.ttf")
	touch = Settings.is_touch()
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_minimap()
	_build_labels()
	if touch:
		_build_touch()
	_build_pause()
	map_screen = MapScreen.new()
	add_child(map_screen)
	map_screen.setup(world, nav, player)
	map_screen.closed.connect(_on_map_closed)
	nav.arrived.connect(func(): show_toast(I18n.t("arrived")))
	show_toast(I18n.t("welcome"))
	hint.text = I18n.t("hint_touch") if touch else I18n.t("hint_pc")

func _label(fnt: Font, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fnt)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

# ---------------------------------------------------------------- minimapa
func _build_minimap() -> void:
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.03, 0.08, 0.7)
	sb.set_corner_radius_all(int(MM_SIZE * 0.5 + 6))
	sb.border_color = Color(0.0, 0.85, 1.0, 0.55)
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = Vector2(14, 14)
	frame.size = Vector2(MM_SIZE + 12, MM_SIZE + 12)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_minimap_input)
	root.add_child(frame)
	minimap = ColorRect.new()
	minimap.position = Vector2(6, 6)
	minimap.size = Vector2(MM_SIZE, MM_SIZE)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_mat = ShaderMaterial.new()
	mm_mat.shader = load("res://shaders/minimap.gdshader")
	mm_mat.set_shader_parameter("map_tex", world.map_texture)
	minimap.material = mm_mat
	frame.add_child(minimap)
	mm_overlay = Control.new()
	mm_overlay.position = Vector2(6, 6)
	mm_overlay.size = Vector2(MM_SIZE, MM_SIZE)
	mm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_overlay.draw.connect(_draw_minimap_overlay)
	frame.add_child(mm_overlay)

func _on_minimap_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		open_map()

func _mm_point(world_xz: Vector2) -> Vector2:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var d := world_xz - pp
	var c := cos(player.yaw)
	var s := sin(player.yaw)
	var q := Vector2(c * d.x - s * d.y, s * d.x + c * d.y)
	return q / (mm_span * World.HALF * 2.0) * (MM_SIZE * 0.5) + Vector2.ONE * MM_SIZE * 0.5

func _draw_minimap_overlay() -> void:
	var ci := mm_overlay
	var cen := Vector2.ONE * MM_SIZE * 0.5
	var rad := MM_SIZE * 0.5 - 3.0
	# ruta
	if nav.active and nav.route.size() > 1:
		var prev := _mm_point(Vector2(nav.route[0].x, nav.route[0].z))
		for i in range(1, nav.route.size()):
			var a3 := nav.route[i - 1]
			var b3 := nav.route[i]
			var steps := maxi(int(a3.distance_to(b3) / 6.0), 1)
			for k in range(1, steps + 1):
				var q3 := a3.lerp(b3, float(k) / steps)
				var cur := _mm_point(Vector2(q3.x, q3.z))
				if prev.distance_to(cen) < rad and cur.distance_to(cen) < rad:
					ci.draw_line(prev, cur, Color(0, 0, 0, 0.55), 6.0, true)
					ci.draw_line(prev, cur, MapIcons.ROUTE_COLOR, 3.5, true)
				prev = cur
	# lugares
	for pl in world.places:
		var p := _mm_point(pl.pos)
		if p.distance_to(cen) < rad - 8.0:
			MapIcons.badge(ci, pl.icon, p, 9.0, pl.color)
	# destino (se queda en el borde si está lejos)
	if nav.active:
		var tp := _mm_point(Vector2(nav.target.x, nav.target.z))
		if tp.distance_to(cen) > rad - 10.0:
			tp = cen + (tp - cen).normalized() * (rad - 10.0)
		MapIcons.pin(ci, tp, 9.0)
	# norte
	var n := _mm_point(Vector2(player.global_position.x, player.global_position.z - 10000.0))
	var np := cen + (n - cen).normalized() * (rad - 2.0)
	ci.draw_circle(np, 10.0, Color(0.03, 0.05, 0.1, 0.95))
	ci.draw_string(font_b, np + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.4, 0.4))
	# jugador (flecha según hacia dónde mira el personaje)
	var rel := player.facing - (player.yaw + PI)
	MapIcons.arrow(ci, cen, -rel, 10.0, Color(1, 1, 1))

# ---------------------------------------------------------------- textos
func _build_labels() -> void:
	clock = _label(font_m, 20, Color(0.8, 0.95, 1.0))
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -220
	clock.offset_right = -84
	clock.offset_top = 18
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zone = _label(font_b, 30, Color(1, 1, 1))
	zone.anchor_left = 0.5
	zone.anchor_right = 0.5
	zone.offset_left = -300
	zone.offset_right = 300
	zone.offset_top = 22
	zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone.modulate.a = 0.0
	route_lbl = _label(font_b, 18, Color(1.0, 0.6, 0.95))
	route_lbl.position = Vector2(16, MM_SIZE + 36)
	toast = _label(font_b, 24, Color(0.6, 1.0, 0.85))
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -400
	toast.offset_right = 400
	toast.offset_top = 80
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	fps_lbl = _label(font_m, 14, Color(0.6, 1.0, 0.6))
	fps_lbl.anchor_left = 1.0
	fps_lbl.anchor_right = 1.0
	fps_lbl.offset_left = -220
	fps_lbl.offset_right = -84
	fps_lbl.offset_top = 46
	fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint = _label(font, 15, Color(0.85, 0.92, 1.0, 0.85))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -420
	hint.offset_right = 420
	hint.offset_top = -34
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var menu := _round_button("≡", Vector2(-70, 14), func(): set_paused(true), 48)
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	var mapb := _round_button("🗺", Vector2(MM_SIZE - 30, MM_SIZE - 32), func(): open_map(), 46)
	mapb.text = I18n.t("map")
	mapb.add_theme_font_size_override("font_size", 12)
	mapb.size = Vector2(64, 30)

func _round_button(txt: String, pos: Vector2, cb: Callable, sz := 48) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = Vector2(sz, sz)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.05, 0.11, 0.8)
	sb.border_color = Color(0.0, 0.85, 1.0, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(sz)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(cb)
	root.add_child(b)
	return b

func show_toast(t: String) -> void:
	toast.text = t
	_toast_t = 3.5

# ---------------------------------------------------------------- controles táctiles
func _build_touch() -> void:
	joy_ctrl = Control.new()
	joy_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ctrl.draw.connect(_draw_touch)
	root.add_child(joy_ctrl)

func _touch_buttons() -> Array:
	var vs := root.get_viewport_rect().size
	return [
		{"id": "jump", "label": I18n.t("jump"), "c": Vector2(vs.x - 95, vs.y - 110), "r": 54.0},
		{"id": "attack", "label": I18n.t("attack"), "c": Vector2(vs.x - 215, vs.y - 80), "r": 44.0},
		{"id": "run", "label": I18n.t("run"), "c": Vector2(vs.x - 110, vs.y - 240), "r": 40.0},
		{"id": "camera", "label": I18n.t("camera"), "c": Vector2(vs.x - 230, vs.y - 200), "r": 34.0},
	]

func _draw_touch() -> void:
	var vs := root.get_viewport_rect().size
	var base := joy_base if joy_index >= 0 else Vector2(150, vs.y - 150)
	joy_ctrl.draw_circle(base, 72.0, Color(0.0, 0.05, 0.1, 0.35))
	joy_ctrl.draw_arc(base, 72.0, 0, TAU, 40, Color(0.0, 0.85, 1.0, 0.5), 2.0, true)
	joy_ctrl.draw_circle(base + joy_vec * 60.0, 30.0, Color(0.6, 0.95, 1.0, 0.55))
	for b in _touch_buttons():
		var active: bool = b.id == "run" and player.sprint_toggle
		joy_ctrl.draw_circle(b.c, b.r, Color(0.0, 0.25, 0.35, 0.65) if active else Color(0.0, 0.05, 0.1, 0.45))
		joy_ctrl.draw_arc(b.c, b.r, 0, TAU, 36, Color(0.0, 0.85, 1.0, 0.75), 2.0, true)
		var fs := 15
		var tw := font_b.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		joy_ctrl.draw_string(font_b, b.c + Vector2(-tw * 0.5, 6), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.98, 1.0))

func _input(event: InputEvent) -> void:
	if map_screen.visible or pause_panel.visible:
		return
	if not touch:
		if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if event.position.x > MM_SIZE + 30 or event.position.y > MM_SIZE + 30:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.is_action_pressed("map"):
			open_map()
		elif event.is_action_pressed("pause"):
			set_paused(true)
		return
	if event is InputEventScreenTouch:
		var vs := root.get_viewport_rect().size
		if event.pressed:
			for b in _touch_buttons():
				if event.position.distance_to(b.c) < b.r + 10.0:
					_press_button(b.id)
					get_viewport().set_input_as_handled()
					return
			if event.position.x < MM_SIZE + 40 and event.position.y < MM_SIZE + 60:
				return
			if event.position.x < vs.x * 0.42 and joy_index < 0:
				joy_index = event.index
				joy_base = event.position
				joy_vec = Vector2.ZERO
			elif look_index < 0:
				look_index = event.index
		else:
			if event.index == joy_index:
				joy_index = -1
				joy_vec = Vector2.ZERO
				player.touch_move = Vector2.ZERO
			elif event.index == look_index:
				look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			var v: Vector2 = (event.position - joy_base) / 60.0
			joy_vec = v.limit_length(1.0)
			player.touch_move = Vector2(joy_vec.x, -joy_vec.y)
		elif event.index == look_index:
			player.look(event.relative * 1.6)

func _press_button(id: String) -> void:
	match id:
		"jump":
			Input.action_press("jump")
			await get_tree().create_timer(0.12).timeout
			Input.action_release("jump")
		"attack":
			player.attack()
		"run":
			player.sprint_toggle = not player.sprint_toggle
		"camera":
			player.toggle_camera()

# ---------------------------------------------------------------- mapa y pausa
func open_map() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	map_screen.open()

func _on_map_closed() -> void:
	pass

func _build_pause() -> void:
	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0.0, 0.02, 0.06, 0.78)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -170
	box.offset_right = 170
	box.offset_top = -120
	box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(box)
	var t := Label.new()
	t.text = I18n.t("paused")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", font_b)
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	box.add_child(t)
	for pair in [["resume", _resume], ["map", _pause_to_map], ["to_title", _pause_to_title]]:
		var b := Button.new()
		b.text = I18n.t(pair[0])
		b.custom_minimum_size = Vector2(340, 60)
		b.add_theme_font_override("font", font_b)
		b.add_theme_font_size_override("font_size", 22)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.06, 0.12, 0.9)
		sb.border_color = Color(0.0, 0.85, 1.0, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(pair[1])
		box.add_child(b)

func _resume() -> void:
	set_paused(false)

func _pause_to_map() -> void:
	set_paused(false)
	open_map()

func _pause_to_title() -> void:
	set_paused(false)
	to_title.emit()

func set_paused(p: bool) -> void:
	pause_panel.visible = p
	get_tree().paused = p
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------------------------------------------------------------- por fotograma
func _process(delta: float) -> void:
	if player == null:
		return
	# zoom automático del minimapa: se aleja al correr
	var sp := player.speed_h()
	var target_span := lerpf(0.085, 0.15, clampf(sp / Player.RUN, 0.0, 1.0))
	mm_span = lerpf(mm_span, target_span, clampf(delta * 1.5, 0.0, 1.0))
	var uv := world.world_to_uv(player.global_position.x, player.global_position.z)
	mm_mat.set_shader_parameter("center_uv", uv)
	mm_mat.set_shader_parameter("span", mm_span)
	mm_mat.set_shader_parameter("angle", -player.yaw)
	mm_overlay.queue_redraw()
	# reloj
	var mins := int(world.time_of_day * 24.0 * 60.0)
	clock.text = "%02d:%02d  %s" % [mins / 60, mins % 60, "☾" if world.night > 0.5 else "☀"]
	fps_lbl.visible = Settings.show_fps
	fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	# zona
	var zn := world.zone_name_at(player.global_position.x, player.global_position.z)
	if zn != _zone_name:
		_zone_name = zn
		zone.text = zn
		var tw := create_tween()
		tw.tween_property(zone, "modulate:a", 1.0, 0.4)
		tw.tween_interval(2.2)
		tw.tween_property(zone, "modulate:a", 0.0, 0.8)
	# ruta
	if nav.active:
		route_lbl.text = "▶ %s · %d m" % [nav.target_name, int(nav.distance)]
	else:
		route_lbl.text = ""
	# aviso
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	if hint.modulate.a > 0.0:
		hint.modulate.a = maxf(hint.modulate.a - delta * 0.06, 0.0)
	if touch:
		joy_ctrl.queue_redraw()
