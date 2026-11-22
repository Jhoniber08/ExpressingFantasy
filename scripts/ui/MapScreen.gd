class_name MapScreen
extends Control
## Mapa del mundo a pantalla completa:
## - pellizcar / rueda para zoom, arrastrar para mover
## - zoom automático para encuadrar tu posición y el destino
## - toca un punto o un lugar de la lista para marcar la ruta (estilo GTA)

signal closed

var world: World
var nav: Navigator
var player: Player
var zoom := 0.9                 # píxeles por metro
var center := Vector2.ZERO      # centro de la vista (mundo)
var _touches := {}
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _moved := false
var _pinch_d := 0.0
var _mouse_drag := false
var font: Font
var font_b: Font
var list_box: VBoxContainer
var info: Label
var _tw: Tween

func setup(w: World, n: Navigator, p: Player) -> void:
	world = w
	nav = n
	player = p
	font = load("res://fonts/Inter-Regular.otf")
	font_b = load("res://fonts/Poppins-Bold.ttf")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func _btn(text: String, cb: Callable, min_w := 120.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.12, 0.88)
	sb.border_color = Color(0.0, 0.85, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	var sh := sb.duplicate()
	sh.bg_color = Color(0.0, 0.25, 0.35, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_color_override("font_color", Color(0.85, 0.97, 1.0))
	b.pressed.connect(cb)
	return b

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(20, 16)
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	var title := Label.new()
	title.text = "◆ " + I18n.t("map")
	title.add_theme_font_override("font", font_b)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	title.custom_minimum_size = Vector2(150, 52)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(_btn("＋", func(): _zoom_by(1.4, size * 0.5), 60))
	top.add_child(_btn("－", func(): _zoom_by(1.0 / 1.4, size * 0.5), 60))
	top.add_child(_btn(I18n.t("center"), func(): _animate_to(Vector2(player.global_position.x, player.global_position.z), zoom)))
	top.add_child(_btn(I18n.t("clear_route"), _clear_route))
	top.add_child(_btn("✕ " + I18n.t("close"), func(): close()))
	# panel de lugares
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.02, 0.05, 0.10, 0.86)
	psb.border_color = Color(0.0, 0.8, 1.0, 0.5)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(12)
	psb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -300
	panel.offset_right = -16
	panel.offset_top = 84
	add_child(panel)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	panel.add_child(list_box)
	info = Label.new()
	info.text = I18n.t("tap_to_mark")
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_top = -40
	info.offset_left = 24
	add_child(info)

func _refresh_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = I18n.t("places")
	head.add_theme_font_override("font", font_b)
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	list_box.add_child(head)
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for pl in world.places:
		var d := int(pp.distance_to(pl.pos))
		var b := _btn("%s  ·  %d m" % [I18n.t(pl.id), d], func(): _route_to(pl.pos, I18n.t(pl.id)), 260)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size.y = 42
		list_box.add_child(b)

func _clear_route() -> void:
	nav.clear()
	info.text = I18n.t("tap_to_mark")
	queue_redraw()

func open() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true
	_refresh_list()
	auto_zoom()

func close() -> void:
	visible = false
	closed.emit()

## Zoom automático: encuadra al jugador y el destino (o la zona cercana)
func auto_zoom() -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var view := size - Vector2(340, 160)
	if nav.active:
		var tp := Vector2(nav.target.x, nav.target.z)
		var mn := Vector2(minf(pp.x, tp.x), minf(pp.y, tp.y))
		var mx := Vector2(maxf(pp.x, tp.x), maxf(pp.y, tp.y))
		for q in nav.route:
			mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.z))
			mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.z))
		var span := (mx - mn) + Vector2(90, 90)
		var z := clampf(minf(view.x / span.x, view.y / span.y), 0.35, 4.0)
		_animate_to((mn + mx) * 0.5 + Vector2(150.0 / z * 0.5, 0), z)
	else:
		_animate_to(pp, clampf(view.y / 420.0, 0.6, 3.0))

func _animate_to(c: Vector2, z: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "center", c, 0.55)
	_tw.tween_property(self, "zoom", z, 0.55)

func _route_to(p: Vector2, nm: String) -> void:
	nav.set_destination(p, nm)
	info.text = "%s: %s  ·  %d m" % [I18n.t("destination"), nm, int(nav.distance)]
	auto_zoom()

func _process(_d: float) -> void:
	if visible:
		queue_redraw()

func w2s(p: Vector2) -> Vector2:
	return (p - center) * zoom + size * 0.5

func s2w(s: Vector2) -> Vector2:
	return (s - size * 0.5) / zoom + center

func _zoom_by(f: float, at: Vector2) -> void:
	var before := s2w(at)
	zoom = clampf(zoom * f, 0.3, 6.0)
	var after := s2w(at)
	center += before - after
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.07, 0.14))
	var tl := w2s(Vector2(-World.HALF, -World.HALF))
	draw_texture_rect(world.map_texture, Rect2(tl, Vector2.ONE * World.HALF * 2.0 * zoom), false)
	# cuadrícula técnica cada 100 m
	var gc := Color(0.4, 0.9, 1.0, 0.07)
	for k in range(-500, 501, 100):
		draw_line(w2s(Vector2(k, -512)), w2s(Vector2(k, 512)), gc, 1.0)
		draw_line(w2s(Vector2(-512, k)), w2s(Vector2(512, k)), gc, 1.0)
	# ruta
	if nav.active and nav.route.size() > 1:
		var pts := PackedVector2Array()
		for q in nav.route:
			pts.append(w2s(Vector2(q.x, q.z)))
		draw_polyline(pts, Color(0, 0, 0, 0.6), 9.0, true)
		draw_polyline(pts, MapIcons.ROUTE_COLOR, 5.0, true)
	# lugares
	for pl in world.places:
		var sp := w2s(pl.pos)
		var r := clampf(13.0 * sqrt(zoom), 12.0, 24.0)
		MapIcons.badge(self, pl.icon, sp, r, pl.color)
		var txt := I18n.t(pl.id)
		var fs := 15 if zoom < 1.2 else 18
		var tw := font_b.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font_b, sp + Vector2(-tw * 0.5, r + 20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.85))
		draw_string(font_b, sp + Vector2(-tw * 0.5, r + 20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	# destino
	if nav.active:
		MapIcons.pin(self, w2s(Vector2(nav.target.x, nav.target.z)), 16.0)
	# jugador
	var pp := w2s(Vector2(player.global_position.x, player.global_position.z))
	draw_circle(pp, 16.0, Color(0.2, 0.9, 1.0, 0.18))
	MapIcons.arrow(self, pp, -player.facing + PI, 13.0, Color(1, 1, 1))
	# brújula y escala
	var cp := Vector2(size.x - 360, 120)
	draw_circle(cp, 26, Color(0.02, 0.05, 0.1, 0.8))
	draw_arc(cp, 26, 0, TAU, 32, Color(0.0, 0.85, 1.0, 0.7), 2.0, true)
	draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -20), cp + Vector2(6, 0), cp + Vector2(-6, 0)]), Color(1, 0.3, 0.3))
	draw_string(font_b, cp + Vector2(-6, 42), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
	var bar := 100.0 * zoom
	var bp := Vector2(24, size.y - 70)
	draw_line(bp, bp + Vector2(bar, 0), Color(1, 1, 1, 0.9), 3.0)
	draw_string(font, bp + Vector2(0, -8), "100 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_pos = event.position
				_press_time = Time.get_ticks_msec() / 1000.0
				_moved = false
			elif _touches.size() == 2:
				var ks := _touches.keys()
				_pinch_d = (_touches[ks[0]] as Vector2).distance_to(_touches[ks[1]])
		else:
			if _touches.size() == 1 and not _moved and Time.get_ticks_msec() / 1000.0 - _press_time < 0.4:
				_tap(event.position)
			_touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			center -= event.relative / zoom
			if event.position.distance_to(_press_pos) > 12.0:
				_moved = true
		elif _touches.size() >= 2:
			_moved = true
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var d := a.distance_to(b)
			if _pinch_d > 0.0:
				_zoom_by(d / _pinch_d, (a + b) * 0.5)
			_pinch_d = d
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_drag = true
				_press_pos = event.position
				_moved = false
			else:
				_mouse_drag = false
				if not _moved and not Settings.is_touch():
					_tap(event.position)
	elif event is InputEventMouseMotion and _mouse_drag and not Settings.is_touch():
		center -= event.relative / zoom
		if event.position.distance_to(_press_pos) > 8.0:
			_moved = true

func _tap(pos: Vector2) -> void:
	var wp := s2w(pos)
	# ¿tocó un lugar?
	for pl in world.places:
		if w2s(pl.pos).distance_to(pos) < 26.0:
			_route_to(pl.pos, I18n.t(pl.id))
			return
	if absf(wp.x) < World.HALF and absf(wp.y) < World.HALF:
		_route_to(wp, I18n.t("custom_point"))
