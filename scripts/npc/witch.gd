class_name WitchNPC extends Node3D
## Некромантка. Бьюти-гот в депрессии. Встречает скелета на заднем крыльце
## (стоя, с бутылкой), выдаёт бытовуху и уползает на диван до конца времён.
## Квестгивер: interact → сигнал talked; реплики задаёт миссия через say().

signal talked

const IDLE_LINES: Array[String] = [
	"Вино кончается. Всё кончается…",
	"Не разбей… а, пофиг.",
	"Раньше я поднимала армии мёртвых. Теперь — только бокал.",
	"Свеча догорает. Ну и хрен с ней.",
	"Некромантия — дохлое дело. В прямом смысле.",
	"Пыль, паутина… идеальный интерьер. Не трогай.",
	"Я не ленивая. Я энергосберегающая.",
	"Завтра начну новую жизнь. Шучу. Не начну.",
	"Кот сдох двести лет назад. До сих пор скучаю.",
	"Хочешь совет? Забей. На всё. Мне помогает.",
	"Где-то был штопор. Лет сто назад. Ладно, зубами.",
	"Опять гремишь костями… Ладно. Греми.",
]

var prompt := "Поговорить"
var _bubble: Label3D
var _standing: Node3D
var _lying: Node3D
var _torso_stand: Node3D
var _torso_lie: Node3D
var _bottle_stand: Node3D
var _bottle_lie: Node3D
var _bubble_timer := 0.0
var _idle_timer := 0.0
var _next_idle_in := randf_range(15.0, 25.0)
var _last_line := -1
var _moving := false

func _ready() -> void:
	add_to_group("interactable")
	_standing = Node3D.new()
	add_child(_standing)
	_build_standing()
	_lying = Node3D.new()
	_lying.visible = false
	add_child(_lying)
	_build_lying()
	_bubble = Label3D.new()
	_bubble.position = Vector3(0, 2.2, 0)
	_bubble.font_size = 40
	_bubble.width = 700
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 10
	_bubble.visible = false
	add_child(_bubble)

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	talked.emit()

func say(text: String, duration := 6.0) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = duration

## Лениво уплыть на диван (marker — couch_marker особняка) и разлечься.
func go_to_couch(marker: Node3D) -> void:
	if _moving:
		return
	_moving = true
	say("Всё. Я устала. Это был весь мой спорт на месяц.", 4.0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", marker.global_position, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "global_rotation:y", marker.global_rotation.y, 3.0)
	tw.tween_callback(func() -> void:
		_standing.visible = false
		_lying.visible = true
		_moving = false)

# ---------------------------------------------------------------- стоячая поза

func _build_standing() -> void:
	var w := _standing
	# платье до пола + корсет
	_torso_stand = Node3D.new()
	w.add_child(_torso_stand)
	MeshLib.cone(_torso_stand, 0.34, 1.25, Vector3(0, 0.62, 0), MeshLib.WITCH_DRESS)
	MeshLib.cylinder(_torso_stand, 0.17, 0.2, Vector3(0, 1.12, 0), MeshLib.WITCH_DRESS.darkened(0.5))
	# грудь/плечи
	MeshLib.sphere(w, 0.16, Vector3(0, 1.28, 0), MeshLib.WITCH_DRESS, 0.8)
	# голова
	MeshLib.sphere(w, 0.16, Vector3(0, 1.52, 0), MeshLib.WITCH_SKIN.lightened(0.2))
	MeshLib.box(w, Vector3(0.05, 0.012, 0.015), Vector3(-0.06, 1.56, -0.135), Color.BLACK, Vector3(0, 0, 8))
	MeshLib.box(w, Vector3(0.05, 0.012, 0.015), Vector3(0.06, 1.56, -0.135), Color.BLACK, Vector3(0, 0, -8))
	MeshLib.box(w, Vector3(0.05, 0.018, 0.015), Vector3(0, 1.46, -0.148), MeshLib.WINE.darkened(0.4))
	# чокер
	MeshLib.cylinder(w, 0.085, 0.045, Vector3(0, 1.38, 0), Color.BLACK)
	MeshLib.box(w, Vector3(0.03, 0.03, 0.015), Vector3(0, 1.38, -0.085), MeshLib.ACCENT)
	# волосы: копна сзади и пряди на плечи
	MeshLib.sphere(w, 0.19, Vector3(0, 1.58, 0.07), MeshLib.WITCH_HAIR, 0.8)
	MeshLib.capsule(w, 0.05, 0.6, Vector3(-0.14, 1.2, 0.1), MeshLib.WITCH_HAIR, Vector3(8, 0, 6))
	MeshLib.capsule(w, 0.05, 0.6, Vector3(0.14, 1.2, 0.1), MeshLib.WITCH_HAIR, Vector3(8, 0, -6))
	MeshLib.capsule(w, 0.04, 0.5, Vector3(0, 1.15, 0.16), MeshLib.WITCH_HAIR, Vector3(12, 0, 0))
	# шляпа
	var hat := Node3D.new()
	hat.position = Vector3(0, 1.68, 0)
	hat.rotation_degrees = Vector3(0, 0, -8)
	w.add_child(hat)
	MeshLib.cylinder(hat, 0.36, 0.05, Vector3(0, 0, 0), MeshLib.WITCH_DRESS)
	MeshLib.cone(hat, 0.24, 0.5, Vector3(0, 0.25, 0), MeshLib.WITCH_DRESS)
	MeshLib.cylinder(hat, 0.245, 0.07, Vector3(0, 0.05, 0), MeshLib.WITCH_DRESS.darkened(0.5))
	MeshLib.box(hat, Vector3(0.07, 0.07, 0.03), Vector3(0, 0.05, -0.235), MeshLib.ACCENT) \
		.material_override = MeshLib.mat(MeshLib.ACCENT, 0.5, 0.0, MeshLib.ACCENT.darkened(0.5))
	# рука с бутылкой (висит вдоль платья)
	MeshLib.capsule(w, 0.045, 0.5, Vector3(0.24, 1.05, -0.05), MeshLib.WITCH_SKIN, Vector3(0, 0, -14))
	_bottle_stand = MeshLib.cylinder(w, 0.05, 0.28, Vector3(0.3, 0.78, -0.08), MeshLib.WINE, Vector3(0, 0, -20))
	# вторая рука скрещена
	MeshLib.capsule(w, 0.045, 0.42, Vector3(-0.2, 1.15, -0.1), MeshLib.WITCH_SKIN, Vector3(0, 0, 55))
	# лёгкий барьер, чтобы сквозь неё не ходили
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.28
	shape.height = 1.7
	col.shape = shape
	col.position = Vector3(0, 0.85, 0)
	body.add_child(col)
	w.add_child(body)

# ---------------------------------------------------------------- лежачая поза

func _build_lying() -> void:
	var w := Node3D.new()
	w.position = Vector3(0.1, 0.55, 0)
	_lying.add_child(w)
	_torso_lie = Node3D.new()
	w.add_child(_torso_lie)
	MeshLib.cone(_torso_lie, 0.3, 0.95, Vector3(0.25, 0.12, 0), MeshLib.WITCH_DRESS, Vector3(0, 0, -65))
	MeshLib.cylinder(_torso_lie, 0.215, 0.16, Vector3(0.12, 0.06, 0), MeshLib.WITCH_DRESS.darkened(0.5), Vector3(0, 0, -65))
	MeshLib.sphere(w, 0.16, Vector3(-0.55, 0.35, 0), MeshLib.WITCH_SKIN.lightened(0.2))
	MeshLib.box(w, Vector3(0.05, 0.012, 0.015), Vector3(-0.61, 0.4, -0.135), Color.BLACK, Vector3(0, 0, 10))
	MeshLib.box(w, Vector3(0.05, 0.012, 0.015), Vector3(-0.49, 0.4, -0.135), Color.BLACK, Vector3(0, 0, -10))
	MeshLib.box(w, Vector3(0.05, 0.018, 0.015), Vector3(-0.54, 0.3, -0.148), MeshLib.WINE.darkened(0.4), Vector3(0, 0, -6))
	MeshLib.cylinder(w, 0.085, 0.045, Vector3(-0.43, 0.24, 0), Color.BLACK, Vector3(0, 0, 50))
	MeshLib.box(w, Vector3(0.03, 0.03, 0.015), Vector3(-0.43, 0.24, -0.085), MeshLib.ACCENT, Vector3(0, 0, 50))
	MeshLib.sphere(w, 0.19, Vector3(-0.62, 0.42, 0.05), MeshLib.WITCH_HAIR, 0.7)
	MeshLib.box(w, Vector3(0.3, 0.1, 0.34), Vector3(-0.72, 0.22, 0), MeshLib.WITCH_HAIR)
	MeshLib.box(w, Vector3(0.3, 0.06, 0.42), Vector3(-1.2, 0.32, -0.1), MeshLib.WITCH_HAIR, Vector3(0, 0, -7))
	MeshLib.capsule(w, 0.035, 0.5, Vector3(-1.12, 0.06, -0.52), MeshLib.WITCH_HAIR, Vector3(-12, 0, 6))
	MeshLib.capsule(w, 0.03, 0.55, Vector3(-1.26, 0.02, -0.5), MeshLib.WITCH_HAIR, Vector3(-8, 0, -14))
	MeshLib.capsule(w, 0.032, 0.42, Vector3(-1.42, 0.14, 0.1), MeshLib.WITCH_HAIR, Vector3(8, 0, -12))
	var hat := Node3D.new()
	hat.position = Vector3(-0.88, 0.56, 0)
	hat.rotation_degrees = Vector3(0, 0, 55)
	w.add_child(hat)
	MeshLib.cylinder(hat, 0.36, 0.05, Vector3(0, -0.22, 0), MeshLib.WITCH_DRESS)
	MeshLib.cone(hat, 0.24, 0.5, Vector3(0, 0.03, 0), MeshLib.WITCH_DRESS)
	MeshLib.cylinder(hat, 0.245, 0.07, Vector3(0, -0.17, 0), MeshLib.WITCH_DRESS.darkened(0.5))
	MeshLib.capsule(w, 0.055, 0.5, Vector3(0.95, 0.35, 0.08), MeshLib.WITCH_SKIN, Vector3(0, 0, 100))
	MeshLib.capsule(w, 0.055, 0.5, Vector3(0.9, 0.3, -0.12), MeshLib.WITCH_SKIN, Vector3(0, 0, 115))
	MeshLib.box(w, Vector3(0.09, 0.2, 0.09), Vector3(1.22, 0.32, 0.08), Color.BLACK)
	MeshLib.box(w, Vector3(0.09, 0.2, 0.09), Vector3(1.2, 0.22, -0.14), Color.BLACK)
	MeshLib.capsule(w, 0.045, 0.4, Vector3(-0.3, 0.28, -0.25), MeshLib.WITCH_SKIN, Vector3(0, 0, 70))
	_bottle_lie = MeshLib.cylinder(w, 0.05, 0.28, Vector3(-0.12, 0.3, -0.3), MeshLib.WINE, Vector3(0, 0, -30))

# ---------------------------------------------------------------- поведение

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if _standing.visible:
		_torso_stand.scale.y = 1.0 + sin(t * 1.7) * 0.015
		_bottle_stand.rotation.z = deg_to_rad(-20) + sin(t * 0.9) * 0.1
	else:
		_torso_lie.scale.y = 1.0 + sin(t * 1.7) * 0.02
		_bottle_lie.rotation.z = deg_to_rad(-30) + sin(t * 0.9) * 0.12
	if _bubble.visible:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
	# апатичное бормотание себе под нос
	_idle_timer += delta
	if _idle_timer >= _next_idle_in:
		_idle_timer = 0.0
		_next_idle_in = randf_range(15.0, 25.0)
		_try_idle_line()

func _try_idle_line() -> void:
	if _bubble.visible or _moving:
		return
	var pl := Game.player_skeleton
	if pl == null or not is_instance_valid(pl):
		return
	if global_position.distance_to(pl.global_position) > 6.0:
		return
	var idx := int(randf_range(0.0, float(IDLE_LINES.size()))) % IDLE_LINES.size()
	if idx == _last_line:
		idx = (idx + 1) % IDLE_LINES.size()
	_last_line = idx
	say(IDLE_LINES[idx], 4.0)
