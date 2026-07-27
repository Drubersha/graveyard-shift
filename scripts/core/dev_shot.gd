extends Node
## Автолоад для автопроверок. Аргументы после "--" в командной строке:
##   --smoke=N        — прокрутить N кадров и выйти (headless-проверка на ошибки)
##   --shot=path.png  — на кадре 90 сохранить скриншот и выйти
##   --selftest       — прогнать скриптованный интеграционный тест (см. selftest.gd)

var _shot_path := ""
var _quit_frame := -1
var _frame := 0
var _teleport := Vector3.INF  # --tp=x,y,z — телепорт игрока перед скриншотом
var _loc := ""                # --loc=indoor — переключить локацию перед скриншотом
var _first_person := false    # --fpv — снимать от первого лица

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
			_quit_frame = 90
		elif arg.begins_with("--smoke="):
			_quit_frame = int(arg.trim_prefix("--smoke="))
		elif arg.begins_with("--loc="):
			_loc = arg.trim_prefix("--loc=")
		elif arg.begins_with("--tp="):
			var parts := arg.trim_prefix("--tp=").split(",")
			if parts.size() == 3:
				_teleport = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		elif arg == "--fpv":
			_first_person = true
		elif arg == "--selftest":
			var st := load("res://scripts/core/selftest.gd")
			if st:
				var node: Node = (st as GDScript).new()
				add_child.call_deferred(node)
	if _loc != "" and _shot_path != "":
		_quit_frame = 170

func _process(_delta: float) -> void:
	if _quit_frame < 0:
		return
	_frame += 1
	if _frame == 8 and _loc != "" and Game.main_node:
		Game.main_node.switch_location(_loc)
	var tp_frame := 110 if _loc != "" else 5
	if _frame == tp_frame and _teleport != Vector3.INF and is_instance_valid(Game.player_skeleton):
		var skel := Game.player_skeleton as SkeletonPlayer
		if skel.state == SkeletonPlayer.State.SHATTERED:
			skel.force_reassemble()
		skel.global_position = _teleport
		if _first_person and Game.camera_rig:
			(Game.camera_rig as CameraRig).toggle_view()
	if _frame >= _quit_frame:
		if _shot_path != "":
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("shot saved: ", _shot_path)
		print("devshot: done after ", _frame, " frames")
		get_tree().quit()
