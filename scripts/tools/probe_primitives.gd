extends SceneTree
## Ищет модели с не-треугольными поверхностями: такие меши валят рендер
## ошибкой «Vertex amount must be a multiple of 3» на каждом кадре.
## godot --headless --path . -s res://scripts/tools/probe_primitives.gd

func _init() -> void:
	var dir := DirAccess.open("res://assets/models")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".glb"):
			var ps: PackedScene = load("res://assets/models/" + f)
			if ps:
				var node := ps.instantiate()
				_check(node, f)
				node.free()
		f = dir.get_next()
	print("готово")
	quit(0)

func _check(node: Node, file: String) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for i in mesh.get_surface_count():
				var prim: int = mesh.surface_get_primitive_type(i)
				if prim != Mesh.PRIMITIVE_TRIANGLES:
					print("%s: поверхность %d — примитив %d (НЕ треугольники), вершин %d"
						% [file, i, prim, mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX].size()])
	for c in node.get_children():
		_check(c, file)
