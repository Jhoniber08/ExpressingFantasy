class_name MeshKit
extends RefCounted
## Junta muchas piezas (cajas, cilindros, esferas...) en una sola malla con colores por vértice.
## Una malla = una llamada de dibujo: así el juego va rápido en teléfonos.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var idx := PackedInt32Array()

func add_prim(prim: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arr := prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv = arr[Mesh.ARRAY_TEX_UV]
	var has_uv: bool = uv is PackedVector2Array and uv.size() == v.size()
	var ii = arr[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	for i in v.size():
		verts.append(xf * v[i])
		norms.append((nb * n[i]).normalized())
		cols.append(color)
		uvs.append(uv[i] if has_uv else Vector2.ZERO)
	if ii is PackedInt32Array and ii.size() > 0:
		for k in ii.size():
			idx.append(base + ii[k])
	else:
		for k in v.size():
			idx.append(base + k)

func box(center: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> void:
	var b := BoxMesh.new()
	b.size = size
	add_prim(b, Transform3D(Basis(Vector3.UP, rot_y), center), color)

func cyl(center: Vector3, r_top: float, r_bot: float, h: float, color: Color, seg := 10, basis := Basis()) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	add_prim(c, Transform3D(basis, center), color)

func sphere(center: Vector3, r: float, color: Color, scale := Vector3.ONE, seg := 10, rings := 6) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	add_prim(s, Transform3D(Basis().scaled(scale), center), color)

func prism(center: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> void:
	var p := PrismMesh.new()
	p.size = size
	add_prim(p, Transform3D(Basis(Vector3.UP, rot_y), center), color)

## Cinta (camino) a lo largo de puntos 3D
func ribbon(pts: PackedVector3Array, width: float, color: Color, color_edge: Color) -> void:
	if pts.size() < 2:
		return
	var base := verts.size()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var dir := (b - a)
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x) * width * 0.5
		verts.append(pts[i] - side); norms.append(Vector3.UP); cols.append(color_edge); uvs.append(Vector2(0, i))
		verts.append(pts[i]); norms.append(Vector3.UP); cols.append(color); uvs.append(Vector2(0.5, i))
		verts.append(pts[i] + side); norms.append(Vector3.UP); cols.append(color_edge); uvs.append(Vector2(1, i))
	for i in pts.size() - 1:
		var o := base + i * 3
		for k in 2:
			idx.append_array(PackedInt32Array([o + k, o + 3 + k, o + 1 + k, o + 1 + k, o + 3 + k, o + 4 + k]))

func is_empty() -> bool:
	return verts.is_empty()

func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

static func vc_material(rough := 0.85, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func glow_material(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
