extends SceneTree
## Промер скелета модели: список костей, их индексы, поза покоя и масштаб узла.
## Нужен, чтобы вешать BoneAttachment3D на ПРАВИЛЬНУЮ кость, а не на глазок.
##
##   godot --headless --path . -s res://scripts/tools/probe_bones.gd -- <res://путь>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = ["res://assets/ext/woman/Animated Woman.fbx"]
	for path in args:
		_probe(path)
	quit(0)


func _probe(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("НЕТ ФАЙЛА %s" % path)
		return
	var node: Node = (load(path) as PackedScene).instantiate()
	print("=== %s" % path)
	_dump(node, 0)
	var skel := _find_skel(node)
	if skel:
		print("Skeleton3D: %s, костей %d, motion_scale=%.4f" % [skel.name, skel.get_bone_count(), skel.motion_scale])
		for i in skel.get_bone_count():
			var rest := skel.get_bone_global_rest(i)
			print("  [%2d] %-24s parent=%2d rest_global=%s" % [i, skel.get_bone_name(i),
				skel.get_bone_parent(i), rest.origin.snappedf(0.001)])
	node.free()


func _dump(node: Node, depth: int) -> void:
	var extra := ""
	if node is Node3D:
		extra = " xf_scale=%s pos=%s" % [(node as Node3D).scale.snappedf(0.001),
			(node as Node3D).position.snappedf(0.001)]
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		extra += " mesh surfaces=%d skin=%s" % [mi.mesh.get_surface_count() if mi.mesh else 0, mi.skin != null]
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				extra += " | mat%d=%s" % [s, m.resource_name if m else "нет"]
	print("%s- %s (%s)%s" % ["  ".repeat(depth), node.name, node.get_class(), extra])
	for c in node.get_children():
		_dump(c, depth + 1)


func _find_skel(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find_skel(c)
		if f:
			return f
	return null
