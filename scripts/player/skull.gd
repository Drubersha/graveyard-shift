class_name SkullEntity extends RigidBody3D
## Брошенный/отлетевший череп. Точка сборки скелета: где череп — там и соберёмся.

func _ready() -> void:
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
	anchor.position = Vector3(0, 0.4, 0)
	add_child(anchor)
	var vis := Node3D.new()
	add_child(vis)
	MeshLib.sphere(vis, 0.17, Vector3.ZERO, MeshLib.BONE)
	MeshLib.box(vis, Vector3(0.16, 0.1, 0.12), Vector3(0, -0.12, -0.03), MeshLib.BONE)
	MeshLib.sphere(vis, 0.035, Vector3(-0.06, 0.02, -0.14), Color.BLACK)
	MeshLib.sphere(vis, 0.035, Vector3(0.06, 0.02, -0.14), Color.BLACK)
