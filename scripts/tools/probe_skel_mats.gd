extends SceneTree
## Разовая проверка: доехали ли имена материалов и emissiveFactor из Blender
## в импортированные Skeleton_*_own.gltf, и что даёт BoneParts.reskin().
## Запуск:
##   godot --headless --path . -s res://scripts/tools/probe_skel_mats.gd

func _init() -> void:
	for id: String in BoneParts.IDS:
		var path: String = BoneParts.MODEL_DIR + str(BoneParts.MODEL[id])
		if not ResourceLoader.exists(path):
			print(id, ": НЕТ ФАЙЛА ", path)
			continue
		var inst: Node = (load(path) as PackedScene).instantiate()
		print("--- ", id)
		_walk(inst)
	quit()

func _walk(n: Node) -> void:
	var mi := n as MeshInstance3D
	if mi and mi.mesh:
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var nm := m.resource_name if m else "<нет>"
			var kind := MeshLib.skel_kind_for(nm)
			var emi := m.emission if m and m.emission_enabled else Color.BLACK
			print("  #%d name=%-14s kind=%-6s albedo=%s emission=%s" % [
				i, nm, kind, str(m.albedo_color) if m else "-", str(emi)])
	for c in n.get_children():
		_walk(c)
