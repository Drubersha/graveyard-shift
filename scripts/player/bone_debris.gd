class_name BoneDebris extends RigidBody3D
## Безымянная мелочь после полного рассыпания: рёбра, позвонки, обломки.
## Именованные детали (руки, ноги, торс) — это BonePart, а не это.

func _ready() -> void:
	mass = 0.7
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.05
	physics_material_override.friction = 0.9
	var length := randf_range(0.16, 0.34)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.07, length, 0.07)
	col.shape = shape
	add_child(col)
	# гранёный осколок: пять сторон, к концам сужается — никакого сглаживания
	var r := randf_range(0.022, 0.036)
	var mi := MeshLib.faceted(self, [
		Vector3(r * 0.8, -length * 0.5, r * 0.8),
		Vector3(r, -length * 0.2, r),
		Vector3(r * 0.85, length * 0.25, r * 0.85),
		Vector3(r * 1.1, length * 0.5, r * 1.1),
	], 5, Vector3.ZERO, MeshLib.BONE_SKEL)
	# материал берём из общей точки правды: у обломка должен быть ровно тот же
	# эмиссионный пол, что у тела, из которого он только что вылетел
	mi.material_override = MeshLib.skel_mat("bone" if randf() < 0.6 else "dark")
	mi.rotation_degrees = Vector3(randf_range(0, 180), randf_range(0, 180), 0)
	angular_damp = 0.8
	angular_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5),
		randf_range(-2.5, 2.5))
