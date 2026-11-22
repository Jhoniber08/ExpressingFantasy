class_name Avatar
extends Node3D
## Personaje original (explorador) con proporciones humanas (~1.8 m) y animación procedural:
## respirar, caminar, correr, saltar, nadar y combo de espada de 3 golpes.

var parts := {}
var t := 0.0
var cape: Node3D
var sword_back: Node3D
var sword_hand: Node3D

const SKIN := Color("#e2b48e")
const TUNIC := Color("#1f5f7a")
const TUNIC2 := Color("#163f55")
const PANTS := Color("#2a2a35")
const LEATHER := Color("#6b4426")
const BOOTS := Color("#2b1d14")
const HAIR := Color("#2f1e14")
const CAPE := Color("#8e2433")
const GOLD := Color("#d8b24a")

func _ready() -> void:
	_build()

func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi

func _pivot(parent: Node3D, pos: Vector3, nm: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.name = nm
	parent.add_child(n)
	parts[nm] = n
	return n

func _caps(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s

func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b

func _build() -> void:
	var hips := _pivot(self, Vector3(0, 0.95, 0), "hips")
	_part(hips, _caps(0.17, 0.42), PANTS, Vector3(0, 0.02, 0)).scale = Vector3(1.15, 0.7, 0.85)
	var torso := _pivot(hips, Vector3(0, 0.1, 0), "torso")
	var chest := _part(torso, _caps(0.19, 0.62), TUNIC, Vector3(0, 0.3, 0))
	chest.scale = Vector3(1.1, 1.0, 0.75)
	_part(torso, _box(Vector3(0.40, 0.07, 0.30)), LEATHER, Vector3(0, 0.06, 0))
	_part(torso, _box(Vector3(0.08, 0.08, 0.04)), GOLD, Vector3(0, 0.06, 0.15))
	_part(torso, _box(Vector3(0.05, 0.55, 0.27)), LEATHER, Vector3(0.02, 0.33, 0)).rotation.z = 0.55
	_part(torso, _caps(0.2, 0.42), TUNIC2, Vector3(0, -0.12, 0)).scale = Vector3(1.15, 0.6, 0.85)
	var neck := _pivot(torso, Vector3(0, 0.62, 0), "neck")
	_part(neck, _caps(0.055, 0.16), SKIN, Vector3(0, 0.04, 0))
	var head := _pivot(neck, Vector3(0, 0.15, 0), "head")
	var skull := _part(head, _sph(0.115), SKIN, Vector3(0, 0.07, 0))
	skull.scale = Vector3(0.92, 1.08, 1.0)
	var hair := _part(head, _sph(0.125), HAIR, Vector3(0, 0.11, -0.015))
	hair.scale = Vector3(1.0, 0.85, 1.05)
	_part(head, _box(Vector3(0.2, 0.06, 0.08)), HAIR, Vector3(0, 0.17, 0.08)).rotation.x = -0.3
	for sx in [-1.0, 1.0]:
		var eye := _part(head, _sph(0.016), Color("#1a1420"), Vector3(0.042 * sx, 0.075, 0.1))
		eye.scale = Vector3(1, 1.2, 0.6)
		_part(head, _sph(0.02), SKIN, Vector3(0.112 * sx, 0.06, 0.0)).scale = Vector3(0.5, 1, 0.8)
	_part(head, _sph(0.018), SKIN.darkened(0.06), Vector3(0, 0.045, 0.112))
	# brazos
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var sh := _pivot(torso, Vector3(0.24 * sx, 0.52, 0), "shoulder_" + side)
		_part(sh, _sph(0.075), TUNIC, Vector3(0, 0, 0)).scale = Vector3(1, 0.9, 1)
		_part(sh, _caps(0.055, 0.30), TUNIC, Vector3(0, -0.15, 0))
		var el := _pivot(sh, Vector3(0, -0.29, 0), "elbow_" + side)
		_part(el, _caps(0.048, 0.28), SKIN, Vector3(0, -0.13, 0))
		_part(el, _caps(0.055, 0.12), LEATHER, Vector3(0, -0.17, 0))
		var hand := _pivot(el, Vector3(0, -0.29, 0), "hand_" + side)
		_part(hand, _sph(0.045), SKIN, Vector3(0, -0.02, 0)).scale = Vector3(0.9, 1.1, 0.7)
	# piernas
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var hip := _pivot(hips, Vector3(0.1 * sx, -0.06, 0), "hip_" + side)
		_part(hip, _caps(0.075, 0.46), PANTS, Vector3(0, -0.22, 0))
		var knee := _pivot(hip, Vector3(0, -0.44, 0), "knee_" + side)
		_part(knee, _caps(0.062, 0.44), PANTS, Vector3(0, -0.2, 0))
		_part(knee, _caps(0.07, 0.24), BOOTS, Vector3(0, -0.3, 0))
		var foot := _pivot(knee, Vector3(0, -0.43, 0), "foot_" + side)
		_part(foot, _box(Vector3(0.11, 0.08, 0.24)), BOOTS, Vector3(0, -0.02, 0.05))
	# capa
	cape = _pivot(torso, Vector3(0, 0.58, -0.15), "cape")
	var cm := _part(cape, _box(Vector3(0.46, 0.95, 0.03)), CAPE, Vector3(0, -0.47, 0))
	cm.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	# espada (en la espalda y en la mano)
	sword_back = _sword(torso)
	sword_back.position = Vector3(-0.05, 0.35, -0.2)
	sword_back.rotation = Vector3(0, 0, 2.6)
	sword_hand = _sword(parts["hand_r"])
	sword_hand.position = Vector3(0, -0.05, 0.02)
	sword_hand.rotation = Vector3(PI * 0.5, 0, 0)
	sword_hand.visible = false

func _sword(parent: Node3D) -> Node3D:
	var s := Node3D.new()
	parent.add_child(s)
	_part(s, _box(Vector3(0.045, 0.85, 0.012)), Color("#dfe6ee"), Vector3(0, 0.55, 0))
	_part(s, _box(Vector3(0.22, 0.04, 0.05)), GOLD, Vector3(0, 0.12, 0))
	_part(s, _caps(0.022, 0.18), LEATHER, Vector3(0, 0.02, 0))
	_part(s, _sph(0.03), GOLD, Vector3(0, -0.08, 0))
	return s

func _r(nm: String) -> Node3D:
	return parts[nm]

## Animación por fotograma
## speed: m/s horizontal · on_floor · swim · attack: fase 0..1 · combo 0..2
func animate(delta: float, speed: float, on_floor: bool, vy: float, swim: bool, attack: float, combo: int) -> void:
	t += delta
	var run := clampf(speed / 9.0, 0.0, 1.0)
	var walk := clampf(speed / 4.5, 0.0, 1.0)
	var freq := lerpf(7.0, 11.5, run)
	var ph := t * freq
	var sw := sin(ph) * lerpf(0.0, 0.95, walk)
	var breath := sin(t * 2.2) * 0.015
	var hips := _r("hips")
	var torso := _r("torso")
	hips.position.y = 0.95 + absf(sin(ph)) * 0.06 * walk + breath
	torso.rotation.x = 0.06 + 0.18 * run
	torso.rotation.y = sin(ph) * 0.12 * walk
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		_r("hip_" + side).rotation.x = sw * s
		_r("knee_" + side).rotation.x = maxf(0.0, -sin(ph + (0.0 if side == "l" else PI)) * 1.1 * walk + 0.05)
		_r("shoulder_" + side).rotation.x = -sw * s * 0.85
		_r("shoulder_" + side).rotation.z = (0.12 + 0.05 * run) * (-1.0 if side == "l" else 1.0)
		_r("elbow_" + side).rotation.x = -0.25 - 0.9 * run
	if not on_floor and not swim:
		var up := clampf(vy / 6.0, -1.0, 1.0)
		for side in ["l", "r"]:
			_r("hip_" + side).rotation.x = -0.5 if side == "l" else 0.25
			_r("knee_" + side).rotation.x = 0.9 if side == "l" else 0.3
			_r("shoulder_" + side).rotation.x = -0.6 - up * 0.4
			_r("shoulder_" + side).rotation.z = (0.6) * (-1.0 if side == "l" else 1.0)
	if swim:
		torso.rotation.x = 1.1
		hips.position.y = 0.55
		for side in ["l", "r"]:
			var s2 := 1.0 if side == "l" else -1.0
			_r("shoulder_" + side).rotation.x = -2.2 + sin(t * 3.0 + s2) * 1.2
			_r("hip_" + side).rotation.x = sin(t * 6.0) * 0.4 * s2
	# capa: se levanta al correr
	cape.rotation.x = 0.15 + run * 0.9 + sin(t * 8.0) * 0.06 * run + (0.6 if not on_floor else 0.0)
	# ataque
	var attacking := attack > 0.0
	sword_hand.visible = attacking
	sword_back.visible = not attacking
	if attacking:
		var a := attack
		var sr := _r("shoulder_r")
		var er := _r("elbow_r")
		match combo:
			0:
				sr.rotation = Vector3(lerpf(-2.4, 0.6, _ease(a)), 0, lerpf(0.4, -0.3, a))
				torso.rotation.y = lerpf(0.6, -0.5, _ease(a))
			1:
				sr.rotation = Vector3(-1.4, 0, lerpf(1.6, -0.9, _ease(a)))
				torso.rotation.y = lerpf(-0.7, 0.7, _ease(a))
			_:
				sr.rotation = Vector3(lerpf(-3.0, 0.9, _ease(a)), 0, 0.1)
				torso.rotation.x = lerpf(-0.2, 0.5, _ease(a))
				hips.position.y -= sin(a * PI) * 0.12
		er.rotation.x = -0.3

func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
