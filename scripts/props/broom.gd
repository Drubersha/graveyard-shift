class_name Broom extends RigidBody3D
## Веник. Хватается как обычный предмет; пыль чистится, когда веник её касается —
## неважно, несёшь ты его, возишь или пнул через всю кухню.

func _ready() -> void:
	add_to_group("grabbable")
	mass = 3.0
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.06
	shape.height = 1.3
	col.shape = shape
	col.rotation_degrees = Vector3(0, 0, 90)
	add_child(col)
	# черенок
	MeshLib.capsule(self, 0.025, 1.1, Vector3(-0.25, 0, 0), MeshLib.WOOD, Vector3(0, 0, 90))
	# метёлка
	MeshLib.box(self, Vector3(0.3, 0.16, 0.1), Vector3(0.42, -0.02, 0), Color(0.75, 0.6, 0.3))
	for i in 5:
		MeshLib.box(self, Vector3(0.04, 0.14, 0.08), Vector3(0.32 + i * 0.05, -0.14, 0), Color(0.68, 0.54, 0.26))
	# перевязка
	MeshLib.box(self, Vector3(0.08, 0.05, 0.12), Vector3(0.3, 0.04, 0), Color(0.5, 0.3, 0.2))
