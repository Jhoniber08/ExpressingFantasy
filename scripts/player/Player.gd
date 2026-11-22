class_name Player
extends CharacterBody3D
## Jugador: caminar, correr, saltar, nadar, combo de ataque y cámara en 3.ª / 1.ª persona.

signal attacked(combo: int)

const WALK := 4.6
const RUN := 9.5
const JUMP := 6.8
const GRAVITY := 19.0
const SWIM := 3.4

var world: World
var avatar: Avatar
var yaw := 0.0
var pitch := -0.25
var first_person := false
var sprint_toggle := false
var touch_move := Vector2.ZERO          # joystick virtual (x derecha, y adelante)
var attack_t := 0.0
var combo := 0
var combo_window := 0.0
var swimming := false
var facing := 0.0

var cam_yaw: Node3D
var cam_pitch: Node3D
var arm: SpringArm3D
var camera: Camera3D

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	avatar = Avatar.new()
	add_child(avatar)
	# cámara
	cam_yaw = Node3D.new()
	cam_yaw.position.y = 1.55
	add_child(cam_yaw)
	cam_yaw.top_level = true
	cam_pitch = Node3D.new()
	cam_yaw.add_child(cam_pitch)
	arm = SpringArm3D.new()
	arm.spring_length = 4.6
	arm.margin = 0.25
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	arm.shape = sphere
	arm.add_excluded_object(get_rid())
	cam_pitch.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = Settings.far_clip()
	arm.add_child(camera)
	camera.current = true

func look(delta_px: Vector2) -> void:
	var s := 0.0042 * Settings.sensitivity
	yaw -= delta_px.x * s
	pitch = clampf(pitch - delta_px.y * s, -1.25, 0.9 if first_person else 0.6)

func toggle_camera() -> void:
	first_person = not first_person
	avatar.visible = not first_person

func attack() -> void:
	if attack_t > 0.0 and attack_t < 0.55:
		return
	if combo_window > 0.0:
		combo = (combo + 1) % 3
	else:
		combo = 0
	attack_t = 0.001
	attacked.emit(combo)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif event.is_action_pressed("toggle_cam"):
		toggle_camera()
	elif event.is_action_pressed("attack") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or event is InputEventKey):
		attack()

func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	if touch_move.length() > 0.05:
		input = touch_move
	input = input.limit_length(1.0)
	var sprint := Input.is_action_pressed("sprint") or sprint_toggle
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := (fwd * input.y + right * input.x)
	var water_y := 0.0
	swimming = global_position.y < water_y - 1.05
	var speed := SWIM if swimming else (RUN if sprint else WALK)
	if attack_t > 0.0 and is_on_floor():
		speed *= 0.35
	var target := dir * speed
	var accel := 10.0 if is_on_floor() or swimming else 3.5
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))
	if swimming:
		var depth := (water_y - 1.05) - global_position.y
		velocity.y = lerpf(velocity.y, clampf(depth * 3.0, -2.0, 3.0), delta * 3.0)
		if Input.is_action_just_pressed("jump"):
			velocity.y = 4.0
	elif is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -40.0:
		respawn()
	# orientación del personaje
	var hv := Vector2(velocity.x, velocity.z)
	if hv.length() > 0.4 and not first_person:
		facing = lerp_angle(facing, atan2(velocity.x, velocity.z), clampf(12.0 * delta, 0.0, 1.0))
	if first_person or attack_t > 0.0:
		facing = lerp_angle(facing, yaw + PI, clampf(14.0 * delta, 0.0, 1.0))
	avatar.rotation.y = facing
	# ataque
	if attack_t > 0.0:
		attack_t += delta / 0.42
		if attack_t >= 1.0:
			attack_t = 0.0
			combo_window = 0.45
	elif combo_window > 0.0:
		combo_window -= delta
	avatar.animate(delta, hv.length(), is_on_floor(), velocity.y, swimming, attack_t, combo)
	RenderingServer.global_shader_parameter_set("player_pos", global_position)

func _process(delta: float) -> void:
	# la cámara sigue al jugador con suavidad
	var head := global_position + Vector3(0, 1.62 if first_person else 1.55, 0)
	cam_yaw.global_position = cam_yaw.global_position.lerp(head, clampf(18.0 * delta, 0.0, 1.0)) if not first_person else head
	cam_yaw.rotation.y = yaw
	cam_pitch.rotation.x = pitch
	var target_len := 0.0 if first_person else lerpf(4.2, 5.6, clampf(Vector2(velocity.x, velocity.z).length() / RUN, 0.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, target_len, clampf(6.0 * delta, 0.0, 1.0))
	camera.position.x = 0.0 if first_person else 0.55

func respawn() -> void:
	var c: Vector2 = World.P_CITY + Vector2(0, 34)
	global_position = Vector3(c.x, world.height_at(c.x, c.y) + 1.5, c.y)
	velocity = Vector3.ZERO

func speed_h() -> float:
	return Vector2(velocity.x, velocity.z).length()
