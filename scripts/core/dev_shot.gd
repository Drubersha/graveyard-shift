extends Node
## Автолоад для автопроверок. Аргументы после "--" в командной строке:
##   --smoke=N        — прокрутить N кадров и выйти (headless-проверка на ошибки)
##   --shot=path.png  — на кадре 90 сохранить скриншот и выйти
##   --selftest       — прогнать скриптованный интеграционный тест (см. selftest.gd)

var _shot_path := ""
var _quit_frame := -1
var _frame := 0
var _teleport := Vector3.INF  # --tp=x,y,z — телепорт игрока перед скриншотом

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
			_quit_frame = 90
		elif arg.begins_with("--smoke="):
			_quit_frame = int(arg.trim_prefix("--smoke="))
		elif arg.begins_with("--tp="):
			var parts := arg.trim_prefix("--tp=").split(",")
			if parts.size() == 3:
				_teleport = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		elif arg == "--selftest":
			var st := load("res://scripts/core/selftest.gd")
			if st:
				var node: Node = (st as GDScript).new()
				add_child.call_deferred(node)

func _process(_delta: float) -> void:
	if _quit_frame < 0:
		return
	_frame += 1
	if _frame == 5 and _teleport != Vector3.INF and is_instance_valid(Game.player_skeleton):
		Game.player_skeleton.global_position = _teleport
	if _frame >= _quit_frame:
		if _shot_path != "":
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("shot saved: ", _shot_path)
		print("devshot: done after ", _frame, " frames")
		get_tree().quit()
