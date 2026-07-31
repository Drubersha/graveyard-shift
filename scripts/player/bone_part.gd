class_name BonePart extends RigidBody3D
## Отвалившаяся именованная деталь скелета (рука, нога, торс).
## В отличие от BoneDebris это не «какая-то кость», а конкретно та деталь,
## которая была на теле: та же модель, тот же износ. Живёт до сборки по R.

var part_id := ""

static func make(parent: Node, id: String, at: Vector3, vel: Vector3) -> BonePart:
	var p := BonePart.new()
	p.part_id = id
	parent.add_child(p)
	p.global_position = at
	p.linear_velocity = vel
	# крутить сильнее ±2.5 нельзя: раскрученная деталь укатывается от кучи
	p.angular_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5),
		randf_range(-2.5, 2.5))
	return p

func _ready() -> void:
	add_to_group("bone_part")
	mass = 2.5 if part_id == "torso" else 1.2
	# кости не резиновые: гасим отскок, иначе деталь укатывается за карту
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.05
	physics_material_override.friction = 0.9
	angular_damp = 0.8
	var vis := BoneParts.build(self, part_id)
	# коллизия — бокс по общей AABB детали; merged_aabb уже с масштабом визуала
	var aabb := ModelLib.merged_aabb(vis)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size.max(Vector3(0.06, 0.06, 0.06)) * 0.92
	col.shape = shape
	col.position = aabb.position + aabb.size * 0.5
	add_child(col)
