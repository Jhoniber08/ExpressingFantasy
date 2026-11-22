class_name World
extends Node3D
## Mundo de Expressing Fantasy: isla de 1 km², terreno, agua, cielo, lugares, caminos y ciclo día/noche.

signal progress(pct: float, line: String)

const RES := 257            # vértices por lado
const STEP := 4.0           # metros entre vértices
const HALF := 512.0         # la isla va de -512 a 512 m
const CH := 32              # cuadros por trozo de terreno
const GRID2 := 512          # cuadrícula fina de 2 m (mapa y ocupación)
const DAY_LENGTH := 720.0   # segundos por día completo

var heights := PackedFloat32Array()
var colors := PackedColorArray()
var grass_map := PackedByteArray()     # 0..255 aptitud de pasto (rejilla RES)
var blocked := PackedByteArray()       # rejilla de 2 m: 1 = ocupado (calles, casas...)
var places: Array = []                 # diccionarios de lugares
var roads := RoadNet.new()
var road_pts: Array = []               # PackedVector3Array por camino (para la malla)
var footprints: Array = []             # Rect2 de edificios (para el mapa)
var map_image: Image
var map_texture: ImageTexture

var time_of_day := 0.30                # 0 medianoche · 0.25 amanecer · 0.5 mediodía
var night := 0.0
var animated: Array = []               # nodos con animación simple (molino, faro)
var glow_mats: Array = []              # materiales que brillan de noche

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var cine_cam: Camera3D
var _sky_timer := 0.0
var _cine_t := 0.0

var n_base := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_shape := FastNoiseLite.new()
var n_ridge := FastNoiseLite.new()
var n_color := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

# posiciones fijas de los lugares (x, z)
const P_CITY := Vector2(10, 40)
const P_FOREST := Vector2(-270, -50)
const P_MOUNTAIN := Vector2(235, -235)
const P_LAKE := Vector2(-150, -265)
const P_RUINS := Vector2(285, 165)
const P_VILLAGE := Vector2(-255, 245)
const CITY_R := 112.0
const LAKE_R := 72.0

func _init() -> void:
	rng.seed = 20261122
	n_base.seed = 1101; n_base.frequency = 0.0042; n_base.fractal_octaves = 5
	n_detail.seed = 2202; n_detail.frequency = 0.03; n_detail.fractal_octaves = 2
	n_shape.seed = 3303; n_shape.frequency = 0.9; n_shape.fractal_octaves = 3
	n_ridge.seed = 4404; n_ridge.frequency = 0.011; n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED; n_ridge.fractal_octaves = 4
	n_color.seed = 5505; n_color.frequency = 0.02; n_color.fractal_octaves = 3

# =====================================================================
#  CONSTRUCCIÓN (por pasos, para mostrar el progreso en la pantalla de inicio)
# =====================================================================
func build() -> void:
	_step(0.02, "Inicializando motor Godot %s · renderizador %s" % [Engine.get_version_info().string, _renderer_name()])
	await get_tree().process_frame
	_setup_environment()
	_step(0.06, "Cielo procedural · luna neón · %d estrellas" % 9000)
	await get_tree().process_frame
	_gen_heights()
	_step(0.22, "Terreno %d × %d m generado (%d vértices)" % [int(HALF * 2), int(HALF * 2), RES * RES])
	await get_tree().process_frame
	_define_places_and_roads()
	_step(0.30, "%d lugares y %d caminos trazados" % [places.size(), road_pts.size()])
	await get_tree().process_frame
	_apply_flatten_and_colors()
	_build_terrain_mesh()
	_build_collision()
	_step(0.42, "Malla del terreno en %d trozos · física lista" % [(RES - 1) / CH * (RES - 1) / CH])
	await get_tree().process_frame
	_build_water()
	var pl := Places.new()
	add_child(pl)
	await pl.build(self)
	_step(0.62, "Ciudad, puerto, aldea, ruinas y santuario construidos (%d edificios)" % footprints.size())
	await get_tree().process_frame
	_build_road_meshes()
	_build_nav()
	_step(0.68, "Red de rutas GPS: %d nodos" % roads.astar.get_point_count())
	await get_tree().process_frame
	var veg := Vegetation.new()
	add_child(veg)
	await veg.build(self)
	_step(0.92, "Vegetación: %s árboles · %s matas de pasto" % [_fmt(veg.tree_count), _fmt(veg.grass_count)])
	await get_tree().process_frame
	_build_map_image()
	_step(0.97, "Mapa del mundo renderizado (%d × %d px)" % [GRID2, GRID2])
	await get_tree().process_frame
	_setup_cinematic()
	_update_sky(true)
	_step(1.0, "Mundo listo.")

func _step(p: float, line: String) -> void:
	progress.emit(p, line)

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

func _renderer_name() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))

# =====================================================================
#  TERRENO
# =====================================================================
func idx(i: int, j: int) -> int:
	return j * RES + i

func grid_to_world(i: int, j: int) -> Vector2:
	return Vector2(-HALF + i * STEP, -HALF + j * STEP)

func raw_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var ang := atan2(z, x)
	var R := 410.0 + 42.0 * n_shape.get_noise_2d(cos(ang) * 3.0, sin(ang) * 3.0)
	var mask := smoothstep(R + 30.0, R - 140.0, r)
	var b := n_base.get_noise_2d(x, z) * 0.5 + 0.5
	var land := 2.5 + b * 30.0 + n_detail.get_noise_2d(x, z) * 1.6
	var dm := Vector2(x, z).distance_to(P_MOUNTAIN)
	land += 140.0 * exp(-dm * dm / (2.0 * 88.0 * 88.0)) * (0.7 + 0.3 * (n_ridge.get_noise_2d(x, z) * 0.5 + 0.5))
	land += 18.0 * exp(-dm * dm / (2.0 * 170.0 * 170.0))
	return lerpf(-16.0, land, mask)

func _gen_heights() -> void:
	heights.resize(RES * RES)
	for j in RES:
		for i in RES:
			var p := grid_to_world(i, j)
			heights[idx(i, j)] = raw_height(p.x, p.y)

## Altura interpolada en cualquier punto (x, z)
func height_at(x: float, z: float) -> float:
	var fx := (x + HALF) / STEP
	var fz := (z + HALF) / STEP
	var i := clampi(int(floor(fx)), 0, RES - 2)
	var j := clampi(int(floor(fz)), 0, RES - 2)
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var h00 := heights[idx(i, j)]
	var h10 := heights[idx(i + 1, j)]
	var h01 := heights[idx(i, j + 1)]
	var h11 := heights[idx(i + 1, j + 1)]
	# misma triangulación que la malla
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := STEP
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func place_at(x: float, z: float) -> Dictionary:
	for p in places:
		if Vector2(x, z).distance_to(p.pos) < p.radius:
			return p
	return {}

# =====================================================================
#  LUGARES Y CAMINOS
# =====================================================================
func _shore_point(from: Vector2, dir: Vector2) -> Vector2:
	var p := from
	for k in 300:
		p += dir * 3.0
		if raw_height(p.x, p.y) < 0.6:
			return p
	return p

func _define_places_and_roads() -> void:
	var city_h := maxf(raw_height(P_CITY.x, P_CITY.y), 7.0)
	var port_dir := Vector2(0.15, 1.0).normalized()
	var shore := _shore_point(P_CITY + port_dir * 130.0, port_dir)
	var ruins_h := maxf(raw_height(P_RUINS.x, P_RUINS.y), 4.0)
	var vil_h := maxf(raw_height(P_VILLAGE.x, P_VILLAGE.y), 4.0)
	var peak_h := raw_height(P_MOUNTAIN.x, P_MOUNTAIN.y)
	places = [
		{"id": "city", "pos": P_CITY, "radius": CITY_R + 8.0, "flat": CITY_R + 4.0, "h": city_h, "icon": "city", "color": Color("#3fd7ff")},
		{"id": "port", "pos": shore, "radius": 70.0, "flat": 46.0, "h": 2.4, "icon": "port", "color": Color("#4f8bff"), "dir": port_dir, "center": shore - port_dir * 22.0},
		{"id": "forest", "pos": P_FOREST, "radius": 135.0, "flat": 0.0, "h": 0.0, "icon": "forest", "color": Color("#4ccf6a")},
		{"id": "mountain", "pos": P_MOUNTAIN, "radius": 120.0, "flat": 0.0, "h": peak_h, "icon": "mountain", "color": Color("#c9e6ff")},
		{"id": "lake", "pos": P_LAKE, "radius": LAKE_R + 20.0, "flat": 0.0, "h": -5.0, "icon": "lake", "color": Color("#58c4ff")},
		{"id": "ruins", "pos": P_RUINS, "radius": 55.0, "flat": 40.0, "h": ruins_h, "icon": "ruins", "color": Color("#c69cff")},
		{"id": "village", "pos": P_VILLAGE, "radius": 75.0, "flat": 62.0, "h": vil_h, "icon": "village", "color": Color("#ffb347")},
	]

	# puertas de la ciudad: N, S, E, O
	var gates := {
		"N": P_CITY + Vector2(0, -CITY_R), "S": P_CITY + Vector2(0, CITY_R),
		"E": P_CITY + Vector2(CITY_R, 0), "W": P_CITY + Vector2(-CITY_R, 0)}
	var targets := {
		"port": [gates["S"], shore - port_dir * 30.0],
		"forest": [gates["W"], P_FOREST + Vector2(60, 10)],
		"mountain": [gates["E"], P_MOUNTAIN + (P_CITY - P_MOUNTAIN).normalized() * 150.0],
		"lake": [gates["N"], P_LAKE + (P_CITY - P_LAKE).normalized() * (LAKE_R + 14.0)],
		"ruins": [gates["E"], P_RUINS + Vector2(-30, 0)],
		"village": [gates["W"], P_VILLAGE + Vector2(40, -30)],
	}
	road_pts.clear()
	for k in targets:
		road_pts.append(_make_road_2d(targets[k][0], targets[k][1], hash(k)))
	# camino costero entre aldea y bosque, y entre ruinas y puerto
	road_pts.append(_make_road_2d(P_VILLAGE + Vector2(20, -50), P_FOREST + Vector2(30, 70), 77))
	road_pts.append(_make_road_2d(P_RUINS + Vector2(-20, 30), shore + Vector2(40, -30), 91))

func _make_road_2d(a: Vector2, b: Vector2, seed_v: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := a.distance_to(b)
	var n := maxi(int(d / 6.0), 2)
	var perp := (b - a).normalized().orthogonal()
	var amp := minf(d * 0.08, 28.0)
	var ph := float(seed_v % 100) * 0.13
	for k in n + 1:
		var t := float(k) / n
		var p := a.lerp(b, t)
		var w := sin(t * PI) * (sin(t * 6.0 + ph) * 0.7 + sin(t * 13.0 + ph * 2.0) * 0.3)
		pts.append(p + perp * w * amp)
	return pts

func _apply_flatten_and_colors() -> void:
	# 1) aplanar lugares y excavar el lago
	for j in RES:
		for i in RES:
			var p := grid_to_world(i, j)
			var k := idx(i, j)
			var h := heights[k]
			for pl in places:
				var c: Vector2 = pl.get("center", pl.pos)
				var d := p.distance_to(c)
				if pl.flat > 0.0 and d < pl.flat + 40.0:
					h = lerpf(h, pl.h, smoothstep(pl.flat + 40.0, pl.flat, d))
			var dl := p.distance_to(P_LAKE)
			if dl < LAKE_R + 30.0:
				h = lerpf(h, -5.5, smoothstep(LAKE_R + 30.0, LAKE_R * 0.6, dl))
			heights[k] = h
	# 2) caminos: altura suavizada y aplanado debajo
	var smoothed: Array = []
	for r2 in road_pts:
		var hs := PackedFloat32Array()
		for p in r2:
			hs.append(maxf(height_at(p.x, p.y), 1.6))
		var hs2 := hs.duplicate()
		for i in hs.size():
			var s := 0.0
			var c := 0
			for o in range(-4, 5):
				var q := clampi(i + o, 0, hs.size() - 1)
				s += hs[q]
				c += 1
			hs2[i] = s / c
		var p3 := PackedVector3Array()
		for i in r2.size():
			p3.append(Vector3(r2[i].x, hs2[i], r2[i].y))
		smoothed.append(p3)
		_flatten_along(p3, 4.0, 6.0)
	road_pts = smoothed
	# 3) colores y aptitud de pasto
	colors.resize(RES * RES)
	grass_map.resize(RES * RES)
	for j in RES:
		for i in RES:
			var p := grid_to_world(i, j)
			var k := idx(i, j)
			var h := heights[k]
			var nrm := _grid_normal(i, j)
			var nc := n_color.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var c := Color(0.33, 0.50, 0.22, 0.0)
			var g := 1.0
			var df := p.distance_to(P_FOREST)
			if h < 0.2:
				c = Color(0.62, 0.56, 0.40, 1.0).lerp(Color(0.40, 0.42, 0.36, 1.0), clampf(-h / 10.0, 0.0, 1.0)); g = 0.0
			elif h < 2.1:
				c = Color(0.86, 0.79, 0.60, 1.0); g = 0.0
			else:
				var dry := Color(0.52, 0.55, 0.28, 0.0)
				var lush := Color(0.27, 0.47, 0.19, 0.0)
				c = lush.lerp(dry, clampf(nc * 1.3 - 0.25, 0.0, 1.0))
				if df < 150.0:
					c = c.lerp(Color(0.17, 0.34, 0.13, 0.0), smoothstep(150.0, 70.0, df))
				if h > 55.0:
					c = c.lerp(Color(0.45, 0.43, 0.38, 0.0), smoothstep(55.0, 85.0, h)); g *= 1.0 - smoothstep(50.0, 75.0, h)
				if h > 98.0:
					c = Color(0.93, 0.95, 1.0, 1.0).lerp(c, 1.0 - smoothstep(98.0, 108.0, h)); g = 0.0
				if nrm.y < 0.78:
					g *= 0.2
			var dc := p.distance_to(P_CITY)
			if dc < CITY_R + 2.0:
				c = Color(0.56, 0.54, 0.50, 1.0); g = 0.0
			grass_map[k] = int(clampf(g, 0.0, 1.0) * 255.0)
			colors[k] = c
	# tierra de los caminos en la textura del terreno
	for r3 in road_pts:
		_paint_along(r3, 3.5, Color(0.50, 0.42, 0.30, 1.0))

func _grid_normal(i: int, j: int) -> Vector3:
	var hl := heights[idx(maxi(i - 1, 0), j)]
	var hr := heights[idx(mini(i + 1, RES - 1), j)]
	var hd := heights[idx(i, maxi(j - 1, 0))]
	var hu := heights[idx(i, mini(j + 1, RES - 1))]
	return Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()

func _flatten_along(pts: PackedVector3Array, w: float, blend: float) -> void:
	for s in pts.size() - 1:
		var a := pts[s]
		var b := pts[s + 1]
		var mn := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * (w + blend)
		var mx := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * (w + blend)
		var i0 := clampi(int((mn.x + HALF) / STEP), 0, RES - 1)
		var i1 := clampi(int((mx.x + HALF) / STEP) + 1, 0, RES - 1)
		var j0 := clampi(int((mn.y + HALF) / STEP), 0, RES - 1)
		var j1 := clampi(int((mx.y + HALF) / STEP) + 1, 0, RES - 1)
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l2 := maxf(ab.length_squared(), 0.001)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := grid_to_world(i, j)
				var t := clampf((p - Vector2(a.x, a.z)).dot(ab) / l2, 0.0, 1.0)
				var q := Vector2(a.x, a.z) + ab * t
				var d := p.distance_to(q)
				if d < w + blend:
					var target := lerpf(a.y, b.y, t) - 0.25
					var k := idx(i, j)
					heights[k] = lerpf(heights[k], target, smoothstep(w + blend, w, d))

func _paint_along(pts: PackedVector3Array, w: float, c: Color) -> void:
	for s in range(0, pts.size() - 1):
		var a := Vector2(pts[s].x, pts[s].z)
		var b := Vector2(pts[s + 1].x, pts[s + 1].z)
		var i0 := clampi(int((minf(a.x, b.x) - w + HALF) / STEP), 0, RES - 1)
		var i1 := clampi(int((maxf(a.x, b.x) + w + HALF) / STEP) + 1, 0, RES - 1)
		var j0 := clampi(int((minf(a.y, b.y) - w + HALF) / STEP), 0, RES - 1)
		var j1 := clampi(int((maxf(a.y, b.y) + w + HALF) / STEP) + 1, 0, RES - 1)
		var ab := b - a
		var l2 := maxf(ab.length_squared(), 0.001)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := grid_to_world(i, j)
				var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
				if p.distance_to(a + ab * t) < w:
					colors[idx(i, j)] = c
					grass_map[idx(i, j)] = 0

func _build_terrain_mesh() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var chunks := (RES - 1) / CH
	for cj in chunks:
		for ci in chunks:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var ind := PackedInt32Array()
			var any_land := false
			for j in CH + 1:
				for i in CH + 1:
					var gi := ci * CH + i
					var gj := cj * CH + j
					var p := grid_to_world(gi, gj)
					var h := heights[idx(gi, gj)]
					if h > -3.0:
						any_land = true
					verts.append(Vector3(p.x, h, p.y))
					norms.append(_grid_normal(gi, gj))
					cols.append(colors[idx(gi, gj)])
			if not any_land:
				continue
			for j in CH:
				for i in CH:
					var a := j * (CH + 1) + i
					var b := a + 1
					var c := a + CH + 1
					var d := c + 1
					ind.append_array(PackedInt32Array([a, b, c, b, d, c]))
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = ind
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.name = "Terrain_%d_%d" % [ci, cj]
			add_child(mi)

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := HeightMapShape3D.new()
	shape.map_width = RES
	shape.map_depth = RES
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(cs)
	add_child(body)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600, 2600)
	plane.subdivide_width = 90
	plane.subdivide_depth = 90
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.0
	mi.name = "Ocean"
	add_child(mi)

func _build_road_meshes() -> void:
	var kit := MeshKit.new()
	for r in road_pts:
		var pts := PackedVector3Array()
		for p in r:
			pts.append(Vector3(p.x, maxf(height_at(p.x, p.z), p.y - 0.1) + 0.14, p.z))
		kit.ribbon(pts, 5.2, Color(0.56, 0.47, 0.34), Color(0.42, 0.36, 0.26))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = MeshKit.vc_material(0.95)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Roads"
	add_child(mi)

func _build_nav() -> void:
	for r in road_pts:
		roads.add_polyline(r, 12.0)
	# avenidas de la ciudad: puertas ↔ plaza
	var c3 := Vector3(P_CITY.x, places[0].h + 0.2, P_CITY.y)
	for g in [Vector2(0, -CITY_R), Vector2(0, CITY_R), Vector2(CITY_R, 0), Vector2(-CITY_R, 0)]:
		var line := PackedVector3Array()
		for k in 9:
			var p: Vector2 = P_CITY + g * (float(k) / 8.0)
			line.append(Vector3(p.x, places[0].h + 0.2, p.y))
		roads.add_polyline(line, 14.0)
	# calles transversales
	for off in [-72.0, -36.0, 36.0, 72.0]:
		var span := sqrt(maxf(104.0 * 104.0 - off * off, 0.0))
		for horizontal in [true, false]:
			var line2 := PackedVector3Array()
			for k in 7:
				var t := lerpf(-span, span, float(k) / 6.0)
				var p2 := P_CITY + (Vector2(t, off) if horizontal else Vector2(off, t))
				line2.append(Vector3(p2.x, c3.y, p2.y))
			roads.add_polyline(line2, 12.0)
	roads.finalize(9.0)

# =====================================================================
#  OCUPACIÓN (rejilla de 2 m) — evita árboles sobre calles y casas
# =====================================================================
func block_rect(center: Vector2, size: Vector2, rot := 0.0) -> void:
	if blocked.is_empty():
		blocked.resize(GRID2 * GRID2)
	var r := size.length() * 0.5
	var c := cos(-rot)
	var s := sin(-rot)
	for gz in range(int((center.y - r + HALF) / 2.0), int((center.y + r + HALF) / 2.0) + 1):
		for gx in range(int((center.x - r + HALF) / 2.0), int((center.x + r + HALF) / 2.0) + 1):
			if gx < 0 or gz < 0 or gx >= GRID2 or gz >= GRID2:
				continue
			var p := Vector2(-HALF + gx * 2.0 + 1.0, -HALF + gz * 2.0 + 1.0) - center
			var q := Vector2(c * p.x - s * p.y, s * p.x + c * p.y)
			if absf(q.x) <= size.x * 0.5 + 1.0 and absf(q.y) <= size.y * 0.5 + 1.0:
				blocked[gz * GRID2 + gx] = 1

func block_circle(center: Vector2, r: float) -> void:
	if blocked.is_empty():
		blocked.resize(GRID2 * GRID2)
	for gz in range(int((center.y - r + HALF) / 2.0), int((center.y + r + HALF) / 2.0) + 1):
		for gx in range(int((center.x - r + HALF) / 2.0), int((center.x + r + HALF) / 2.0) + 1):
			if gx < 0 or gz < 0 or gx >= GRID2 or gz >= GRID2:
				continue
			var p := Vector2(-HALF + gx * 2.0 + 1.0, -HALF + gz * 2.0 + 1.0)
			if p.distance_to(center) <= r:
				blocked[gz * GRID2 + gx] = 1

func is_blocked(x: float, z: float) -> bool:
	if blocked.is_empty():
		return false
	var gx := int((x + HALF) / 2.0)
	var gz := int((z + HALF) / 2.0)
	if gx < 0 or gz < 0 or gx >= GRID2 or gz >= GRID2:
		return true
	return blocked[gz * GRID2 + gx] == 1

func near_road(x: float, z: float, w: float) -> bool:
	for r in road_pts:
		for k in range(0, r.size(), 2):
			var p: Vector3 = r[k]
			if absf(p.x - x) < w + 6.0 and absf(p.z - z) < w + 6.0:
				if Vector2(p.x, p.z).distance_to(Vector2(x, z)) < w + 3.0:
					return true
	return false

# =====================================================================
#  MAPA (imagen 512×512 con relieve, agua, caminos y edificios)
# =====================================================================
func _build_map_image() -> void:
	map_image = Image.create_empty(GRID2, GRID2, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.6, 0.8, -0.4).normalized()
	for gz in GRID2:
		for gx in GRID2:
			var x := -HALF + gx * 2.0 + 1.0
			var z := -HALF + gz * 2.0 + 1.0
			var h := height_at(x, z)
			var c: Color
			if h < 0.0:
				var deep := clampf(-h / 16.0, 0.0, 1.0)
				c = Color(0.10, 0.42, 0.58).lerp(Color(0.03, 0.14, 0.27), deep)
				if Vector2(x, z).distance_to(P_LAKE) < LAKE_R + 25.0:
					c = Color(0.14, 0.50, 0.66).lerp(Color(0.08, 0.30, 0.48), deep)
			else:
				var fi := clampi(int((x + HALF) / STEP), 0, RES - 1)
				var fj := clampi(int((z + HALF) / STEP), 0, RES - 1)
				c = colors[idx(fi, fj)]
				c.a = 1.0
				var n := normal_at(x, z)
				var shade := clampf(n.dot(light) * 1.25, 0.45, 1.25)
				c = Color(c.r * shade, c.g * shade, c.b * shade)
				if h < 1.0:
					c = c.lerp(Color(0.95, 0.9, 0.7), 0.3)
			map_image.set_pixel(gx, gz, c)
	# calles de la ciudad (más claras) y edificios (bloques oscuros)
	var city_street := Color(0.80, 0.80, 0.78)
	for gz in GRID2:
		for gx in GRID2:
			var x := -HALF + gx * 2.0 + 1.0
			var z := -HALF + gz * 2.0 + 1.0
			var lp := Vector2(x, z) - P_CITY
			if lp.length() < CITY_R - 4.0:
				for off in [-72.0, -36.0, 0.0, 36.0, 72.0]:
					var w := 6.0 if off == 0.0 else 4.0
					if absf(lp.x - off) < w or absf(lp.y - off) < w:
						map_image.set_pixel(gx, gz, city_street)
				if lp.length() < 26.0:
					map_image.set_pixel(gx, gz, Color(0.88, 0.86, 0.80))
			elif absf(lp.length() - (CITY_R + 2.0)) < 2.0:
				map_image.set_pixel(gx, gz, Color(0.35, 0.33, 0.32))
	for fp in footprints:
		var rc: Rect2 = fp.rect
		var col: Color = fp.color
		for gz in range(int((rc.position.y + HALF) / 2.0), int((rc.end.y + HALF) / 2.0) + 1):
			for gx in range(int((rc.position.x + HALF) / 2.0), int((rc.end.x + HALF) / 2.0) + 1):
				if gx >= 0 and gz >= 0 and gx < GRID2 and gz < GRID2:
					map_image.set_pixel(gx, gz, col)
	# caminos
	for r in road_pts:
		for k in r.size():
			var p: Vector3 = r[k]
			var gx := int((p.x + HALF) / 2.0)
			var gz := int((p.z + HALF) / 2.0)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var px := gx + ox
					var py := gz + oy
					if px >= 0 and py >= 0 and px < GRID2 and py < GRID2:
						map_image.set_pixel(px, py, Color(0.93, 0.86, 0.66) if (ox == 0 and oy == 0) else Color(0.72, 0.62, 0.44))
	map_texture = ImageTexture.create_from_image(map_image)

func world_to_uv(x: float, z: float) -> Vector2:
	return Vector2((x + HALF) / (HALF * 2.0), (z + HALF) / (HALF * 2.0))

# =====================================================================
#  CIELO, LUZ Y CICLO DÍA/NOCHE
# =====================================================================
func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.glow_enabled = Settings.glow()
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.96
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = Settings.shadows()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = Settings.shadow_distance()
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.75, 1.0)
	moon.shadow_enabled = false
	add_child(moon)

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / DAY_LENGTH, 1.0)
	var ang := (time_of_day - 0.25) * TAU          # 0.25 amanecer, 0.5 mediodía
	var sun_dir := Vector3(cos(ang) * 0.85, sin(ang), 0.35 * cos(ang * 0.5)).normalized()
	var moon_dir := Vector3(-sun_dir.x, -sun_dir.y, sun_dir.z * 0.4 + 0.25).normalized()
	var day := smoothstep(-0.12, 0.18, sun_dir.y)
	var dusk := (1.0 - absf(day * 2.0 - 1.0)) * smoothstep(-0.25, 0.05, sun_dir.y)
	night = 1.0 - day
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
	sun.light_energy = 1.0 * day
	sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.62, 0.38), dusk)
	sun.visible = day > 0.01
	moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP if absf(moon_dir.y) < 0.99 else Vector3.FORWARD)
	moon.light_energy = 0.32 * night
	moon.visible = night > 0.05
	env.ambient_light_color = Color(0.10, 0.13, 0.26).lerp(Color(0.55, 0.62, 0.74), day).lerp(Color(0.85, 0.55, 0.45), dusk * 0.4)
	env.ambient_light_energy = lerpf(0.45, 0.42, day)
	env.fog_light_color = Color(0.05, 0.07, 0.15).lerp(Color(0.68, 0.78, 0.9), day).lerp(Color(0.95, 0.6, 0.45), dusk * 0.6)
	RenderingServer.global_shader_parameter_set("night", night)
	for m in glow_mats:
		m.emission_energy_multiplier = lerpf(0.4, 3.0, night)
	_sky_timer -= delta
	if _sky_timer <= 0.0:
		_sky_timer = 1.0
		sky_mat.set_shader_parameter("sun_dir", sun_dir)
		sky_mat.set_shader_parameter("moon_dir", moon_dir)
		sky_mat.set_shader_parameter("day", day)
		sky_mat.set_shader_parameter("dusk", dusk)
	for a in animated:
		if is_instance_valid(a.node):
			a.node.rotate_object_local(a.axis, a.speed * delta)
	if cine_cam and cine_cam.current:
		_cine_t += delta * 0.035
		var c := Vector3(P_CITY.x, places[0].h, P_CITY.y)
		var pos := c + Vector3(cos(_cine_t) * 250.0, 95.0 + sin(_cine_t * 0.7) * 25.0, sin(_cine_t) * 250.0)
		cine_cam.look_at_from_position(pos, c + Vector3(0, 25, 0))

func _update_sky(_force := false) -> void:
	_sky_timer = 0.0

func _setup_cinematic() -> void:
	cine_cam = Camera3D.new()
	cine_cam.fov = 62.0
	cine_cam.far = Settings.far_clip()
	add_child(cine_cam)
	cine_cam.current = true

func zone_name_at(x: float, z: float) -> String:
	var p := place_at(x, z)
	if not p.is_empty():
		return I18n.t(p.id)
	if height_at(x, z) < -1.0:
		return I18n.t("sea")
	return I18n.t("wild")
