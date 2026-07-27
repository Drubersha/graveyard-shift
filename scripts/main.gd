extends Node3D
## Точка входа и менеджер локаций. Персистентны: окружение, камера, скелет,
## HUD, миссия. Локации (двор / особняк / подвал) грузятся по отдельности,
## переходы — через порталы с фейдом. Предмет в руках путешествует с игроком.

const MANSION_POS := Vector3(0, 0, -29)

var skeleton: SkeletonPlayer
var hud: GameHUD
var mission: TutorialMission
var location: Node3D = null
var location_name := ""
var _switching := false
var _spawns := {}
var _carried: RigidBody3D = null
var _entry_point := Vector3.ZERO   # куда возвращает кнопка H

func _ready() -> void:
	Game.main_node = self
	_build_environment()
	add_child(CameraRig.new())
	skeleton = SkeletonPlayer.new()
	add_child(skeleton)
	hud = GameHUD.new()
	add_child(hud)
	mission = TutorialMission.new()
	mission.player = skeleton
	add_child(mission)
	_load_location("outdoor", "grave")
	mission.start_intro()

## Переключение локации с фейдом (порталы и селфтест).
func switch_location(target: String, spawn_id := "") -> void:
	if _switching or target == location_name:
		return
	_switching = true
	hud.fade_to(1.0, 0.3, func() -> void:
		_load_location(target, spawn_id)
		hud.fade_to(0.0, 0.35, func() -> void: _switching = false))

func _load_location(target: String, spawn_id: String) -> void:
	# скелет собирается, забирает руку и прихватывает ношу — ничего не должно
	# остаться в выгружаемой локации
	if is_instance_valid(skeleton):
		if skeleton.state == SkeletonPlayer.State.SHATTERED:
			skeleton.force_reassemble()
		if not skeleton.arm_attached:
			skeleton.reattach_arm()
			Game.hint("Рука сама нашлась. Не задавай вопросов.")
		_carried = skeleton.held if is_instance_valid(skeleton.held) else null
		if _carried:
			skeleton.held = null
			_carried.get_parent().remove_child(_carried)
	if is_instance_valid(location):
		location.queue_free()
	location = Node3D.new()
	location.name = "Location_" + target
	add_child(location)
	location_name = target
	_spawns = {}
	var portals: Array[Portal] = []
	match target:
		"outdoor":
			var graveyard := GraveyardScene.new()
			location.add_child(graveyard)
			var shell := Mansion.new()
			shell.mode = "exterior"
			shell.position = MANSION_POS
			location.add_child(shell)
			_spawns["grave"] = graveyard.spawn_point
			_collect(shell)
			portals.append_array(shell.portals)
			mission.bind_outdoor(graveyard, shell)
		"indoor":
			var interior := Mansion.new()
			interior.mode = "interior"
			interior.position = MANSION_POS
			location.add_child(interior)
			_collect(interior)
			portals.append_array(interior.portals)
			mission.bind_indoor(interior)
		"cellar":
			var cellar := Dungeon.new()
			cellar.position = MANSION_POS
			location.add_child(cellar)
			_collect(cellar)
			portals.append_array(cellar.portals)
			mission.bind_cellar(cellar)
	for p in portals:
		p.used.connect(_on_portal.bind(p))
	# игрок и его ноша
	var pos: Vector3 = _spawns.get(spawn_id, _spawns.values()[0] if not _spawns.is_empty() else Vector3.UP)
	_entry_point = pos
	skeleton.respawn_at(pos)
	if _carried:
		location.add_child(_carried)
		_carried.global_position = pos + Vector3(0, 1.0, 0)
		_carried.linear_velocity = Vector3.ZERO
		skeleton.held = _carried
		_carried = null

## H — собраться целиком и вернуться ко входу локации (спасает из любой ямы).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn") and not _switching and is_instance_valid(skeleton):
		skeleton.respawn_at(_entry_point)

func _collect(node: Node) -> void:
	if not "spawns" in node:
		return
	for key: String in node.spawns:
		_spawns[key] = (node as Node3D).to_global(node.spawns[key])

func _on_portal(p: Portal) -> void:
	switch_location(p.target, p.spawn_id)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = MeshLib.NIGHT_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.6)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = MeshLib.FOG_COLOR
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var moon_light := DirectionalLight3D.new()
	moon_light.rotation_degrees = Vector3(-38, 25, 0)
	moon_light.light_color = Color(0.65, 0.7, 1.0)
	moon_light.light_energy = 0.35
	moon_light.shadow_enabled = true
	add_child(moon_light)
	var moon := MeshLib.sphere(self, 3.5, Vector3(-28, 26, -55), Color(0.95, 0.95, 0.85))
	moon.material_override = MeshLib.mat(Color(0.95, 0.95, 0.85), 1.0, 0.0, Color(0.8, 0.8, 0.7))
