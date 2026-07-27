class_name Fridge extends StaticBody3D
## Холодильник. Выдаёт яйца по требованию — единственный член семьи, который работает.

var prompt := "Взять яйцо"
var model_path := ""   # модель холодильника из хауспака

func _ready() -> void:
	add_to_group("interactable")
	if model_path == "":
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.8, 1.9, 0.7)
		col.shape = shape
		col.position = Vector3(0, 0.95, 0)
		add_child(col)
		MeshLib.box(self, Vector3(0.8, 1.9, 0.7), Vector3(0, 0.95, 0), Color(0.75, 0.78, 0.8))
		MeshLib.box(self, Vector3(0.76, 0.04, 0.72), Vector3(0, 1.25, 0), Color(0.6, 0.63, 0.66))
		MeshLib.capsule(self, 0.025, 0.5, Vector3(-0.3, 1.55, -0.37), MeshLib.METAL)
		MeshLib.capsule(self, 0.025, 0.35, Vector3(-0.3, 0.7, -0.37), MeshLib.METAL)
		# магнитик-череп, куда без него
		MeshLib.sphere(self, 0.05, Vector3(0.15, 1.5, -0.36), MeshLib.BONE_DARK)
	else:
		var vis := ModelLib.visual(self, model_path, Vector3.ZERO, 180.0, ModelLib.HOUSE_SCALE)
		var aabb := ModelLib.merged_aabb(vis)  # масштаб уже внутри
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = aabb.size.max(Vector3(0.3, 0.3, 0.3)) * 0.95
		col.shape = shape
		col.position = aabb.position + aabb.size * 0.5
		add_child(col)
		MeshLib.sphere(self, 0.05, Vector3(0.12, 1.35, -0.42), MeshLib.BONE_DARK)

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	var egg := BreakableProp.make(get_parent(), "egg", Vector3.ZERO)
	egg.position = position + Vector3(0, 1.1, -0.7)
	Game.hint("Яйцо. Хрупкое. Как ты.")
