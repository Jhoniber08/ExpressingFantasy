class_name Navigator
extends Node3D
## GPS estilo GTA: marcas un destino, se calcula la ruta por los caminos,
## aparece un haz de luz en el destino y flechas en el suelo te guían.

signal route_changed
signal arrived

var world: World
var player: Player
var active := false
var target := Vector3.ZERO
var target_name := ""
var route := PackedVector3Array()
var distance := 0.0
var _timer := 0.0
var beacon: MeshInstance3D
var chevrons: Array = []

func setup(w: World, p: Player) -> void:
	world = w
	player = p
	beacon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 240.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 16
	beacon.mesh = cyl
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/beacon.gdshader")
	beacon.material_override = m
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	add_child(beacon)
	var chev_mesh := _chevron_mesh()
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1.0, 0.3, 0.9, 0.55)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.no_depth_test = false
	for i in 9:
		var c := MeshInstance3D.new()
		c.mesh = chev_mesh
		c.material_override = cm
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.visible = false
		add_child(c)
		chevrons.append(c)

func _chevron_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.32, 0, 0), Vector3(0.95, 0.05, 0.22), Color.WHITE, -0.7)
	k.box(Vector3(0.32, 0, 0), Vector3(0.95, 0.05, 0.22), Color.WHITE, 0.7)
	return k.commit()

func set_destination(pos2: Vector2, name: String) -> void:
	target = Vector3(pos2.x, world.height_at(pos2.x, pos2.y), pos2.y)
	target_name = name
	active = true
	beacon.visible = true
	beacon.position = target + Vector3(0, 110.0, 0)
	_recalc()

func clear() -> void:
	active = false
	route = PackedVector3Array()
	beacon.visible = false
	for c in chevrons:
		c.visible = false
	route_changed.emit()

func _recalc() -> void:
	if not active or player == null:
		return
	route = world.roads.route(player.global_position, target)
	distance = 0.0
	for i in route.size() - 1:
		distance += route[i].distance_to(route[i + 1])
	route_changed.emit()

func _process(delta: float) -> void:
	if not active or player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.8
		_recalc()
	var pp := player.global_position
	if Vector2(pp.x, pp.z).distance_to(Vector2(target.x, target.z)) < 12.0:
		clear()
		arrived.emit()
		return
	_place_chevrons(pp)

## Coloca flechas en el suelo a lo largo de los próximos metros de la ruta
func _place_chevrons(pp: Vector3) -> void:
	if route.size() < 2:
		return
	var start_d := 9.0
	var step := 5.5
	var acc := 0.0
	var placed := 0
	var next_at := start_d
	for i in route.size() - 1:
		var a := route[i]
		var b := route[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		while acc + seg >= next_at and placed < chevrons.size():
			var t := (next_at - acc) / seg
			var p := a.lerp(b, t)
			var y := world.height_at(p.x, p.z)
			var ch: MeshInstance3D = chevrons[placed]
			ch.visible = true
			var dir := (b - a)
			ch.global_position = Vector3(p.x, maxf(y, 0.2) + 0.45, p.z)
			ch.rotation = Vector3(0, atan2(dir.x, dir.z), 0)
			placed += 1
			next_at += step
		acc += seg
		if placed >= chevrons.size():
			break
	for k in range(placed, chevrons.size()):
		chevrons[k].visible = false
