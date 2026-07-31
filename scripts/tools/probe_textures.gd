extends SceneTree
## Промер текстур дома: какие PNG реально грузятся, а какие возвращают null.
## godot --headless --path . -s res://scripts/tools/probe_textures.gd

func _init() -> void:
	var dir := DirAccess.open("res://assets/textures/house")
	if dir == null:
		print("нет папки")
		quit(1)
		return
	dir.list_dir_begin()
	var bad := 0
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".png"):
			var t: Texture2D = load("res://assets/textures/house/" + f)
			if t == null:
				print("NULL     ", f)
				bad += 1
			else:
				print("ok %dx%d  %s" % [t.get_width(), t.get_height(), f])
		f = dir.get_next()
	print("битых: ", bad)
	quit(0)
