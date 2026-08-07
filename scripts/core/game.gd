extends Node
## Автолоад "Game": глобальные сигналы, раскладка ввода, possession и счёт срача.

signal possession_changed(node: Node3D)
signal item_picked(item: Node3D)   # null — предмет отпущен
signal objective_changed(text: String)
signal hint_shown(text: String)

var possessed: Node3D = null        # чем управляем
var camera_target: Node3D = null    # чьими глазами смотрим (череп, пока он при теле — тело)
var player_skeleton: Node3D = null
var camera_rig: Node3D = null
var main_node: Node3D = null  # корень с менеджером локаций
var mess_points: int = 0
var mess_target: int = 0  # >0 — HUD показывает срач-о-метр
# кадр последней смены possession: гасит двойное срабатывание Tab,
# когда скелет и рука обрабатывают один и тот же is_action_just_pressed
var last_switch_frame := -1

## Кэш get_nodes_in_group на текущий физический кадр: HUD опрашивает группы
## каждый тик, а в одном кадре одну группу могут запрашивать несколько узлов.
## Состав групп живёт внутри сцены (предметы спавнятся и бьются), поэтому
## кэш валиден ровно один кадр — устареть не успевает.
var _group_cache := {}
var _group_frame := -1

## Состояние мира, которое переживает перезагрузку локаций.
var world_state := {
	"dust_cleaned": [],      # id убранной пыли
	"plates_done": [],       # id вымытых/разбитых тарелок
	"pantry_open": false,    # рычаг зельеварочной уже дёрнут
	"stove_have": [],        # ингредиенты, уже принятые плитой
	"breakfast_ready": false,
}

func _ready() -> void:
	_setup_input()

func mark(key: String, id: int) -> void:
	if not world_state[key].has(id):
		world_state[key].append(id)

func has_mark(key: String, id: int) -> bool:
	return world_state[key].has(id)

func stove_have() -> Array:
	return world_state["stove_have"]

func stove_add(kind: String) -> void:
	if not world_state["stove_have"].has(kind):
		world_state["stove_have"].append(kind)

func stove_reset() -> void:
	world_state["stove_have"] = []
	world_state["breakfast_ready"] = true

## Передать управление узлу. Узел может (duck typing) иметь on_possess()/on_unpossess()
## и дочерний Node3D "CamAnchor" — за ним следует камера.
func possess(node: Node3D) -> void:
	if possessed == node:
		return
	last_switch_frame = Engine.get_physics_frames()
	var prev := possessed
	possessed = node
	if is_instance_valid(prev) and prev.has_method("on_unpossess"):
		prev.on_unpossess()
	if is_instance_valid(node) and node.has_method("on_possess"):
		node.on_possess()
	possession_changed.emit(node)

func is_possessed(node: Node) -> bool:
	return possessed == node

## Камера всегда «в глазницах»: при теле — на теле, отдельно — на черепе.
func set_camera_target(node: Node3D) -> void:
	camera_target = node

## Всё, чем сейчас можно управлять: тело, оторванная рука, отделённый череп.
func control_targets() -> Array[Node3D]:
	var list: Array[Node3D] = []
	var skel := player_skeleton as SkeletonPlayer
	if skel == null:
		return list
	if skel.state != SkeletonPlayer.State.SHATTERED:
		list.append(skel)
	if is_instance_valid(skel.arm_entity):
		list.append(skel.arm_entity)
	if is_instance_valid(skel.skull_entity):
		list.append(skel.skull_entity)
	return list

## Tab — по кругу: тело → рука → череп → тело.
func cycle_control() -> void:
	var list := control_targets()
	if list.size() < 2:
		return
	var idx := list.find(possessed)
	var next: Node3D = list[(idx + 1) % list.size()]
	possess(next)
	var names := {}
	names[player_skeleton] = "тело (удалённо)" if camera_target != player_skeleton else "тело"
	hint("Управление: " + str(names.get(next, "рука" if next is DetachedArm else "череп")))

func add_mess(value: int) -> void:
	mess_points += value

## Группы с кэшем на текущий физический кадр — для горячих циклов.
func nodes_in_group(group: String) -> Array:
	var frame := int(Engine.get_physics_frames())
	if frame != _group_frame:
		_group_frame = frame
		_group_cache.clear()
	if not _group_cache.has(group):
		_group_cache[group] = get_tree().get_nodes_in_group(group)
	return _group_cache[group]

func hint(text: String) -> void:
	hint_shown.emit(text)

## На что смотрит прицел: луч из камеры сквозь центр экрана.
## Возвращает узел из группы `group`, если он в пределах `reach` от актёра.
func aimed(actor: Node3D, group: String, reach: float, ray_len := 9.0) -> Node3D:
	var rig := camera_rig as CameraRig
	if rig == null or not is_instance_valid(actor):
		return null
	var space := actor.get_world_3d().direct_space_state
	var from := rig.cam_origin()
	var params := PhysicsRayQueryParameters3D.create(from, from + rig.aim() * ray_len, 1)
	var exclude: Array[RID] = []
	if actor is CollisionObject3D:
		exclude.append((actor as CollisionObject3D).get_rid())
	params.exclude = exclude
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return null
	var node: Node = hit["collider"]
	while node != null and not node.is_in_group(group):
		node = node.get_parent()
	if node == null or not node is Node3D:
		return null
	var target := node as Node3D
	return target if target.global_position.distance_to(actor.global_position) <= reach else null

## Есть ли прямая видимость от актёра до интерактива (чтобы не жать рычаги сквозь стены).
## Разрешаем, если луч ничего не задел, задел сам таргет/его потомка,
## или точка попадания вплотную к таргету (рычаг на стене, снап на скамейке).
func has_line_of_sight(from: Node3D, target: Node3D) -> bool:
	var space := from.get_world_3d().direct_space_state
	var origin := from.global_position + Vector3.UP * 0.6
	var dest := target.global_position + Vector3.UP * 0.25
	var params := PhysicsRayQueryParameters3D.create(origin, dest, 1)
	var exclude: Array[RID] = []
	if from is CollisionObject3D:
		exclude.append((from as CollisionObject3D).get_rid())
	params.exclude = exclude
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return true
	var collider: Node = hit["collider"]
	if collider == target or target.is_ancestor_of(collider):
		return true
	return (hit["position"] as Vector3).distance_to(target.global_position) < 0.35

## Вся раскладка задаётся кодом — надёжнее, чем руками в project.godot.
func _setup_input() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("interact", KEY_E)
	_bind_key("detach_arm", KEY_F)
	_bind_key("throw_skull", KEY_G)
	_bind_key("collapse", KEY_R)
	_bind_key("switch_body", KEY_TAB)
	_bind_key("toggle_view", KEY_V)
	_bind_key("respawn", KEY_H)
	_bind_mouse("grab", MOUSE_BUTTON_LEFT)

func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
