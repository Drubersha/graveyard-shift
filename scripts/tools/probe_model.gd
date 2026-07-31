extends SceneTree
## Промер любой модели: габариты, оси, число мешей и материалов, анимации.
## Нужен, чтобы проверять масштаб НОВОЙ модели против эталона из пака, а не на глаз.
##
## Запуск:
##   godot --headless --path . -s res://scripts/tools/probe_model.gd -- <res://путь> [ещё пути]
## Без аргументов промеряет эталоны: дверь, стул, холодильник — по ним сверяют масштаб.

const REFERENCE := {
	"дверь (проём ~2 м)": "res://assets/ext/house/Door_1.fbx",
	"стул (сиденье ~0.45 м)": "res://assets/ext/house/Chair_1.fbx",
	"холодильник (~1.8 м)": "res://assets/ext/house/Kitchen_Fridge.fbx",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var targets: Dictionary = {}
	if args.is_empty():
		targets = REFERENCE.duplicate()
		print("(без аргументов — промеряю эталоны для сверки масштаба)\n")
	else:
		for a in args:
			targets[a] = a

	for key: String in targets:
		_probe(key, targets[key])
	quit(0)


func _probe(label: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		print("%s: НЕТ ФАЙЛА %s" % [label, path])
		return
	var ps: PackedScene = load(path)
	if ps == null:
		print("%s: НЕ ЗАГРУЗИЛСЯ %s" % [label, path])
		return
	var node := ps.instantiate()
	var aabb := _merged_aabb(node, Transform3D.IDENTITY)
	var meshes: Array[String] = []
	var mats := {}
	_collect(node, meshes, mats)

	print("%s\n  файл    : %s" % [label, path])
	print("  габариты: X=%.3f Y=%.3f Z=%.3f (высота — это Y)" % [aabb.size.x, aabb.size.y, aabb.size.z])
	print("  начало  : %s" % [aabb.position.snappedf(0.001)])
	var low := aabb.position.y
	print("  низ по Y: %.3f %s" % [low, "— стоит на нуле" if absf(low) < 0.02 else "— НЕ на нуле, при постановке уедет"])
	print("  мешей   : %d, материалов: %d" % [meshes.size(), mats.size()])
	var ap := _find_anim(node)
	if ap:
		print("  анимации: %s" % ", ".join(ap.get_animation_list()))
	node.free()
	print("")


func _collect(node: Node, meshes: Array[String], mats: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			meshes.append(mi.name)
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m:
					mats[m.resource_name if m.resource_name != "" else str(m.get_instance_id())] = true
	for child in node.get_children():
		_collect(child, meshes, mats)


func _merged_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = local_xf * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for child in node.get_children():
		var sub := _merged_aabb(child, local_xf)
		if sub.size.length_squared() > 0.0001:
			result = result.merge(sub) if has else sub
			has = true
	return result


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null
