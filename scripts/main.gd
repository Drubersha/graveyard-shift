extends Node3D
## Точка входа и менеджер локаций. Персистентны: окружение, камера, скелет,
## HUD, миссия. Локации (улица / интерьер особняка) грузятся по отдельности,
## переход — через порталы задней двери с фейдом.

const MANSION_POS := Vector3(0, 0, -29)

var skeleton: SkeletonPlayer
var hud: GameHUD
var mission: TutorialMission
var location: Node3D = null
var location_name := ""
var _switching := false

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
	_load_location("outdoor")
	skeleton.global_position = Vector3(3, 0.4, 8)  # открытая могила
	mission.start_intro()

## Переключение локации с фейдом (вызывается порталами и селфтестом).
func switch_location(target: String) -> void:
	if _switching or target == location_name:
		return
	_switching = true
	hud.fade_to(1.0, 0.3, func() -> void:
		_load_location(target)
		if target == "indoor":
			skeleton.global_position = MANSION_POS + Vector3(-7.0, 0.2, 4.6)
		else:
			skeleton.global_position = MANSION_POS + Vector3(-7.0, 0.2, 7.4)
		skeleton.velocity = Vector3.ZERO
		hud.fade_to(0.0, 0.35, func() -> void: _switching = false))

func _load_location(target: String) -> void:
	# скелет собирается и забирает руку — части тела не должны остаться в выгруженной локации
	if is_instance_valid(skeleton):
		if skeleton.state == SkeletonPlayer.State.SHATTERED:
			skeleton.force_reassemble()
		if not skeleton.arm_attached:
			skeleton.reattach_arm()
			Game.hint("Рука сама нашлась. Не задавай вопросов.")
	if is_instance_valid(location):
		location.queue_free()
	location = Node3D.new()
	location.name = "Location_" + target
	add_child(location)
	location_name = target
	if target == "outdoor":
		var graveyard := GraveyardScene.new()
		location.add_child(graveyard)
		var shell := Mansion.new()
		shell.mode = "exterior"
		shell.position = MANSION_POS
		location.add_child(shell)
		shell.back_portal.used.connect(func() -> void: switch_location("indoor"))
		mission.bind_outdoor(graveyard, shell)
	else:
		var interior := Mansion.new()
		interior.mode = "interior"
		interior.position = MANSION_POS
		location.add_child(interior)
		interior.back_portal.used.connect(func() -> void: switch_location("outdoor"))
		mission.bind_indoor(interior)

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
