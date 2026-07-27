extends Node
## Автолоад "Game": глобальные сигналы, раскладка ввода, possession и счёт срача.

signal prop_broken(value: int)
signal possession_changed(node: Node3D)
signal objective_changed(text: String)
signal hint_shown(text: String)
signal mission_stage_changed(stage: int)

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

func _ready() -> void:
	_setup_input()

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
	prop_broken.emit(value)

func hint(text: String) -> void:
	hint_shown.emit(text)

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
