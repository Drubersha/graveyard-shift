class_name CameraRig extends Node3D
## Орбитальная камера от третьего лица. Следует за Game.possessed:
## если у одержимого узла есть дочерний Node3D "CamAnchor" — за ним, иначе за корнем.

const SENS := 0.005
const FOLLOW_SPEED := 10.0
const THIRD_LENGTH := 4.8

var yaw := 0.0
var pitch := -0.35
var first_person := false

var _arm: SpringArm3D
var _cam: Camera3D

func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = THIRD_LENGTH
	_arm.margin = 0.35
	_arm.collision_mask = 1
	# шар вместо луча: иначе камера пролезает сквозь потолки и тонкие перекрытия
	var probe := SphereShape3D.new()
	probe.radius = 0.4
	_arm.shape = probe
	add_child(_arm)
	_cam = Camera3D.new()
	_arm.add_child(_cam)
	_cam.current = true
	Game.camera_rig = self
	Game.possession_changed.connect(func(_n: Node3D) -> void: _apply_view_mode())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view"):
		toggle_view()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENS
		var lo := -1.35 if first_person else -1.25
		var hi := 1.2 if first_person else 0.55
		pitch = clampf(pitch - event.relative.y * SENS, lo, hi)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# смотрим глазами черепа: он при теле — камера на теле, отделён — летит с ним
	var target := Game.camera_target
	if not is_instance_valid(target):
		target = Game.possessed
	if not is_instance_valid(target):
		return
	var anchor: Node3D = target.get_node_or_null("CamAnchor")
	var target_pos: Vector3
	if anchor:
		target_pos = anchor.global_position
	else:
		target_pos = target.global_position + Vector3.UP * 1.2
	global_position = global_position.lerp(target_pos, minf(1.0, delta * FOLLOW_SPEED))
	rotation.y = yaw
	_arm.rotation.x = pitch

## Переключение вида: от третьего лица ↔ от первого (из глазниц черепа).
func toggle_view() -> void:
	first_person = not first_person
	_arm.spring_length = 0.0 if first_person else THIRD_LENGTH
	pitch = clampf(pitch, -1.25, 0.4)
	_apply_view_mode()
	Game.hint("Вид от первого лица (V — обратно)" if first_person else "Вид от третьего лица (V — обратно)")

## Одержимый объект прячет свой визуал, когда камера сидит у него внутри.
func _apply_view_mode() -> void:
	for node in get_tree().get_nodes_in_group("view_aware"):
		if node.has_method("set_view_mode"):
			node.set_view_mode(first_person and Game.camera_target == node)

## Направление "вперёд" для управления с точки зрения камеры (в плоскости XZ).
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()

func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw)).normalized()

## Направление броска — куда смотрит сама камера (с учётом наклона).
func aim() -> Vector3:
	return -_cam.global_transform.basis.z
