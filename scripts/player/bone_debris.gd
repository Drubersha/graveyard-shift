class_name BoneDebris extends RigidBody3D
## Отдельная кость после рассыпания. Живёт до сборки скелета.

func _ready() -> void:
	mass = 1.0
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.05
	shape.height = randf_range(0.28, 0.45)
	col.shape = shape
	add_child(col)
	var mi := MeshLib.capsule(self, 0.05, shape.height, Vector3.ZERO, MeshLib.BONE)
	mi.rotation_degrees = Vector3(randf_range(0, 180), randf_range(0, 180), 0)
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
