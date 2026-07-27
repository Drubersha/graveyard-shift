class_name DetachedArm extends RigidBody3D
## Оторванная рука на радиоуправлении. Ползает, прыгает, жмёт рычаги и кнопки,
## пролезает туда, куда скелет не влезет (вентиляция).

const CRAWL_FORCE := 55.0
const MAX_SPEED := 3.4
const HOP_IMPULSE := 3.2
const INTERACT_RANGE := 1.4

var owner_skeleton: SkeletonPlayer = null
var _visual: Node3D
var _crawl_phase := 0.0

func _ready() -> void:
	mass = 2.0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 0.14, 0.42)
	col.shape = shape
	add_child(col)
	var anchor := Node3D.new()
	anchor.name = "CamAnchor"
	anchor.position = Vector3(0, 0.45, 0)
	add_child(anchor)
	_build_visual()

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	# ладонь
	MeshLib.box(_visual, Vector3(0.2, 0.07, 0.22), Vector3(0, 0, 0.04), MeshLib.BONE)
	# пальцы
	for i in 4:
		var x := -0.075 + i * 0.05
		MeshLib.capsule(_visual, 0.022, 0.16, Vector3(x, 0, -0.14), MeshLib.BONE, Vector3(90, 0, 0))
	# большой палец
	MeshLib.capsule(_visual, 0.022, 0.12, Vector3(0.13, 0, 0.02), MeshLib.BONE, Vector3(0, 0, 90))
	# торчащая кость предплечья
	MeshLib.capsule(_visual, 0.035, 0.22, Vector3(0, 0.04, 0.2), MeshLib.BONE_DARK, Vector3(70, 0, 0))
	# маркер, чтобы руку было видно издалека
	MeshLib.label(self, "РУКА", Vector3(0, 0.65, 0), 28, MeshLib.ACCENT)

func _physics_process(delta: float) -> void:
	if not Game.is_possessed(self):
		return
	var rig := Game.camera_rig as CameraRig
	var input := Vector2.ZERO
	input.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if rig and input.length() > 0.1:
		var dir := (rig.forward() * input.y + rig.right() * input.x).normalized()
		if linear_velocity.length() < MAX_SPEED:
			apply_central_force(dir * CRAWL_FORCE)
		# ладонь смотрит по ходу движения, пальцы перебирают
		var face := atan2(dir.x, dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, face + PI, delta * 8.0)
		_crawl_phase += delta * 14.0
		_visual.position.y = absf(sin(_crawl_phase)) * 0.05
	if Input.is_action_just_pressed("jump") and _on_ground():
		apply_central_impulse(Vector3.UP * HOP_IMPULSE)
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if (Input.is_action_just_pressed("switch_body") or Input.is_action_just_pressed("detach_arm")) \
			and Game.last_switch_frame != int(Engine.get_physics_frames()):
		if is_instance_valid(owner_skeleton):
			Game.possess(owner_skeleton)

func _on_ground() -> bool:
	var params := PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 0.35, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(params).is_empty()

func _try_interact() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node3D:
			continue
		var d: float = (node as Node3D).global_position.distance_to(global_position)
		if d < best_d and Game.has_line_of_sight(self, node):
			best_d = d
			best = node
	if best:
		best.interact(self)
