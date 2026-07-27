class_name TutorialMission extends Node
## Обучающая миссия «Приберись в доме»: дойти до дома → рука через вентиляцию →
## рычаг → поговорить с ведьмой → разнести дом → доложить.

enum Stage { GO_HOME, OPEN_DOOR, TALK, TRASH, REPORT, DONE }

const MESS_TARGET := 200

var door: DoorGate
var lever: Lever
var witch: WitchNPC
var vent_marker: Node3D
var player: SkeletonPlayer

var stage := Stage.GO_HOME
var _beacon: MeshInstance3D

func _ready() -> void:
	lever.activated.connect(_on_lever)
	door.opened.connect(_on_door_opened)
	witch.talked.connect(_on_talk)
	Game.prop_broken.connect(_on_mess)
	_beacon = MeshLib.cylinder(self, 0.35, 7.0, Vector3.ZERO, MeshLib.ACCENT)
	var m := MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.22
	_beacon.material_override = m
	_enter(Stage.GO_HOME)
	Game.hint("WASD — ходить. Управление — на панели справа сверху.")

func _enter(s: Stage) -> void:
	stage = s
	Game.mission_stage_changed.emit(s)
	match s:
		Stage.GO_HOME:
			Game.objective_changed.emit("Ты откопался. Иди к готическому дому за воротами кладбища.")
			_beacon_at(door.global_position + Vector3(0.5, 0, 1.0))
		Stage.OPEN_DOOR:
			Game.objective_changed.emit("Дверь заперта. Оторви руку (F), заведи её в вентиляцию справа от двери и дёрни рычаг изнутри (E).")
			_beacon_at(vent_marker.global_position)
			Game.hint("Рука пролезет туда, куда ты — нет.")
		Stage.TALK:
			Game.objective_changed.emit("Зайди в дом и поговори с хозяйкой (E).")
			_beacon_at(witch.global_position + Vector3(0, 0, -1.2))
		Stage.TRASH:
			Game.mess_target = MESS_TARGET
			_update_trash_objective()
			_beacon.visible = false
			Game.hint("Хватай (ЛКМ), швыряй (держать ЛКМ), кидай мебель в мебель. Череп (G) тоже снаряд.")
		Stage.REPORT:
			Game.objective_changed.emit("Достаточно. Доложи хозяйке (E).")
			_beacon_at(witch.global_position + Vector3(0, 0, -1.2))
		Stage.DONE:
			Game.objective_changed.emit("Туториал пройден! M1 завершён. Дальше — город, магазин и полиция (M2). А пока — вольная песочница.")
			_beacon.visible = false

func _beacon_at(pos: Vector3) -> void:
	_beacon.visible = true
	_beacon.global_position = pos + Vector3.UP * 3.0

func _physics_process(_delta: float) -> void:
	if stage == Stage.GO_HOME and is_instance_valid(player):
		if player.global_position.distance_to(door.global_position) < 7.0:
			_enter(Stage.OPEN_DOOR)

func _on_lever() -> void:
	door.open()

func _on_door_opened() -> void:
	if stage <= Stage.OPEN_DOOR:
		witch.say("Открыто. Ну заходи, раз припёрся.")
		_enter(Stage.TALK)

func _on_talk() -> void:
	match stage:
		Stage.TALK:
			witch.say("А, ты. Слушай… тут бардак. Приберись, а? В смысле — разнеси здесь всё к чертям. Мне так спокойнее.")
			_enter(Stage.TRASH)
		Stage.REPORT:
			witch.say("Неплохо для груды костей. Свободен. Завтра сходишь за вином… но это уже другая история.")
			_enter(Stage.DONE)
		Stage.DONE:
			witch.say("Иди уже. Я занята. Вином.")
		_:
			witch.say("Дверь. Рычаг. Вентиляция. Сам-сам.")

func _on_mess(_value: int) -> void:
	if stage == Stage.TRASH:
		if Game.mess_points >= MESS_TARGET:
			witch.say("О-о. Уже уютнее.")
			_enter(Stage.REPORT)
		else:
			_update_trash_objective()

func _update_trash_objective() -> void:
	Game.objective_changed.emit("«Уборка»: разнеси дом (%d/%d)" % [Game.mess_points, MESS_TARGET])
