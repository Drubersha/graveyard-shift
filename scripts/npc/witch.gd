class_name WitchNPC extends Node3D
## Некромантка на модели Quaternius Animated Woman: стоит у чёрного входа (Idle),
## после вводного диалога исчезает с дымком и сидит на диване гостиной (SitIdle).
## API для миссии: signal talked, interact(), say(), go_to_couch().

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
	"В доме девятнадцать комнат. Убираю я — ноль.",
]

const MODEL := "Animated Woman"
const SKIN := "res://assets/ext/woman/LightSkin.png"
const MODEL_SCALE := 0.35  # модель в FBX ~5 м ростом

var prompt := "Поговорить"
var _bubble: Label3D
var _model: Node3D
var _anim: AnimationPlayer
var _barrier: StaticBody3D
var _bubble_timer := 0.0
var _idle_timer := 0.0
var _next_idle_in := randf_range(15.0, 25.0)
var _last_line := -1
var _moving := false

func _ready() -> void:
	add_to_group("interactable")
	# модель смотрит в +Z, а в Godot «вперёд» — это -Z: разворачиваем визуал,
	# чтобы поворот самого узла работал по обычной конвенции
	_model = ModelLib.visual(self, MODEL, Vector3.ZERO, 180.0, MODEL_SCALE)
	_apply_witch_look(_model)
	_anim = _find_anim(_model)
	if _anim:
		for anim_name in _anim.get_animation_list():
			var a := _anim.get_animation(anim_name)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
		_play("Idle")
	_attach_hat()
	# барьер, чтобы сквозь хозяйку не ходили
	_barrier = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	col.shape = shape
	col.position = Vector3(0, 0.85, 0)
	_barrier.add_child(col)
	add_child(_barrier)
	_bubble = Label3D.new()
	_bubble.position = Vector3(0, 2.15, 0)
	_bubble.font_size = 40
	_bubble.width = 700
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 10
	_bubble.no_depth_test = true      # реплика читается сквозь косяки и мебель
	_bubble.render_priority = 12
	_bubble.outline_render_priority = 11
	_bubble.visible = false
	add_child(_bubble)

## Скин + лёгкое затемнение в готессу.
func _apply_witch_look(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(SKIN)
		m.albedo_color = Color(0.5, 0.38, 0.58)   # готический полумрак вместо джинсы
		m.roughness = 0.95
		mi.material_override = m
	for child in node.get_children():
		_apply_witch_look(child)

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _play(short_name: String) -> void:
	if _anim == null:
		return
	for anim_name in _anim.get_animation_list():
		if anim_name.ends_with(short_name):
			_anim.play(anim_name, 0.3)
			return

## Остроконечная шляпа. Кости FBX в своём масштабе, поэтому шляпа висит
## на фиксированной высоте головы (стоя/сидя — _hat_root двигается).
var _hat_root: Node3D

func _attach_hat() -> void:
	_hat_root = Node3D.new()
	add_child(_hat_root)
	_hat_root.position = Vector3(0, 1.58, 0)
	var hat := Node3D.new()
	hat.position = Vector3(0, 0.1, 0)
	hat.rotation_degrees = Vector3(0, 0, -8)
	_hat_root.add_child(hat)
	MeshLib.cylinder(hat, 0.34, 0.045, Vector3.ZERO, MeshLib.WITCH_DRESS)
	MeshLib.cone(hat, 0.22, 0.48, Vector3(0, 0.24, 0), MeshLib.WITCH_DRESS)
	MeshLib.cylinder(hat, 0.225, 0.06, Vector3(0, 0.05, 0), MeshLib.WITCH_DRESS.darkened(0.5))
	MeshLib.box(hat, Vector3(0.06, 0.06, 0.03), Vector3(0, 0.05, -0.215), MeshLib.ACCENT) \
		.material_override = MeshLib.mat(MeshLib.ACCENT, 0.5, 0.0, MeshLib.ACCENT.darkened(0.5))

# ---------------------------------------------------------------- API миссии

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	talked.emit()

func say(text: String, duration := 6.0) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = duration

## Сразу усадить на диван (при загрузке интерьера, когда знакомство уже было).
func sit_now() -> void:
	_play("SitIdle")
	_bubble.position.y = 1.6
	if _hat_root:
		_hat_root.position = Vector3(0, 1.08, 0.12)

## Уйти с крыльца в дом (дым — и нет её). Внутри она уже будет на диване.
func go_home_puff() -> void:
	if _moving:
		return
	_moving = true
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(func() -> void:
		_puff(global_position + Vector3.UP * 0.9)
		visible = false)
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)

## Дым-телепорт на диван: идти лень, магия дешевле.
func go_to_couch(marker: Node3D) -> void:
	if _moving:
		return
	_moving = true
	_puff(global_position + Vector3.UP * 0.9)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		global_position = marker.global_position
		global_rotation = marker.global_rotation
		_play("SitIdle")
		_bubble.position.y = 1.6
		_puff(global_position + Vector3.UP * 0.7)
		say("Я наверху. Не спрашивай как. Работай.", 4.0)
		_moving = false)

func _puff(at: Vector3) -> void:
	for i in 6:
		var puff := MeshLib.sphere(get_tree().current_scene, randf_range(0.12, 0.24),
			at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.4), randf_range(-0.3, 0.3)),
			Color(0.5, 0.45, 0.6), 0.9)
		var tw := puff.create_tween()
		tw.tween_property(puff, "scale", Vector3(0.02, 0.02, 0.02), randf_range(0.5, 0.9))
		tw.parallel().tween_property(puff, "position:y", puff.position.y + 0.7, 0.8)
		tw.tween_callback(puff.queue_free)

# ---------------------------------------------------------------- поведение

func _process(delta: float) -> void:
	if _bubble.visible:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
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
