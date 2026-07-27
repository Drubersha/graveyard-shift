extends SceneTree
## Печатает AABB ключевых моделей и список анимаций женщины.
## Запуск: godot --headless --path . -s res://scripts/tools/asset_probe.gd

const PROBES := {
	"woman": "res://assets/ext/woman/Animated Woman.fbx",
	"door_double": "res://assets/ext/house/Door_Double.fbx",
	"door_1": "res://assets/ext/house/Door_1.fbx",
	"bed_king": "res://assets/ext/house/Bed_King.fbx",
	"chair_1": "res://assets/ext/house/Chair_1.fbx",
	"couch_large1": "res://assets/ext/house/Couch_Large1.fbx",
	"fireplace": "res://assets/ext/house/Fireplace.fbx",
	"toilet": "res://assets/ext/house/Bathroom_Toilet.fbx",
	"fridge": "res://assets/ext/house/Kitchen_Fridge.fbx",
	"oven_large": "res://assets/ext/house/Kitchen_Oven_Large.fbx",
	"kitchen_sink": "res://assets/ext/house/Kitchen_Sink.fbx",
	"chandelier": "res://assets/ext/house/Light_Chandelier.fbx",
	"column": "res://assets/ext/house/Column_Round1.fbx",
	"sofa_furn": "res://assets/ext/furniture/Sofa.fbx",
	"bedking_furn": "res://assets/ext/furniture/BedKing.fbx",
	"cauldron": "res://assets/ext/megakit/Cauldron.gltf",
	"table_large": "res://assets/ext/megakit/Table_Large.gltf",
	"workbench": "res://assets/ext/megakit/Workbench.gltf",
	"banner": "res://assets/ext/megakit/Banner_1.gltf",
	"candlestick_stand": "res://assets/ext/megakit/CandleStick_Stand.gltf",
	"peg_rack": "res://assets/ext/megakit/Peg_Rack.gltf",
	"dummy": "res://assets/ext/megakit/Dummy.gltf",
}

func _init() -> void:
	for key: String in PROBES:
		var ps: PackedScene = load(PROBES[key])
		if ps == null:
			print(key, ": LOAD FAIL ", PROBES[key])
			continue
		var node := ps.instantiate()
		var aabb := _merged_aabb(node, Transform3D.IDENTITY)
		print(key, " | pos=", aabb.position.snappedf(0.01), " size=", aabb.size.snappedf(0.01))
		var ap := _find_anim_player(node)
		if ap:
			print("  ANIMS: ", ", ".join(ap.get_animation_list()))
		node.free()
	quit(0)

func _merged_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			result = local_xf * mi.mesh.get_aabb()
			has = true
	for child in node.get_children():
		var sub := _merged_aabb(child, local_xf)
		if sub.size != Vector3.ZERO or sub.position != Vector3.ZERO:
			result = result.merge(sub) if has else sub
			has = true
	return result

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null
