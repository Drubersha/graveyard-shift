class_name Lever extends StaticBody3D
## Рычаг. Жмётся скелетом или оторванной рукой (interact).

signal activated

var prompt := "Дёрнуть рычаг"
var used := false
var _handle: MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 0.4, 0.2)
	col.shape = shape
	add_child(col)
	MeshLib.box(self, Vector3(0.16, 0.24, 0.1), Vector3(0, 0, 0), MeshLib.METAL)
	_handle = MeshLib.capsule(self, 0.025, 0.34, Vector3(0, 0.14, -0.05), Color(0.7, 0.2, 0.2), Vector3(-25, 0, 0))

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	if used:
		return
	used = true
	var tw := create_tween()
	tw.tween_property(_handle, "rotation_degrees:x", 35.0, 0.25)
	activated.emit()
