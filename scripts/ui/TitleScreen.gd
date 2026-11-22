class_name TitleScreen
extends CanvasLayer
## Pantalla de inicio "técnica y viva": la isla de fondo en vuelo cinematográfico,
## consola de arranque con el progreso real, barra de carga y menú neón.

signal explore

var font_b: Font
var font: Font
var font_m: Font
var root: Control
var console_lines: VBoxContainer
var bar_fill: ColorRect
var bar_lbl: Label
var load_box: Control
var menu: VBoxContainer
var settings_panel: PanelContainer
var credits_panel: PanelContainer
var title_lbl: Label
var title2_lbl: Label
var tag_lbl: Label
var live_lbl: Label
var info_lbl: Label
var _t := 0.0
var _start_ms := 0
var _ready_done := false

func _ready() -> void:
	layer = 10
	_start_ms = Time.get_ticks_msec()
	font_b = load("res://fonts/Poppins-Bold.ttf")
	font = load("res://fonts/Inter-Regular.otf")
	font_m = load("res://fonts/DejaVuSansMono.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var om := ShaderMaterial.new()
	om.shader = load("res://shaders/scanlines.gdshader")
	overlay.material = om
	root.add_child(overlay)
	_build_left()
	_build_right()
	_build_settings()
	_build_credits()

func _lab(parent: Control, text: String, fnt: Font, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", fnt)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _build_left() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(64, 46)
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 4)
	root.add_child(col)
	tag_lbl = _lab(col, "◆ GODOT %s · OFFLINE BUILD · v%s" % [Engine.get_version_info().string.split(".stable")[0], ProjectSettings.get_setting("application/config/version")], font_m, 14, Color(0.3, 0.9, 1.0))
	title_lbl = _lab(col, "EXPRESSING", font_b, 74, Color(1, 1, 1))
	var ls := LabelSettings.new()
	ls.font = font_b
	ls.font_size = 74
	ls.font_color = Color(0.97, 0.99, 1.0)
	ls.shadow_color = Color(0.0, 0.8, 1.0, 0.55)
	ls.shadow_size = 18
	ls.shadow_offset = Vector2.ZERO
	title_lbl.label_settings = ls
	title2_lbl = _lab(col, "FANTASY", font_b, 74, Color(0.5, 0.95, 1.0))
	var ls2 := ls.duplicate()
	ls2.font_color = Color(0.45, 0.93, 1.0)
	ls2.shadow_color = Color(0.7, 0.2, 1.0, 0.6)
	title2_lbl.label_settings = ls2
	title_lbl.add_theme_constant_override("line_spacing", -20)
	var rem := _lab(col, "R E M A S T E R E D", font_b, 20, Color(1.0, 0.4, 0.9))
	rem.add_theme_color_override("font_shadow_color", Color(1.0, 0.2, 0.8, 0.6))
	var sub := _lab(col, "Ciudad · Puerto · Bosque · Montaña · Lago · Ruinas · Aldea" if Settings.lang == "es" else "City · Harbor · Forest · Mountain · Lake · Ruins · Village", font, 17, Color(0.78, 0.86, 0.95))
	sub.custom_minimum_size.y = 34
	# carga
	load_box = VBoxContainer.new()
	load_box.add_theme_constant_override("separation", 6)
	col.add_child(load_box)
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.0, 0.03, 0.07, 0.72)
	psb.border_color = Color(0.0, 0.8, 1.0, 0.35)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(8)
	psb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	panel.custom_minimum_size = Vector2(560, 196)
	load_box.add_child(panel)
	console_lines = VBoxContainer.new()
	console_lines.add_theme_constant_override("separation", 2)
	panel.add_child(console_lines)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	load_box.add_child(bar_row)
	var lbl := _lab(bar_row, I18n.t("loading"), font_m, 14, Color(0.6, 0.95, 1.0))
	lbl.custom_minimum_size.x = 150
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.0, 0.15, 0.22, 0.8)
	bar_bg.custom_minimum_size = Vector2(320, 10)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar_bg)
	bar_fill = ColorRect.new()
	bar_fill.color = Color(0.0, 0.9, 1.0)
	bar_fill.size = Vector2(0, 10)
	bar_bg.add_child(bar_fill)
	bar_lbl = _lab(bar_row, "0%", font_m, 14, Color(1, 1, 1))
	# menú (aparece al terminar)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu.visible = false
	col.add_child(menu)
	menu.add_child(_menu_btn(I18n.t("explore"), _on_explore, true))
	var mp := _menu_btn(I18n.t("multiplayer") + "   ·   " + I18n.t("soon"), func(): pass, false)
	mp.disabled = true
	menu.add_child(mp)
	menu.add_child(_menu_btn(I18n.t("settings"), func(): settings_panel.visible = true, false))
	menu.add_child(_menu_btn(I18n.t("credits"), func(): credits_panel.visible = true, false))

func _menu_btn(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 62 if primary else 52)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 26 if primary else 19)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.55, 0.7, 0.9) if primary else Color(0.0, 0.04, 0.09, 0.75)
	sb.border_color = Color(0.3, 0.95, 1.0, 0.95) if primary else Color(0.0, 0.8, 1.0, 0.55)
	sb.border_width_left = 6
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_right = 1
	sb.set_corner_radius_all(6)
	var sh := sb.duplicate()
	sh.bg_color = Color(0.0, 0.7, 0.88, 1.0) if primary else Color(0.0, 0.2, 0.3, 0.9)
	var sd := sb.duplicate()
	sd.bg_color = Color(0.05, 0.05, 0.08, 0.6)
	sd.border_color = Color(0.4, 0.4, 0.5, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("disabled", sd)
	b.add_theme_color_override("font_color", Color(1, 1, 1) if primary else Color(0.85, 0.96, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.7))
	b.pressed.connect(cb)
	return b

func _build_right() -> void:
	live_lbl = _lab(root, "◉ LIVE WORLD", font_m, 14, Color(1.0, 0.35, 0.45))
	live_lbl.anchor_left = 1.0
	live_lbl.anchor_right = 1.0
	live_lbl.offset_left = -200
	live_lbl.offset_top = 28
	info_lbl = _lab(root, "", font_m, 13, Color(0.6, 0.85, 1.0, 0.85))
	info_lbl.anchor_left = 1.0
	info_lbl.anchor_right = 1.0
	info_lbl.anchor_top = 1.0
	info_lbl.anchor_bottom = 1.0
	info_lbl.offset_left = -470
	info_lbl.offset_right = -28
	info_lbl.offset_top = -120
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var gpu := RenderingServer.get_video_adapter_name()
	var qn := I18n.t("q_" + Settings.QUALITY_NAMES[Settings.quality])
	info_lbl.text = "GPU  %s\nCPU  %d núcleos · %s\n%s  %s · %d FPS máx\n%s" % [gpu.substr(0, 34), OS.get_processor_count(), OS.get_name(), I18n.t("quality").to_upper(), qn, Settings.fps, I18n.t("offline")]
	var credit := _lab(root, "Jhoniber De la Cruz  ×  Justin Manuel Nolasco «Mano»", font, 14, Color(0.8, 0.88, 1.0, 0.8))
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 64
	credit.offset_top = -40

func _panel(title: String) -> Array:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.04, 0.09, 0.95)
	sb.border_color = Color(0.0, 0.85, 1.0, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(26)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(560, 0)
	p.add_child(v)
	_lab(v, title, font_b, 30, Color(0.4, 0.95, 1.0))
	return [p, v]

func _seg(v: VBoxContainer, label: String, options: Array, current: int, cb: Callable) -> void:
	_lab(v, label, font, 17, Color(0.85, 0.92, 1.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.custom_minimum_size = Vector2(120, 44)
		b.add_theme_font_override("font", font_b)
		b.add_theme_font_size_override("font_size", 16)
		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(0.02, 0.07, 0.13, 0.9)
		sn.border_color = Color(0.0, 0.7, 0.9, 0.5)
		sn.set_border_width_all(1)
		sn.set_corner_radius_all(8)
		var sp := sn.duplicate()
		sp.bg_color = Color(0.0, 0.5, 0.65, 0.95)
		sp.border_color = Color(0.4, 1.0, 1.0)
		b.add_theme_stylebox_override("normal", sn)
		b.add_theme_stylebox_override("hover", sn)
		b.add_theme_stylebox_override("pressed", sp)
		b.add_theme_stylebox_override("focus", sn)
		var idx := i
		b.pressed.connect(func(): cb.call(idx))
		row.add_child(b)

func _slider(v: VBoxContainer, label: String, mn: float, mx: float, val: float, cb: Callable) -> void:
	_lab(v, label, font, 17, Color(0.85, 0.92, 1.0))
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(520, 30)
	s.value_changed.connect(cb)
	v.add_child(s)

func _build_settings() -> void:
	var pv := _panel(I18n.t("settings"))
	settings_panel = pv[0]
	var v: VBoxContainer = pv[1]
	_seg(v, I18n.t("quality"), [I18n.t("q_low"), I18n.t("q_medium"), I18n.t("q_high"), I18n.t("q_ultra")], Settings.quality, func(i): Settings.set_quality(i))
	var fps_opts := [30, 60, 90, 120]
	_seg(v, I18n.t("fps_limit"), ["30", "60", "90", "120"], maxi(fps_opts.find(Settings.fps), 0), func(i): Settings.fps = fps_opts[i]; Settings.save(); Settings.apply())
	_slider(v, I18n.t("render_scale"), 0.5, 1.0, Settings.render_scale, func(x): Settings.render_scale = x; Settings.save(); Settings.apply())
	_slider(v, I18n.t("sensitivity"), 0.3, 2.0, Settings.sensitivity, func(x): Settings.sensitivity = x; Settings.save())
	_seg(v, I18n.t("language"), ["Español", "English"], 0 if Settings.lang == "es" else 1, func(i): Settings.lang = "es" if i == 0 else "en"; Settings.save())
	var cb := CheckButton.new()
	cb.text = I18n.t("show_fps")
	cb.button_pressed = Settings.show_fps
	cb.add_theme_font_override("font", font)
	cb.toggled.connect(func(on): Settings.show_fps = on; Settings.save())
	v.add_child(cb)
	_lab(v, I18n.t("apply_restart"), font, 13, Color(0.6, 0.75, 0.9))
	v.add_child(_menu_btn(I18n.t("back"), func(): settings_panel.visible = false, false))

func _build_credits() -> void:
	var pv := _panel(I18n.t("credits"))
	credits_panel = pv[0]
	var v: VBoxContainer = pv[1]
	var l := _lab(v, I18n.t("credits_text"), font, 18, Color(0.9, 0.95, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_menu_btn(I18n.t("back"), func(): credits_panel.visible = false, false))

# ---------------------------------------------------------------- progreso
func on_progress(pct: float, line: String) -> void:
	var ms := Time.get_ticks_msec() - _start_ms
	var row := HBoxContainer.new()
	var ok := _lab(row, "[ OK ]", font_m, 13, Color(0.4, 1.0, 0.5))
	ok.custom_minimum_size.x = 62
	_lab(row, "%6.2fs" % (ms / 1000.0), font_m, 13, Color(0.45, 0.6, 0.75)).custom_minimum_size.x = 70
	var l := _lab(row, line, font_m, 13, Color(0.8, 0.92, 1.0))
	l.clip_text = true
	l.custom_minimum_size.x = 400
	console_lines.add_child(row)
	while console_lines.get_child_count() > 9:
		console_lines.get_child(0).free()
	var tw := create_tween()
	tw.tween_property(bar_fill, "size:x", 320.0 * pct, 0.25)
	bar_lbl.text = "%d%%" % int(pct * 100.0)

func on_ready() -> void:
	_ready_done = true
	on_progress(1.0, I18n.t("ready") + " · " + I18n.t("offline"))
	await get_tree().create_timer(0.5).timeout
	var tw := create_tween()
	tw.tween_property(load_box, "modulate:a", 0.0, 0.4)
	await tw.finished
	load_box.visible = false
	menu.visible = true
	menu.modulate.a = 0.0
	var i := 0
	for b in menu.get_children():
		b.position.x -= 40
	var tw2 := create_tween()
	tw2.tween_property(menu, "modulate:a", 1.0, 0.5)

func _on_explore() -> void:
	explore.emit()

func hide_title() -> void:
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.45)
	await tw.finished
	visible = false

func show_title() -> void:
	visible = true
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.45)

func _process(delta: float) -> void:
	_t += delta
	if title_lbl and title_lbl.label_settings:
		title_lbl.label_settings.shadow_size = int(14 + 6 * sin(_t * 2.0))
	if live_lbl:
		live_lbl.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
