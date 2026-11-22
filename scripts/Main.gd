extends Node
## Punto de entrada: crea el mundo, la pantalla de inicio, el jugador, el GPS y la interfaz.

var world: World
var title: TitleScreen
var player: Player
var hud: HUD
var nav: Navigator
var fireflies: CPUParticles3D
var music_title: AudioStreamPlayer
var music_explore: AudioStreamPlayer
var shots_dir := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	music_title = _music("res://audio/title_theme.mp3", true)
	music_explore = _music("res://audio/explore_theme.mp3", false)
	world = World.new()
	add_child(world)
	title = TitleScreen.new()
	add_child(title)
	world.progress.connect(title.on_progress)
	title.explore.connect(start_game)
	await world.build()
	title.on_ready()
	if shots_dir != "":
		_autotest()

func _music(path: String, play: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamMP3:
			s.loop = true
		p.stream = s
	p.volume_db = linear_to_db(maxf(Settings.music, 0.001)) if play else -60.0
	add_child(p)
	if play and p.stream:
		p.play()
	return p

func _crossfade(from: AudioStreamPlayer, to: AudioStreamPlayer) -> void:
	if to.stream and not to.playing:
		to.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(from, "volume_db", -60.0, 1.5)
	tw.tween_property(to, "volume_db", linear_to_db(maxf(Settings.music * 0.8, 0.001)), 1.5)

func start_game() -> void:
	title.hide_title()
	if player == null:
		player = Player.new()
		player.world = world
		add_child(player)
		player.respawn()
		player.yaw = 0.0
		nav = Navigator.new()
		add_child(nav)
		nav.setup(world, player)
		hud = HUD.new()
		add_child(hud)
		hud.setup(world, player, nav)
		hud.to_title.connect(back_to_title)
		_make_fireflies()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	hud.visible = true
	hud.process_mode = Node.PROCESS_MODE_INHERIT
	player.camera.current = true
	_crossfade(music_title, music_explore)

func back_to_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.cine_cam.current = true
	title.show_title()
	_crossfade(music_explore, music_title)

func _make_fireflies() -> void:
	fireflies = CPUParticles3D.new()
	fireflies.amount = [40, 70, 110, 160][Settings.quality]
	fireflies.lifetime = 6.0
	fireflies.local_coords = false
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(22, 3, 22)
	fireflies.direction = Vector3(0, 1, 0)
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.2
	fireflies.initial_velocity_max = 0.6
	fireflies.gravity = Vector3(0, 0.05, 0)
	fireflies.scale_amount_min = 0.6
	fireflies.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 1.0, 0.4)
	mat.emission_energy_multiplier = 4.0
	m.material = mat
	fireflies.mesh = m
	fireflies.position = Vector3(0, 2.0, 0)
	fireflies.emitting = false
	player.add_child(fireflies)

## Botón "atrás" de Android: cierra el mapa o pausa, en vez de salir del juego
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and hud and hud.visible:
		if hud.map_screen.visible:
			hud.map_screen.close()
		elif not get_tree().paused:
			hud.set_paused(true)
		else:
			hud.set_paused(false)

func _process(_d: float) -> void:
	if fireflies:
		fireflies.emitting = world.night > 0.55

# =====================================================================
#  MODO DE PRUEBA AUTOMÁTICA (capturas de pantalla para revisar el juego)
#  godot --path . -- --shots=/ruta
# =====================================================================
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _autotest() -> void:
	await _wait(2.0)
	await _shot("01_title")
	start_game()
	await _wait(1.5)
	world.time_of_day = 0.40
	await _wait(1.0)
	await _shot("02_city_day")
	# mirar hacia la torre de cristal
	player.yaw = 0.0
	player.pitch = -0.05
	await _wait(1.0)
	await _shot("03_city_tower")
	# GPS hacia el puerto
	nav.set_destination(world.places[1].pos, I18n.t("port"))
	player.yaw = PI
	await _wait(1.0)
	await _shot("04_route")
	hud.open_map()
	await _wait(1.2)
	await _shot("05_map")
	hud.map_screen.close()
	# bosque
	var f: Vector2 = World.P_FOREST + Vector2(40, 30)
	player.global_position = Vector3(f.x, world.height_at(f.x, f.y) + 1.0, f.y)
	player.yaw = atan2(-(World.P_FOREST.x - f.x), -(World.P_FOREST.y - f.y))
	await _wait(1.5)
	await _shot("06_forest")
	# aldea
	var v: Vector2 = World.P_VILLAGE + Vector2(45, 10)
	player.global_position = Vector3(v.x, world.height_at(v.x, v.y) + 1.0, v.y)
	player.yaw = atan2(-(World.P_VILLAGE.x - v.x), -(World.P_VILLAGE.y - v.y))
	await _wait(1.5)
	await _shot("07_village")
	# puerto al atardecer
	var pp: Vector2 = world.places[1].center
	player.global_position = Vector3(pp.x, world.height_at(pp.x, pp.y) + 1.0, pp.y)
	var pd: Vector2 = world.places[1].dir
	player.yaw = atan2(-pd.x, -pd.y)
	world.time_of_day = 0.74
	await _wait(2.0)
	await _shot("08_port_dusk")
	# ciudad de noche
	var c: Vector2 = World.P_CITY + Vector2(0, 60)
	player.global_position = Vector3(c.x, world.height_at(c.x, c.y) + 1.0, c.y)
	player.yaw = 0.0
	player.pitch = 0.05
	world.time_of_day = 0.95
	await _wait(2.0)
	await _shot("09_city_night")
	# ruinas y montaña
	var r: Vector2 = World.P_RUINS + Vector2(-30, 25)
	player.global_position = Vector3(r.x, world.height_at(r.x, r.y) + 1.0, r.y)
	player.yaw = atan2(-(World.P_RUINS.x - r.x), -(World.P_RUINS.y - r.y))
	player.pitch = -0.1
	world.time_of_day = 0.45
	await _wait(1.5)
	await _shot("10_ruins")
	print("AUTOTEST DONE")
	get_tree().quit()
