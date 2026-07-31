class_name SkullEntity extends RigidBody3D
## Отделённый череп: глаза скелета и точка сборки тела.
## Камера всегда следует за ним, а управлять им можно напрямую — катится как шар.

const ROLL_FORCE := 26.0
const MAX_SPEED := 3.6
const HOP := 3.0

var owner_skeleton: SkeletonPlayer = null
var _visual: Node3D

func _ready() -> void:
	add_to_group("view_aware")
	mass = 3.0
	# гасим качение, иначе сфера катится вечно и сборка не наступает
	linear_damp = 0.35
	angular_damp = 2.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.3
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.19
	col.shape = shape
	add_child(col)
	var anchor := Node3D.new()
	anchor.name = "CamAnchor"
	anchor.position = Vector3(0, 0.34, 0)
	add_child(anchor)
	_visual = Node3D.new()
	add_child(_visual)
	# ровно та же деталь, что стояла на плечах — никакого «второго черепа»
	BoneParts.build(_visual, "skull")

func set_view_mode(first_person: bool) -> void:
	if is_instance_valid(_visual):
		_visual.visible = not first_person

func _physics_process(_delta: float) -> void:
	if not Game.is_possessed(self):
		return
	var rig := Game.camera_rig as CameraRig
	var input := Vector2.ZERO
	input.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if rig and input.length() > 0.1:
		var dir := (rig.forward() * input.y + rig.right() * input.x).normalized()
		if linear_velocity.length() < MAX_SPEED:
			apply_central_force(dir * ROLL_FORCE)
	if Input.is_action_just_pressed("jump") and _on_ground():
		apply_central_impulse(Vector3.UP * HOP)
	if Input.is_action_just_pressed("switch_body") \
			and Game.last_switch_frame != int(Engine.get_physics_frames()):
		Game.cycle_control()
	# G рядом с телом — прирасти обратно
	if Input.is_action_just_pressed("throw_skull") and is_instance_valid(owner_skeleton):
		owner_skeleton.try_attach_skull()

func _on_ground() -> bool:
	var params := PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 0.28, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(params).is_empty()
