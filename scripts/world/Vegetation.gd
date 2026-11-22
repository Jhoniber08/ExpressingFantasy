class_name Vegetation
extends Node3D
## Pasto, flores, árboles, arbustos y rocas con MultiMesh (miles de copias en pocas llamadas de dibujo).
## El pasto ahora es equilibrado: manchas naturales, zonas despejadas y densidad según la calidad.

var w: World
var rng := RandomNumberGenerator.new()
var tree_count := 0
var grass_count := 0
var mat_grass: ShaderMaterial
var mat_fol: ShaderMaterial
var patch := FastNoiseLite.new()

const GRASS_CHUNK := 48.0
const TREE_CHUNK := 128.0

func build(world: World) -> void:
	w = world
	rng.seed = 4242
	patch.seed = 99
	patch.frequency = 0.035
	mat_grass = ShaderMaterial.new()
	mat_grass.shader = load("res://shaders/grass.gdshader")
	mat_fol = ShaderMaterial.new()
	mat_fol.shader = load("res://shaders/foliage.gdshader")
	_trees()
	await get_tree().process_frame
	_grass()

# =====================================================================
#  MALLAS BASE
# =====================================================================
func _grass_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var ind := PackedInt32Array()
	var blades := 7
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for b in blades:
		var a := r.randf() * TAU
		var off := Vector3(r.randf_range(-0.28, 0.28), 0, r.randf_range(-0.28, 0.28))
		var hgt := r.randf_range(0.45, 0.85)
		var wid := r.randf_range(0.05, 0.08)
		var dir := Vector3(cos(a), 0, sin(a))
		var bend := Vector3(-sin(a), 0, cos(a)) * r.randf_range(0.05, 0.18)
		var base := verts.size()
		verts.append(off - dir * wid); uvs.append(Vector2(0, 0))
		verts.append(off + dir * wid); uvs.append(Vector2(1, 0))
		verts.append(off - dir * wid * 0.6 + Vector3(0, hgt * 0.55, 0) + bend * 0.4); uvs.append(Vector2(0, 0.55))
		verts.append(off + dir * wid * 0.6 + Vector3(0, hgt * 0.55, 0) + bend * 0.4); uvs.append(Vector2(1, 0.55))
		verts.append(off + Vector3(0, hgt, 0) + bend); uvs.append(Vector2(0.5, 1))
		for k in 5:
			cols.append(Color.WHITE)
			norms.append(Vector3.UP)
		ind.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2, base + 2, base + 3, base + 4]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = ind
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _flower_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(Vector3(0, 0.2, 0), 0.012, 0.015, 0.4, Color(0.3, 0.5, 0.2, 0.0), 4)
	k.sphere(Vector3(0, 0.42, 0), 0.07, Color(1, 1, 1, 1.0), Vector3(1, 0.5, 1), 6, 3)
	return k.commit()

func _oak_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var bark := Color(0.36, 0.26, 0.17, 0.0)
	k.cyl(Vector3(0, 2.2, 0), 0.22, 0.38, 4.4, bark, 7)
	k.cyl(Vector3(0.5, 3.6, 0.1), 0.08, 0.14, 1.6, bark, 5, Basis(Vector3.BACK, -0.7))
	var g := Color(0.26, 0.45, 0.18, 1.0)
	k.sphere(Vector3(0, 5.6, 0), 2.4, g, Vector3(1, 0.8, 1), 9, 6)
	k.sphere(Vector3(1.4, 4.9, 0.6), 1.7, g.lightened(0.08), Vector3.ONE, 8, 5)
	k.sphere(Vector3(-1.3, 5.0, -0.7), 1.8, g.darkened(0.1), Vector3.ONE, 8, 5)
	k.sphere(Vector3(0.2, 6.7, -0.8), 1.5, g.lightened(0.04), Vector3.ONE, 8, 5)
	return k.commit()

func _pine_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(Vector3(0, 1.6, 0), 0.16, 0.3, 3.2, Color(0.34, 0.24, 0.16, 0.0), 6)
	var g := Color(0.16, 0.33, 0.20, 1.0)
	for i in 4:
		var y := 2.6 + i * 1.8
		var r := 2.5 - i * 0.55
		k.cyl(Vector3(0, y, 0), 0.0, r, 2.6, g.lightened(i * 0.04), 9)
	return k.commit()

func _palm_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var trunk := Color(0.55, 0.43, 0.30, 0.0)
	var top := Vector3.ZERO
	for i in 6:
		var y := i * 1.2
		var x := pow(i / 6.0, 2.0) * 1.2
		k.cyl(Vector3(x, y + 0.6, 0), 0.17, 0.21, 1.25, trunk.darkened(0.08 * (i % 2)), 6)
		top = Vector3(x, y + 1.2, 0)
	var g := Color(0.28, 0.52, 0.20, 1.0)
	for i in 7:
		var a := TAU * i / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		k.sphere(top + dir * 1.6 + Vector3(0, -0.35, 0), 0.5, g, Vector3(2.6, 0.18, 0.75), 6, 3)
	k.sphere(top, 0.35, Color(0.45, 0.32, 0.18, 0.0), Vector3.ONE, 6, 4)
	return k.commit()

func _bush_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var g := Color(0.24, 0.42, 0.18, 1.0)
	k.sphere(Vector3(0, 0.5, 0), 0.8, g, Vector3(1.2, 0.8, 1.0), 7, 4)
	k.sphere(Vector3(0.6, 0.4, 0.2), 0.55, g.lightened(0.07), Vector3.ONE, 6, 4)
	k.sphere(Vector3(-0.5, 0.45, -0.3), 0.6, g.darkened(0.06), Vector3.ONE, 6, 4)
	return k.commit()

func _rock_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3(0, 0.3, 0), 1.0, Color(0.52, 0.51, 0.48, 1.0), Vector3(1.3, 0.75, 1.0), 6, 4)
	k.sphere(Vector3(0.7, 0.2, 0.4), 0.55, Color(0.46, 0.45, 0.42, 1.0), Vector3.ONE, 5, 3)
	return k.commit()

# =====================================================================
#  ÁRBOLES
# =====================================================================
func _trees() -> void:
	var types := {
		"oak": {"mesh": _oak_mesh(), "items": {}},
		"pine": {"mesh": _pine_mesh(), "items": {}},
		"palm": {"mesh": _palm_mesh(), "items": {}},
		"bush": {"mesh": _bush_mesh(), "items": {}},
		"rock": {"mesh": _rock_mesh(), "items": {}},
	}
	var dens := Settings.tree_density()
	var candidates := int(26000 * dens)
	for n in candidates:
		var x := rng.randf_range(-480.0, 480.0)
		var z := rng.randf_range(-480.0, 480.0)
		var h := w.height_at(x, z)
		if h < 1.2 or w.is_blocked(x, z):
			continue
		var nrm := w.normal_at(x, z)
		if nrm.y < 0.72:
			continue
		var df := Vector2(x, z).distance_to(World.P_FOREST)
		var forest := smoothstep(150.0, 60.0, df)
		var pat := patch.get_noise_2d(x, z) * 0.5 + 0.5
		var kind := ""
		var p := rng.randf()
		if h < 3.2:
			if p < 0.10:
				kind = "palm"
		elif h > 40.0 and h < 92.0:
			if p < 0.30 * (1.0 - smoothstep(75.0, 92.0, h)):
				kind = "pine"
			elif p < 0.36:
				kind = "rock"
		else:
			var chance := 0.03 + forest * 0.75 + pat * 0.05
			if p < chance:
				kind = "oak" if rng.randf() < 0.82 or forest > 0.5 else "pine"
			elif p < chance + 0.05:
				kind = "bush"
			elif p < chance + 0.07:
				kind = "rock"
		if kind == "":
			continue
		if kind in ["oak", "pine", "palm"] and w.near_road(x, z, 4.0):
			continue
		var s := rng.randf_range(0.8, 1.35)
		if kind == "rock":
			s = rng.randf_range(0.5, 1.8)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		var xf := Transform3D(basis, Vector3(x, h - 0.15, z))
		var key := Vector2i(int(floor((x + 512.0) / TREE_CHUNK)), int(floor((z + 512.0) / TREE_CHUNK)))
		var items: Dictionary = types[kind].items
		if not items.has(key):
			items[key] = []
		items[key].append(xf)
		if kind != "rock" and kind != "bush":
			tree_count += 1
	var rng_end := Settings.tree_range()
	for kind in types:
		var t: Dictionary = types[kind]
		for key in t.items:
			var list: Array = t.items[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = t.mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat_fol
			mmi.visibility_range_end = rng_end * (0.5 if kind in ["bush", "rock"] else 1.0)
			mmi.name = "%s_%d_%d" % [kind, key.x, key.y]
			if kind == "bush" or Settings.quality < 2:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "bush" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mmi)

# =====================================================================
#  PASTO Y FLORES (en trozos de 48 m que desaparecen con la distancia)
# =====================================================================
func _grass() -> void:
	var gmesh := _grass_mesh()
	var fmesh := _flower_mesh()
	var dens := Settings.grass_density()
	var n_chunks := int(1024.0 / GRASS_CHUNK) + 1
	var range_end := Settings.grass_range()
	var flower_cols := [Color(1, 1, 1), Color(1.0, 0.85, 0.3), Color(0.75, 0.55, 1.0), Color(1.0, 0.55, 0.65), Color(0.55, 0.75, 1.0)]
	for cz in n_chunks:
		for cx in n_chunks:
			var x0 := -512.0 + cx * GRASS_CHUNK
			var z0 := -512.0 + cz * GRASS_CHUNK
			var cxm := x0 + GRASS_CHUNK * 0.5
			var czm := z0 + GRASS_CHUNK * 0.5
			if Vector2(cxm, czm).length() > 470.0:
				continue
			var tries := int(GRASS_CHUNK * GRASS_CHUNK * dens)
			var buf := PackedFloat32Array()
			var fbuf := PackedFloat32Array()
			var count := 0
			var fcount := 0
			for t in tries:
				var x := x0 + rng.randf() * GRASS_CHUNK
				var z := z0 + rng.randf() * GRASS_CHUNK
				var gi := clampi(int(round((x + World.HALF) / World.STEP)), 0, World.RES - 1)
				var gj := clampi(int(round((z + World.HALF) / World.STEP)), 0, World.RES - 1)
				var g := w.grass_map[w.idx(gi, gj)] / 255.0
				if g <= 0.0:
					continue
				# manchas: zonas más densas y claros naturales (menos saturado)
				var pat := patch.get_noise_2d(x, z) * 0.5 + 0.5
				var keep := g * smoothstep(0.25, 0.65, pat)
				if rng.randf() > keep:
					continue
				if w.is_blocked(x, z):
					continue
				var h := w.height_at(x, z)
				if h < 2.0:
					continue
				var s := rng.randf_range(0.7, 1.25) * (0.75 + pat * 0.5)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
				var base_c: Color = w.colors[w.idx(gi, gj)]
				var c := Color(base_c.r * 0.95, base_c.g * 0.92, base_c.b * 0.9).lerp(Color(0.50, 0.50, 0.28), rng.randf() * 0.3)
				if rng.randf() < 0.035:
					var fc: Color = flower_cols[rng.randi() % flower_cols.size()]
					_push(fbuf, Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(x, h, z), fc)
					fcount += 1
					continue
				_push(buf, basis, Vector3(x, h - 0.05, z), c)
				count += 1
			if count > 0:
				_add_mm(gmesh, buf, count, range_end, "grass_%d_%d" % [cx, cz])
				grass_count += count
			if fcount > 0:
				_add_mm(fmesh, fbuf, fcount, range_end * 0.8, "flowers_%d_%d" % [cx, cz])

func _push(buf: PackedFloat32Array, b: Basis, o: Vector3, c: Color) -> void:
	# formato del búfer de MultiMesh: 12 floats de transformación (fila por fila) + 4 de color
	buf.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, 1.0]))

func _add_mm(mesh: Mesh, buf: PackedFloat32Array, count: int, range_end: float, nm: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat_grass
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = range_end
	mmi.name = nm
	add_child(mmi)
