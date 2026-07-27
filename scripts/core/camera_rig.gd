class_name CameraRig extends Node3D
## Орбитальная камера от третьего лица. Следует за Game.possessed:
## если у одержимого узла есть дочерний Node3D "CamAnchor" — за ним, иначе за корнем.

const SENS := 0.005
const FOLLOW_SPEED := 10.0

var yaw := 0.0
var pitch := -0.35

var _arm: SpringArm3D
var _cam: Camera3D

func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = 5.5
	_arm.margin = 0.3
	_arm.collision_mask = 1
	add_child(_arm)
	_cam = Camera3D.new()
	_arm.add_child(_cam)
	_cam.current = true
	Game.camera_rig = self
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENS
		pitch = clampf(pitch - event.relative.y * SENS, -1.25, 0.55)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var target := Game.possessed
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

## Направление "вперёд" для управления с точки зрения камеры (в плоскости XZ).
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()

func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw)).normalized()

## Направление броска — куда смотрит сама камера (с учётом наклона).
func aim() -> Vector3:
	return -_cam.global_transform.basis.z
