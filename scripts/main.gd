extends Node3D
## Точка входа M1: окружение, камера, кладбище, дом, скелет, HUD, миссия.

func _ready() -> void:
	_build_environment()
	var rig := CameraRig.new()
	add_child(rig)
	var graveyard := GraveyardScene.new()
	add_child(graveyard)
	var house := WitchHouse.new()
	house.position = Vector3(0, 0, -26)
	add_child(house)
	var skel := SkeletonPlayer.new()
	add_child(skel)
	skel.global_position = graveyard.spawn_point
	add_child(GameHUD.new())
	var mission := TutorialMission.new()
	mission.door = house.front_door
	mission.lever = house.door_lever
	mission.witch = house.witch
	mission.vent_marker = house.vent_marker
	mission.player = skel
	add_child(mission)

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
	# лунный свет
	var moon_light := DirectionalLight3D.new()
	moon_light.rotation_degrees = Vector3(-38, 25, 0)
	moon_light.light_color = Color(0.65, 0.7, 1.0)
	moon_light.light_energy = 0.35
	moon_light.shadow_enabled = true
	add_child(moon_light)
	# сама луна — декорация
	var moon := MeshLib.sphere(self, 3.5, Vector3(-28, 26, -55), Color(0.95, 0.95, 0.85))
	moon.material_override = MeshLib.mat(Color(0.95, 0.95, 0.85), 1.0, 0.0, Color(0.8, 0.8, 0.7))
