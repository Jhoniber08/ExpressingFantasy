class_name Places
extends Node3D
## Construye los lugares del mapa. Cada uno tiene un monumento visible de lejos para reconocerlo.

var w: World
var rng := RandomNumberGenerator.new()
var mat_vc: StandardMaterial3D
var mat_build: ShaderMaterial
var mat_fol: ShaderMaterial
var font: Font

const PALETTE := [Color("#e8dcc4"), Color("#d9c3a5"), Color("#c9a27e"), Color("#b8c4cc"), Color("#9fb3c8"),
	Color("#e6cfa8"), Color("#c47d5a"), Color("#a9b8a0"), Color("#d8d2c8"), Color("#8a9bb0")]

func build(world: World) -> void:
	w = world
	rng.seed = 777
	mat_vc = MeshKit.vc_material(0.85)
	mat_build = ShaderMaterial.new()
	mat_build.shader = load("res://shaders/building.gdshader")
	mat_fol = ShaderMaterial.new()
	mat_fol.shader = load("res://shaders/foliage.gdshader")
	font = load("res://fonts/Poppins-Bold.ttf")
	_city()
	await get_tree().process_frame
	_port()
	_village()
	await get_tree().process_frame
	_ruins()
	_lake_shrine()
	_mountain_beacon()
	_giant_tree()

# ---------------------------------------------------------------- utilidades
func _mi(mesh: Mesh, mat: Material, nm: String, shadows := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.name = nm
	if not shadows:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

func _body(nm: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = nm
	add_child(b)
	return b

func _col_box(b: StaticBody3D, center: Vector3, size: Vector3, rot := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = Transform3D(Basis(Vector3.UP, rot), center)
	b.add_child(cs)

func _col_cyl(b: StaticBody3D, center: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = center
	b.add_child(cs)

func _sign(text: String, pos: Vector3, color: Color, size := 0.09, range_end := 160.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 64
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.pixel_size = size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.visibility_range_end = range_end
	l.visibility_range_begin = 60.0
	l.position = pos
	add_child(l)

func _light(pos: Vector3, color: Color, energy: float, rng_m: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng_m
	o.shadow_enabled = false
	add_child(o)
	return o

func _glow(color: Color) -> StandardMaterial3D:
	var m := MeshKit.glow_material(color, 1.0)
	w.glow_mats.append(m)
	return m

func _fp(center: Vector2, size: Vector2, color: Color) -> void:
	w.footprints.append({"rect": Rect2(center - size * 0.5, size), "color": color})

# =====================================================================
#  CIUDAD AURELIA — calles en cuadrícula, rascacielos al centro, plaza con torre de cristal y muralla
# =====================================================================
func _city() -> void:
	var C: Vector2 = World.P_CITY
	var R := World.CITY_R
	var H: float = w.places[0].h
	var ground := MeshKit.new()
	var bld := MeshKit.new()
	var fol := MeshKit.new()
	var glow := MeshKit.new()
	var body := _body("CityBody")
	w.block_circle(C, R + 8.0)

	# asfalto general y muralla visual
	ground.cyl(Vector3(C.x, H - 0.05, C.y), R + 1.0, R + 1.5, 0.4, Color(0.20, 0.20, 0.22), 48)
	var lines := [-72.0, -36.0, 0.0, 36.0, 72.0]
	var intervals := [[-104.0, -76.0], [-68.0, -40.0], [-32.0, -6.0], [6.0, 32.0], [40.0, 68.0], [76.0, 104.0]]
	# líneas de las avenidas
	for k in range(-100, 101, 8):
		if absf(k) < 28:
			continue
		ground.box(Vector3(C.x + k, H + 0.17, C.y), Vector3(3.5, 0.02, 0.35), Color(0.95, 0.82, 0.3))
		ground.box(Vector3(C.x, H + 0.17, C.y + k), Vector3(0.35, 0.02, 3.5), Color(0.95, 0.82, 0.3))
	var park_blocks := [Vector2i(1, 4), Vector2i(4, 1), Vector2i(0, 2)]
	for ix in intervals.size():
		for iz in intervals.size():
			var x0: float = intervals[ix][0]
			var x1: float = intervals[ix][1]
			var z0: float = intervals[iz][0]
			var z1: float = intervals[iz][1]
			var bc := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if bc.length() > 100.0:
				continue
			var bs := Vector2(x1 - x0, z1 - z0)
			# acera (bloque elevado)
			ground.box(Vector3(C.x + bc.x, H + 0.12, C.y + bc.y), Vector3(bs.x, 0.3, bs.y), Color(0.63, 0.61, 0.57))
			if Vector2i(ix, iz) in park_blocks:
				ground.box(Vector3(C.x + bc.x, H + 0.29, C.y + bc.y), Vector3(bs.x - 3.0, 0.06, bs.y - 3.0), Color(0.30, 0.50, 0.24))
				for t in 5:
					var tp := C + bc + Vector2(rng.randf_range(-bs.x * 0.35, bs.x * 0.35), rng.randf_range(-bs.y * 0.35, bs.y * 0.35))
					_tree_simple(fol, Vector3(tp.x, H + 0.3, tp.y), rng.randf_range(0.8, 1.2))
				_fp(C + bc, bs - Vector2(3, 3), Color(0.34, 0.56, 0.30))
				continue
			# lotes
			var horizontal := bs.x >= bs.y
			var long_len := bs.x if horizontal else bs.y
			var n := clampi(int(long_len / 15.0), 1, 3)
			for li in n:
				var t0 := -long_len * 0.5 + long_len * li / n
				var t1 := -long_len * 0.5 + long_len * (li + 1) / n
				var lc := bc + (Vector2((t0 + t1) * 0.5, 0) if horizontal else Vector2(0, (t0 + t1) * 0.5))
				var d := lc.length()
				if d < 34.0 or d > 97.0:
					continue
				var lot := Vector2((t1 - t0) - 3.0, bs.y - 4.0) if horizontal else Vector2(bs.x - 4.0, (t1 - t0) - 3.0)
				var hmax := lerpf(48.0, 11.0, clampf((d - 30.0) / 70.0, 0.0, 1.0))
				var hb := snappedf(hmax * rng.randf_range(0.55, 1.05), 3.2) + 3.2
				var col: Color = PALETTE[rng.randi() % PALETTE.size()]
				col.a = 1.0
				var c3 := Vector3(C.x + lc.x, H + 0.27 + hb * 0.5, C.y + lc.y)
				bld.box(c3, Vector3(lot.x, hb, lot.y), col)
				_col_box(body, c3, Vector3(lot.x, hb, lot.y))
				# escalonado para rascacielos
				if hb > 28.0:
					var top := Vector3(lot.x * 0.65, hb * 0.25, lot.y * 0.65)
					bld.box(Vector3(c3.x, H + 0.27 + hb + top.y * 0.5, c3.z), top, col.darkened(0.08))
					glow.sphere(Vector3(c3.x, H + 0.27 + hb + top.y + 1.2, c3.z), 0.45, Color(1, 0.2, 0.2))
				else:
					var rc := Color(0.35, 0.35, 0.38, 0.0)
					bld.box(Vector3(c3.x + lot.x * 0.2, H + 0.27 + hb + 0.8, c3.z - lot.y * 0.15), Vector3(2.4, 1.6, 2.0), rc)
				_fp(C + lc, lot, col.darkened(0.45))

	# plaza central con fuente y Torre de Cristal
	ground.cyl(Vector3(C.x, H + 0.16, C.y), 27.0, 27.0, 0.12, Color(0.86, 0.82, 0.72), 40)
	ground.cyl(Vector3(C.x, H + 0.18, C.y), 20.0, 20.0, 0.12, Color(0.72, 0.62, 0.52), 40)
	ground.cyl(Vector3(C.x, H + 0.20, C.y), 16.0, 16.0, 0.12, Color(0.88, 0.84, 0.76), 40)
	bld.cyl(Vector3(C.x, H + 0.7, C.y), 10.5, 11.0, 1.0, Color(0.82, 0.80, 0.76, 0.0), 32)
	var water := MeshKit.new()
	water.cyl(Vector3(C.x, H + 1.05, C.y), 9.8, 9.8, 0.1, Color(0.2, 0.6, 0.85), 32)
	var wm := MeshKit.glow_material(Color(0.25, 0.65, 0.95), 0.4)
	_mi(water.commit(), wm, "FountainWater", false)
	_col_cyl(body, Vector3(C.x, H + 0.7, C.y), 11.0, 1.2)
	# torre
	bld.box(Vector3(C.x, H + 4.0, C.y), Vector3(7, 6.5, 7), Color(0.88, 0.86, 0.82, 0.0))
	bld.cyl(Vector3(C.x, H + 30.0, C.y), 1.7, 2.6, 46.0, Color(0.92, 0.92, 0.95, 0.0), 8)
	bld.cyl(Vector3(C.x, H + 53.5, C.y), 3.0, 3.0, 1.0, Color(0.80, 0.70, 0.40, 0.0), 8)
	_col_box(body, Vector3(C.x, H + 4.0, C.y), Vector3(7, 6.5, 7))
	_col_cyl(body, Vector3(C.x, H + 30.0, C.y), 2.6, 46.0)
	var crystal := MeshKit.new()
	crystal.sphere(Vector3(C.x, H + 59.0, C.y), 3.2, Color(0.4, 0.95, 1.0), Vector3(1, 2.1, 1), 4, 2)
	var cm := _glow(Color(0.3, 0.9, 1.0))
	_mi(crystal.commit(), cm, "CrystalTop", false)
	_light(Vector3(C.x, H + 59.0, C.y), Color(0.4, 0.9, 1.0), 3.0, 60.0)
	_sign(I18n.t("city"), Vector3(C.x, H + 70.0, C.y), Color(0.6, 0.95, 1.0), 0.14, 420.0)

	# muralla con 4 puertas y torres
	var wall_col := Color(0.70, 0.66, 0.58, 0.0)
	var seg_n := 72
	for s in seg_n:
		var a0 := TAU * s / seg_n
		var a1 := TAU * (s + 1) / seg_n
		var am := (a0 + a1) * 0.5
		var near_gate := false
		for g in [0.0, PI * 0.5, PI, PI * 1.5]:
			if absf(wrapf(am - g, -PI, PI)) < 0.085:
				near_gate = true
		if near_gate:
			continue
		var rr := R + 3.0
		var p0 := C + Vector2(cos(a0), sin(a0)) * rr
		var p1 := C + Vector2(cos(a1), sin(a1)) * rr
		var mid := (p0 + p1) * 0.5
		var length := p0.distance_to(p1) + 0.4
		var rot := -am + PI * 0.5
		var gh := maxf(w.height_at(mid.x, mid.y), H - 1.0)
		bld.box(Vector3(mid.x, gh + 3.0, mid.y), Vector3(length, 6.5, 2.4), wall_col, rot)
		if s % 2 == 0:
			bld.box(Vector3(mid.x, gh + 6.6, mid.y), Vector3(length * 0.5, 0.9, 2.5), wall_col.darkened(0.05), rot)
		_col_box(body, Vector3(mid.x, gh + 3.0, mid.y), Vector3(length, 6.5, 2.4), rot)
	for g in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir := Vector2(cos(g), sin(g))
		var side := dir.orthogonal()
		for sgn in [-1.0, 1.0]:
			var tp: Vector2 = C + dir * (R + 3.0) + side * 9.5 * sgn
			var th := maxf(w.height_at(tp.x, tp.y), H - 1.0)
			bld.cyl(Vector3(tp.x, th + 5.5, tp.y), 3.0, 3.3, 11.0, Color(0.74, 0.70, 0.62, 0.0), 12)
			bld.cyl(Vector3(tp.x, th + 13.0, tp.y), 0.0, 3.8, 4.5, Color(0.22, 0.36, 0.62, 0.0), 12)
			_col_cyl(body, Vector3(tp.x, th + 5.5, tp.y), 3.3, 11.0)
		var gp := C + dir * (R + 3.0)
		bld.box(Vector3(gp.x, H + 8.2, gp.y), Vector3(19.0, 2.0, 2.8), wall_col.darkened(0.1), -g + PI * 0.5)

	# farolas en las avenidas
	for k in range(30, 104, 16):
		for sgn in [-1.0, 1.0]:
			for axis in 2:
				var off := Vector2(k * sgn, 7.5) if axis == 0 else Vector2(7.5, k * sgn)
				for side2 in [-1.0, 1.0]:
					var o2 := off * (Vector2(1, side2) if axis == 0 else Vector2(side2, 1))
					var lp := C + o2
					ground.cyl(Vector3(lp.x, H + 2.8, lp.y), 0.09, 0.13, 5.2, Color(0.15, 0.16, 0.18), 6)
					glow.sphere(Vector3(lp.x, H + 5.5, lp.y), 0.35, Color(1.0, 0.85, 0.55))
	_mi(ground.commit(), mat_vc, "CityGround", false)
	_mi(bld.commit(), mat_build, "CityBuildings")
	_mi(fol.commit(), mat_fol, "CityTrees")
	_mi(glow.commit(), _glow(Color(1.0, 0.82, 0.5)), "CityLamps", false)
	# luces cálidas en la plaza
	for a in 4:
		var lp2 := C + Vector2(cos(a * PI * 0.5 + 0.78), sin(a * PI * 0.5 + 0.78)) * 18.0
		_light(Vector3(lp2.x, H + 5.0, lp2.y), Color(1.0, 0.8, 0.5), 1.6, 22.0)

func _tree_simple(k: MeshKit, base: Vector3, s: float) -> void:
	k.cyl(base + Vector3(0, 1.6 * s, 0), 0.14 * s, 0.22 * s, 3.2 * s, Color(0.36, 0.25, 0.16, 0.0), 6)
	var g := Color(0.24, 0.45, 0.18, 1.0)
	k.sphere(base + Vector3(0, 4.0 * s, 0), 1.8 * s, g, Vector3(1, 0.85, 1), 8, 5)
	k.sphere(base + Vector3(0.8 * s, 3.4 * s, 0.4 * s), 1.2 * s, g.lightened(0.08), Vector3.ONE, 7, 4)
	k.sphere(base + Vector3(-0.7 * s, 3.5 * s, -0.5 * s), 1.2 * s, g.darkened(0.08), Vector3.ONE, 7, 4)

# =====================================================================
#  PUERTO MAREA — muelle, barcos, almacenes y faro con haz giratorio
# =====================================================================
func _port() -> void:
	var pl: Dictionary = w.places[1]
	var P: Vector2 = pl.pos
	var d: Vector2 = pl.dir
	var s := d.orthogonal()
	var rot := atan2(d.x, d.y)
	var k := MeshKit.new()
	var bld := MeshKit.new()
	var glow := MeshKit.new()
	var body := _body("PortBody")
	var deck_y := 2.0
	var wood := Color(0.52, 0.38, 0.24)
	# muelle principal
	var pier_c := P + d * 26.0
	k.box(Vector3(pier_c.x, deck_y, pier_c.y), Vector3(6.0, 0.5, 64.0), wood, rot)
	_col_box(body, Vector3(pier_c.x, deck_y, pier_c.y), Vector3(6.0, 0.5, 64.0), rot)
	var t_c := P + d * 56.0
	k.box(Vector3(t_c.x, deck_y, t_c.y), Vector3(26.0, 0.5, 5.0), wood, rot)
	_col_box(body, Vector3(t_c.x, deck_y, t_c.y), Vector3(26.0, 0.5, 5.0), rot)
	w.block_rect(pier_c, Vector2(8, 66), -rot)
	for i in range(-5, 60, 6):
		for sg in [-1.0, 1.0]:
			var pp: Vector2 = P + d * float(i) + s * 2.8 * sg
			k.cyl(Vector3(pp.x, -1.5, pp.y), 0.22, 0.25, 7.0, wood.darkened(0.3), 6)
	# barcos
	for b in 3:
		var bp := P + d * (18.0 + b * 15.0) + s * (6.5 if b % 2 == 0 else -6.5)
		var hull := Color(0.30, 0.20, 0.14) if b != 1 else Color(0.18, 0.30, 0.45)
		k.box(Vector3(bp.x, 0.6, bp.y), Vector3(3.2, 1.6, 9.0), hull, rot)
		k.prism(Vector3(bp.x + d.x * 5.2, 0.6, bp.y + d.y * 5.2), Vector3(3.2, 1.6, 1.6), hull, rot)
		k.box(Vector3(bp.x, 1.45, bp.y), Vector3(2.9, 0.15, 8.6), wood.lightened(0.15), rot)
		k.cyl(Vector3(bp.x, 5.2, bp.y), 0.1, 0.13, 7.5, wood.darkened(0.2), 6)
		k.box(Vector3(bp.x + d.x * 0.4, 5.6, bp.y + d.y * 0.4), Vector3(0.08, 4.8, 3.8), Color(0.95, 0.93, 0.86), rot)
	# almacenes
	var cc: Vector2 = pl.center
	for sg in [-1.0, 1.0]:
		var wp: Vector2 = cc - d * 6.0 + s * 18.0 * sg
		var col := Color(0.62, 0.36, 0.26, 1.0) if sg < 0 else Color(0.56, 0.60, 0.64, 1.0)
		bld.box(Vector3(wp.x, 2.4 + 3.5, wp.y), Vector3(14, 7, 10), col, rot)
		k.prism(Vector3(wp.x, 2.4 + 8.2, wp.y), Vector3(14.6, 3.0, 10.6), Color(0.30, 0.22, 0.20), rot + PI * 0.5)
		_col_box(body, Vector3(wp.x, 2.4 + 3.5, wp.y), Vector3(14, 7, 10), rot)
		_fp(wp, Vector2(12, 12), Color(0.45, 0.30, 0.25))
		w.block_rect(wp, Vector2(16, 12), -rot)
	# cajas y barriles
	for i in 8:
		var cp := P + d * rng.randf_range(2.0, 40.0) + s * rng.randf_range(-2.0, 2.0)
		k.box(Vector3(cp.x, deck_y + 0.75, cp.y), Vector3(1.0, 1.0, 1.0), Color(0.62, 0.48, 0.30), rng.randf() * PI)
	# faro
	var lh := cc + s * 30.0 + d * 4.0
	var gy := w.height_at(lh.x, lh.y)
	for i in 6:
		var c2 := Color(0.92, 0.92, 0.92) if i % 2 == 0 else Color(0.80, 0.18, 0.16)
		k.cyl(Vector3(lh.x, gy + 1.6 + i * 3.0, lh.y), 2.6 - (i + 1) * 0.1, 2.6 - i * 0.1, 3.05, c2, 16)
	k.cyl(Vector3(lh.x, gy + 19.3, lh.y), 2.7, 2.7, 0.4, Color(0.2, 0.2, 0.22), 16)
	glow.cyl(Vector3(lh.x, gy + 21.0, lh.y), 1.4, 1.4, 3.0, Color(1, 0.9, 0.6), 12)
	k.cyl(Vector3(lh.x, gy + 23.4, lh.y), 0.0, 2.0, 2.0, Color(0.75, 0.15, 0.12), 16)
	_col_cyl(body, Vector3(lh.x, gy + 10.0, lh.y), 2.6, 20.0)
	w.block_circle(lh, 5.0)
	var pivot := Node3D.new()
	pivot.position = Vector3(lh.x, gy + 21.0, lh.y)
	add_child(pivot)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.9, 0.65)
	spot.light_energy = 6.0
	spot.spot_range = 140.0
	spot.spot_angle = 9.0
	spot.shadow_enabled = false
	pivot.add_child(spot)
	w.animated.append({"node": pivot, "axis": Vector3.UP, "speed": 0.7})
	_mi(k.commit(), mat_vc, "Port")
	_mi(bld.commit(), mat_build, "PortBuildings")
	_mi(glow.commit(), _glow(Color(1.0, 0.85, 0.5)), "LighthouseLamp", false)
	_sign(I18n.t("port"), Vector3(lh.x, gy + 30.0, lh.y), Color(0.6, 0.75, 1.0), 0.12, 380.0)

# =====================================================================
#  ALDEA BRISA — casitas con techos de dos aguas, pozo, molino y cultivos
# =====================================================================
func _village() -> void:
	var pl: Dictionary = w.places[6]
	var V: Vector2 = pl.pos
	var H: float = pl.h
	var k := MeshKit.new()
	var glow := MeshKit.new()
	var body := _body("VillageBody")
	var n := 9
	for i in n:
		var a := TAU * i / n + 0.3
		var r := 24.0 + (i % 3) * 6.0
		var hp := V + Vector2(cos(a), sin(a)) * r
		var rot := -a + PI * 0.5
		var gy := w.height_at(hp.x, hp.y)
		var wall: Color = [Color(0.92, 0.88, 0.78), Color(0.84, 0.74, 0.58), Color(0.78, 0.66, 0.50)][i % 3]
		var roof: Color = [Color(0.62, 0.22, 0.16), Color(0.42, 0.26, 0.18), Color(0.30, 0.40, 0.55)][i % 3]
		k.box(Vector3(hp.x, gy + 1.8, hp.y), Vector3(6.0, 3.6, 5.0), wall, rot)
		k.prism(Vector3(hp.x, gy + 4.8, hp.y), Vector3(6.8, 2.4, 5.6), roof, rot + PI * 0.5)
		var front := Vector2(-cos(a), -sin(a))
		var dp := hp + front * 2.52
		k.box(Vector3(dp.x, gy + 1.1, dp.y), Vector3(1.1, 2.2, 0.1), Color(0.30, 0.20, 0.12), rot)
		for sg in [-1.0, 1.0]:
			var wp: Vector2 = hp + front * 2.53 + front.orthogonal() * 1.8 * sg
			glow.box(Vector3(wp.x, gy + 2.0, wp.y), Vector3(0.9, 0.8, 0.08), Color(1.0, 0.8, 0.45), rot)
		var ch := hp + front.orthogonal() * 1.6
		k.box(Vector3(ch.x, gy + 5.6, ch.y), Vector3(0.7, 1.8, 0.7), Color(0.45, 0.40, 0.38))
		_col_box(body, Vector3(hp.x, gy + 1.8, hp.y), Vector3(6.0, 3.6, 5.0), rot)
		w.block_rect(hp, Vector2(8, 7), -rot)
		_fp(hp, Vector2(6, 6), roof.darkened(0.1))
	# pozo
	k.cyl(Vector3(V.x, H + 0.5, V.y), 1.6, 1.7, 1.0, Color(0.55, 0.53, 0.50), 14)
	for sg in [-1.0, 1.0]:
		k.box(Vector3(V.x + 1.4 * sg, H + 1.8, V.y), Vector3(0.2, 2.6, 0.2), Color(0.40, 0.28, 0.18))
	k.prism(Vector3(V.x, H + 3.5, V.y), Vector3(3.8, 1.2, 2.2), Color(0.55, 0.22, 0.15))
	_col_cyl(body, Vector3(V.x, H + 0.5, V.y), 1.7, 1.0)
	# molino
	var mp := V + Vector2(32, -26)
	var my := w.height_at(mp.x, mp.y)
	k.cyl(Vector3(mp.x, my + 6.5, mp.y), 1.8, 2.9, 13.0, Color(0.93, 0.91, 0.86), 12)
	k.cyl(Vector3(mp.x, my + 14.2, mp.y), 0.0, 2.4, 2.6, Color(0.50, 0.24, 0.16), 12)
	_col_cyl(body, Vector3(mp.x, my + 6.5, mp.y), 2.9, 13.0)
	w.block_circle(mp, 5.0)
	_fp(mp, Vector2(5, 5), Color(0.9, 0.9, 0.85))
	var hub := Node3D.new()
	var to_center := (V - mp).normalized()
	hub.position = Vector3(mp.x + to_center.x * 2.4, my + 12.5, mp.y + to_center.y * 2.4)
	hub.rotation.y = atan2(to_center.x, to_center.y)
	add_child(hub)
	var blades := MeshKit.new()
	for bi in 4:
		var ba := bi * PI * 0.5
		var bb := Basis(Vector3.FORWARD, ba)
		blades.add_prim(_boxm(Vector3(1.4, 9.0, 0.12)), Transform3D(bb, bb * Vector3(0, 4.6, 0)), Color(0.85, 0.80, 0.70))
	var bm := MeshInstance3D.new()
	bm.mesh = blades.commit()
	bm.material_override = mat_vc
	hub.add_child(bm)
	w.animated.append({"node": hub, "axis": Vector3.FORWARD, "speed": 0.9})
	# cultivos
	for f in 3:
		var fa := 2.4 + f * 0.75
		var fc := V + Vector2(cos(fa), sin(fa)) * 52.0
		var fy := w.height_at(fc.x, fc.y)
		var frot := -fa
		var crop: Color = [Color(0.42, 0.62, 0.22), Color(0.86, 0.72, 0.28), Color(0.30, 0.52, 0.20)][f]
		for row in 8:
			var o := (row - 3.5) * 1.6
			var rp := fc + Vector2(cos(fa + PI * 0.5), sin(fa + PI * 0.5)) * o
			k.box(Vector3(rp.x, fy + 0.18, rp.y), Vector3(18.0, 0.36, 0.7), crop, frot)
			k.box(Vector3(rp.x, fy + 0.05, rp.y), Vector3(18.0, 0.1, 1.5), Color(0.40, 0.28, 0.18), frot)
		w.block_rect(fc, Vector2(20, 14), -frot)
		_fp(fc, Vector2(16, 12), crop.darkened(0.15))
	_mi(k.commit(), mat_vc, "Village")
	_mi(glow.commit(), _glow(Color(1.0, 0.8, 0.45)), "VillageWindows", false)
	_sign(I18n.t("village"), Vector3(mp.x, my + 21.0, mp.y), Color(1.0, 0.8, 0.5), 0.11, 320.0)

func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

# =====================================================================
#  RUINAS DE VAEL — anillo de columnas rotas y cristal rúnico
# =====================================================================
func _ruins() -> void:
	var pl: Dictionary = w.places[5]
	var Ru: Vector2 = pl.pos
	var H: float = pl.h
	var k := MeshKit.new()
	var body := _body("RuinsBody")
	var stone := Color(0.72, 0.70, 0.64)
	k.cyl(Vector3(Ru.x, H + 0.2, Ru.y), 17.0, 18.0, 0.8, stone.darkened(0.15), 24)
	k.cyl(Vector3(Ru.x, H + 0.65, Ru.y), 13.0, 13.0, 0.3, stone.darkened(0.05), 24)
	_col_cyl(body, Vector3(Ru.x, H + 0.2, Ru.y), 18.0, 0.8)
	for i in 12:
		var a := TAU * i / 12.0
		var cp := Ru + Vector2(cos(a), sin(a)) * 14.0
		var broken := i % 3 == 1
		var ch := 8.0 if not broken else rng.randf_range(2.0, 5.0)
		var moss := stone.lerp(Color(0.40, 0.52, 0.30), rng.randf_range(0.0, 0.35))
		k.cyl(Vector3(cp.x, H + 0.6 + ch * 0.5, cp.y), 0.75, 0.85, ch, moss, 12)
		if not broken:
			k.box(Vector3(cp.x, H + 0.6 + ch + 0.3, cp.y), Vector3(2.0, 0.6, 2.0), stone, a)
		_col_cyl(body, Vector3(cp.x, H + 0.6 + ch * 0.5, cp.y), 0.85, ch)
	# dintel sobre la entrada
	var a0 := 0.0
	var e1 := Ru + Vector2(cos(a0 - 0.26), sin(a0 - 0.26)) * 14.0
	var e2 := Ru + Vector2(cos(a0 + 0.26), sin(a0 + 0.26)) * 14.0
	var em := (e1 + e2) * 0.5
	k.box(Vector3(em.x, H + 9.5, em.y), Vector3(1.6, 1.2, e1.distance_to(e2) + 2.0), stone, 0.0)
	# columnas caídas
	for i in 4:
		var fp := Ru + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
		if fp.distance_to(Ru) < 18.0:
			fp = Ru + (fp - Ru).normalized() * 21.0
		var fy := w.height_at(fp.x, fp.y)
		k.cyl(Vector3(fp.x, fy + 0.6, fp.y), 0.7, 0.75, rng.randf_range(3, 6), stone.darkened(0.1), 10, Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), PI * 0.5))
	# altar y cristal rúnico
	k.box(Vector3(Ru.x, H + 1.5, Ru.y), Vector3(3.0, 1.6, 2.0), stone.darkened(0.2))
	_col_box(body, Vector3(Ru.x, H + 1.5, Ru.y), Vector3(3.0, 1.6, 2.0))
	var cr := MeshKit.new()
	cr.sphere(Vector3(Ru.x, H + 4.2, Ru.y), 0.9, Color(0.75, 0.45, 1.0), Vector3(1, 2.0, 1), 4, 2)
	var crm := _mi(cr.commit(), _glow(Color(0.7, 0.4, 1.0)), "RuneCrystal", false)
	w.animated.append({"node": crm, "axis": Vector3.UP, "speed": 0.0})
	_light(Vector3(Ru.x, H + 4.5, Ru.y), Color(0.7, 0.4, 1.0), 2.2, 26.0)
	w.block_circle(Ru, 20.0)
	_fp(Ru, Vector2(30, 30), Color(0.62, 0.58, 0.66))
	_mi(k.commit(), mat_vc, "Ruins")
	_sign(I18n.t("ruins"), Vector3(Ru.x, H + 15.0, Ru.y), Color(0.85, 0.7, 1.0), 0.11, 320.0)

# =====================================================================
#  LAGO ESPEJO — muelle de madera, pabellón y faroles de piedra
# =====================================================================
func _lake_shrine() -> void:
	var L: Vector2 = World.P_LAKE
	var dir := (World.P_CITY - L).normalized()
	var shore := L + dir * (World.LAKE_R * 0.92)
	var k := MeshKit.new()
	var glow := MeshKit.new()
	var body := _body("LakeBody")
	var rot := atan2(dir.x, dir.y)
	var deck_c := shore - dir * 9.0
	k.box(Vector3(deck_c.x, 1.3, deck_c.y), Vector3(3.2, 0.35, 20.0), Color(0.50, 0.36, 0.22), rot)
	_col_box(body, Vector3(deck_c.x, 1.3, deck_c.y), Vector3(3.2, 0.35, 20.0), rot)
	var gz := shore - dir * 21.0
	k.cyl(Vector3(gz.x, 1.25, gz.y), 4.6, 4.6, 0.4, Color(0.50, 0.36, 0.22), 8)
	_col_cyl(body, Vector3(gz.x, 1.25, gz.y), 4.6, 0.4)
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25
		var pp := gz + Vector2(cos(a), sin(a)) * 3.6
		k.cyl(Vector3(pp.x, 3.2, pp.y), 0.15, 0.18, 3.8, Color(0.62, 0.14, 0.12), 8)
	k.cyl(Vector3(gz.x, 5.9, gz.y), 0.0, 5.6, 2.4, Color(0.20, 0.24, 0.30), 4, Basis(Vector3.UP, PI * 0.25))
	for i in 4:
		var lp := shore - dir * (2.0 + i * 5.0) + dir.orthogonal() * 2.3 * (1.0 if i % 2 == 0 else -1.0)
		k.box(Vector3(lp.x, 1.9, lp.y), Vector3(0.5, 1.0, 0.5), Color(0.6, 0.6, 0.58))
		glow.box(Vector3(lp.x, 2.6, lp.y), Vector3(0.45, 0.4, 0.45), Color(1.0, 0.75, 0.4))
	_mi(k.commit(), mat_vc, "LakeShrine")
	_mi(glow.commit(), _glow(Color(1.0, 0.75, 0.4)), "LakeLanterns", false)
	_sign(I18n.t("lake"), Vector3(gz.x, 12.0, gz.y), Color(0.6, 0.85, 1.0), 0.11, 320.0)

# =====================================================================
#  PICO ESCARCHA — faro de llama azul en la cima
# =====================================================================
func _mountain_beacon() -> void:
	var M: Vector2 = World.P_MOUNTAIN
	var best := M
	var bh := -999.0
	for i in range(-6, 7):
		for j in range(-6, 7):
			var p := M + Vector2(i, j) * 4.0
			var h := w.height_at(p.x, p.y)
			if h > bh:
				bh = h
				best = p
	var k := MeshKit.new()
	for i in 6:
		k.sphere(Vector3(best.x + rng.randf_range(-2.5, 2.5), bh + 0.4, best.y + rng.randf_range(-2.5, 2.5)), rng.randf_range(0.6, 1.2), Color(0.55, 0.55, 0.58), Vector3(1, 0.7, 1), 6, 4)
	k.cyl(Vector3(best.x, bh + 2.5, best.y), 0.6, 0.9, 5.0, Color(0.50, 0.50, 0.55), 8)
	k.cyl(Vector3(best.x, bh + 5.2, best.y), 1.2, 0.8, 0.6, Color(0.40, 0.40, 0.45), 8)
	var fl := MeshKit.new()
	fl.sphere(Vector3(best.x, bh + 6.4, best.y), 0.9, Color(0.4, 0.75, 1.0), Vector3(1, 1.6, 1), 8, 5)
	_mi(k.commit(), mat_vc, "Summit")
	_mi(fl.commit(), _glow(Color(0.35, 0.7, 1.0)), "BlueFlame", false)
	_light(Vector3(best.x, bh + 6.5, best.y), Color(0.4, 0.7, 1.0), 3.0, 40.0)
	w.places[3].pos = best
	_sign(I18n.t("mountain"), Vector3(best.x, bh + 14.0, best.y), Color(0.85, 0.95, 1.0), 0.13, 600.0)

# =====================================================================
#  BOSQUE LUMEN — árbol ancestral gigante y hongos luminosos
# =====================================================================
func _giant_tree() -> void:
	var F: Vector2 = World.P_FOREST
	var gy := w.height_at(F.x, F.y)
	var k := MeshKit.new()
	var bark := Color(0.34, 0.24, 0.17, 0.0)
	k.cyl(Vector3(F.x, gy + 13.0, F.y), 1.6, 3.2, 26.0, bark, 12)
	for i in 6:
		var a := TAU * i / 6.0
		var rp := Vector2(F.x, F.y) + Vector2(cos(a), sin(a)) * 3.2
		k.cyl(Vector3(rp.x, gy + 0.8, rp.y), 0.4, 0.9, 5.0, bark, 6, Basis(Vector3(-sin(a), 0, cos(a)), 1.0))
	var leaf := Color(0.16, 0.38, 0.16, 1.0)
	var blobs := [Vector3(0, 30, 0), Vector3(6, 27, 2), Vector3(-6, 27, -2), Vector3(2, 27, -6), Vector3(-2, 28, 6), Vector3(0, 34, 0)]
	for b in blobs:
		k.sphere(Vector3(F.x, gy, F.y) + b, rng.randf_range(6.0, 8.0), leaf.lerp(Color(0.25, 0.5, 0.2, 1.0), rng.randf()), Vector3(1, 0.75, 1), 10, 6)
	_mi(k.commit(), mat_fol, "AncientTree")
	var body := _body("AncientTreeBody")
	_col_cyl(body, Vector3(F.x, gy + 13.0, F.y), 3.0, 26.0)
	w.block_circle(F, 8.0)
	var mush := MeshKit.new()
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, 22.0)
		var mp := F + Vector2(cos(a), sin(a)) * r
		var my := w.height_at(mp.x, mp.y)
		var c := Color(0.3, 0.95, 1.0) if i % 3 else Color(1.0, 0.45, 0.85)
		mush.sphere(Vector3(mp.x, my + 0.35, mp.y), 0.35, c, Vector3(1, 0.5, 1), 8, 4)
	_mi(mush.commit(), _glow(Color(0.4, 0.95, 1.0)), "GlowMushrooms", false)
	_light(Vector3(F.x, gy + 4.0, F.y), Color(0.4, 1.0, 0.8), 1.5, 30.0)
	_sign(I18n.t("forest"), Vector3(F.x, gy + 42.0, F.y), Color(0.6, 1.0, 0.7), 0.13, 420.0)
