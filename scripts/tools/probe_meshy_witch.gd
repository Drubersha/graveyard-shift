extends SceneTree
## Промер модели ведьмы Meshy: габариты в игровом масштабе, имена костей,
## позиция таза и колена в позе, а также список анимаций.
## godot --headless --path . -s res://scripts/tools/probe_meshy_witch.gd

const SCALE := 1.0   # масштаб теперь в настройках импорта (nodes/root_scale)
const FILES := {
	"idle": "res://assets/models/137_Witch_Idle.glb",
	"sit": "res://assets/models/138_Witch_Sit.glb",
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	for key: String in FILES:
		var ps: PackedScene = load(FILES[key])
		if ps == null:
			print(key, ": НЕ ЗАГРУЗИЛАСЬ ", FILES[key])
			continue
		var root := ps.instantiate() as Node3D
		root.scale = Vector3.ONE * SCALE
		get_root().add_child(root)
		var anim := _find(root, "AnimationPlayer") as AnimationPlayer
		var skel := _find(root, "Skeleton3D") as Skeleton3D
		print("=== ", key, " ===")
		if anim:
			var names := anim.get_animation_list()
			print("  анимации: ", ", ".join(names))
			if names.size() > 0:
				var a := anim.get_animation(names[0])
				a.loop_mode = Animation.LOOP_LINEAR
				anim.play(names[0])
				anim.advance(1.0)   # уводим из T-позы в реальный кадр
		if skel == null:
			print("  Skeleton3D не найден")
			root.queue_free()
			continue
		print("  костей: ", skel.get_bone_count())
		var interesting: Array[String] = []
		for i in skel.get_bone_count():
			var n := skel.get_bone_name(i)
			var low := n.to_lower()
			if low.contains("hip") or low.contains("pelvis") or low.contains("head") \
					or low.contains("spine") or (low.contains("leg") and not low.contains("up")):
				interesting.append("%s[%d]" % [n, i])
		print("  ключевые кости: ", ", ".join(interesting))
		# позиция кости в системе самой модели, уже в игровых метрах
		for bone_name in ["Hips", "Head", "LeftLeg", "LeftUpLeg"]:
			var idx := skel.find_bone(bone_name)
			if idx >= 0:
				var local := skel.get_bone_global_pose(idx).origin
				print("    %s -> в модели %s | в метрах %s"
					% [bone_name, local.snappedf(0.0001), (local * SCALE).snappedf(0.001)])
		var mi := _find(root, "MeshInstance3D") as MeshInstance3D
		if mi and mi.mesh:
			for si in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(si)
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					print("  материал[%d]: %s | прозрачность=%d | альбедо=%s | текстура=%s | cull=%d"
						% [si, sm.resource_name, sm.transparency, sm.albedo_color,
						"есть" if sm.albedo_texture else "НЕТ", sm.cull_mode])
				else:
					print("  материал[%d]: %s" % [si, mat])
		var aabb := _aabb(root, Transform3D.IDENTITY)
		print("  габариты (масштаб %d): %s, низ Y = %.3f" % [SCALE, aabb.size.snappedf(0.001), aabb.position.y])
		root.queue_free()
	quit(0)

func _find(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for c in node.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null

func _aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var local := xf
	if node is Node3D:
		local = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = local * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in node.get_children():
		var sub := _aabb(c, local)
		if sub.size.length_squared() > 0.000001:
			result = result.merge(sub) if has else sub
			has = true
	return result
