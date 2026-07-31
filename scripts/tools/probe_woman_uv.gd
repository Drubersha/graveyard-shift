extends SceneTree
## Разбор Animated Woman: какая полоса палитры LightSkin.png на какую часть тела села.
## Текстура 32x32 — шесть горизонтальных полос-свотчей. Меряем bbox вершин,
## попавших в каждую полосу, в МЕТРАХ (скелетные юниты * MODEL_SCALE).
##
##   godot --headless --path . -s res://scripts/tools/probe_woman_uv.gd

const PATH := "res://assets/ext/woman/Animated Woman.fbx"
const SCALE := 0.35


func _init() -> void:
	var node: Node = (load(PATH) as PackedScene).instantiate()
	var mi := _find_mesh(node)
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	print("вершин %d, uv %d" % [verts.size(), uvs.size()])
	# У скиненного меша сырые вершины лежат в пространстве привязки и в метрах
	# ничего не значат. Регион определяем по ДОМИНИРУЮЩЕЙ кости — это однозначно.
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skel := _find_skel(node)
	var per_vertex := bones.size() / verts.size()
	var bands := {}
	for i in verts.size():
		var band := int(clampf(uvs[i].y, 0.0, 0.999) * 32.0)
		var best := 0
		var best_w := -1.0
		for j in per_vertex:
			if weights[i * per_vertex + j] > best_w:
				best_w = weights[i * per_vertex + j]
				best = bones[i * per_vertex + j]
		if not bands.has(band):
			bands[band] = {}
		var d: Dictionary = bands[band]
		var bn := skel.get_bone_name(best)
		d[bn] = int(d.get(bn, 0)) + 1
	var keys := bands.keys()
	keys.sort()
	for k: int in keys:
		var d: Dictionary = bands[k]
		var pairs := []
		for bn: String in d:
			pairs.append([int(d[bn]), bn])
		pairs.sort_custom(func(a, b): return a[0] > b[0])
		var top := []
		for p in pairs.slice(0, 8):
			top.append("%s:%d" % [p[1], p[0]])
		print("  строка %2d (v=%.3f): %s" % [k, (float(k) + 0.5) / 32.0, ", ".join(top)])

	# Габариты тела в МЕТРАХ и в игровых осях: под них шьётся одежда.
	# Скиненные вершины лежат в пространстве привязки — разворачиваем через
	# bind pose скина и позу покоя костей, иначе цифры бессмысленны.
	var skin := mi.skin
	var binds := {}
	for i in skin.get_bind_count():
		var bi := skin.get_bind_bone(i)
		if bi < 0:
			bi = skel.find_bone(skin.get_bind_name(i))
		binds[i] = skel.get_bone_global_rest(bi) * skin.get_bind_pose(i)
	var groups := {}
	for i in verts.size():
		var p := Vector3.ZERO
		var wsum := 0.0
		for j in per_vertex:
			var w := weights[i * per_vertex + j]
			if w <= 0.0:
				continue
			p += (binds[bones[i * per_vertex + j]] as Transform3D) * verts[i] * w
			wsum += w
		if wsum > 0.0:
			p /= wsum
		# скелет: X вбок, Y вперёд-назад, Z вверх -> игра: (x, z, -y), в метрах
		var g := Vector3(p.x, p.z, -p.y) * SCALE
		var best := 0
		var best_w := -1.0
		for j in per_vertex:
			if weights[i * per_vertex + j] > best_w:
				best_w = weights[i * per_vertex + j]
				best = bones[i * per_vertex + j]
		var bn := skel.get_bone_name(best)
		if not groups.has(bn):
			groups[bn] = AABB(g, Vector3.ZERO)
		else:
			groups[bn] = (groups[bn] as AABB).expand(g)
	print("\nгабариты по костям, МЕТРЫ, игровые оси (X вбок, Y вверх, Z вперёд-назад):")
	for bn: String in ["Head", "Neck", "Spine2", "Spine1", "Spine", "Hips",
			"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftArm", "LeftForeArm", "LeftHand", "RightHand"]:
		if not groups.has(bn):
			continue
		var a: AABB = groups[bn]
		print("  %-12s X %.3f..%.3f | Y %.3f..%.3f | Z %.3f..%.3f" % [bn,
			a.position.x, a.end.x, a.position.y, a.end.y, a.position.z, a.end.z])
	var whole := AABB()
	var first := true
	for bn: String in groups:
		whole = groups[bn] if first else whole.merge(groups[bn])
		first = false
	print("  ВСЯ МОДЕЛЬ  X %.3f..%.3f | Y %.3f..%.3f | Z %.3f..%.3f" % [
		whole.position.x, whole.end.x, whole.position.y, whole.end.y, whole.position.z, whole.end.z])
	node.free()
	quit(0)


func _find_skel(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find_skel(c)
		if f:
			return f
	return null


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var f := _find_mesh(c)
		if f:
			return f
	return null
