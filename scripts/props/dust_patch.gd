class_name DustPatch extends Area3D
## Пятно пыли на полу. Исчезает от касания веником (в руках, волоком или пинком).

signal cleaned

var is_clean := false
var id := -1            # индекс для сохранения прогресса между локациями
var _radius := 0.5
var _visual: MeshInstance3D

static func make(parent: Node, pos: Vector3, radius := 0.5) -> DustPatch:
	var d := DustPatch.new()
	d.position = pos
	parent.add_child(d)
	d._build(radius)
	return d

func _build(radius: float) -> void:
	_radius = radius
	monitoring = true
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.6  # высокая зона: веник в руках скелета тоже достаёт
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)
	add_child(col)
	_visual = MeshLib.cylinder(self, radius, 0.025, Vector3(0, 0.02, 0), Color(0.52, 0.5, 0.44))
	# комки пыли — светлее пола, чтобы цель уборки было видно
	MeshLib.sphere(_visual, radius * 0.2, Vector3(radius * 0.3, 0.04, 0.1), Color(0.6, 0.58, 0.52), 0.6)
	MeshLib.sphere(_visual, radius * 0.16, Vector3(-radius * 0.35, 0.04, -0.15), Color(0.56, 0.54, 0.48), 0.6)
	MeshLib.sphere(_visual, radius * 0.13, Vector3(0.05, 0.04, radius * 0.4), Color(0.58, 0.56, 0.5), 0.6)
	body_entered.connect(_on_body)

## Метла в руках выключена из физики, поэтому её ловим вручную по расстоянию.
func _physics_process(_delta: float) -> void:
	if is_clean:
		return
	var skel := Game.player_skeleton as SkeletonPlayer
	if skel and is_instance_valid(skel.held) and skel.held is Broom:
		if skel.held.global_position.distance_to(global_position) < _radius + 0.75:
			_clean()

func _on_body(body: Node) -> void:
	if is_clean or not body is Broom:
		return
	_clean()

func _clean() -> void:
	if is_clean:
		return
	is_clean = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(0.05, 0.05, 0.05), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	cleaned.emit()
