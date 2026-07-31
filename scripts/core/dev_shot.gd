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
var _yaw := INF               # --yaw=градусы — повернуть камеру для скриншота
## Свободная камера для приёмки: --cam=x,y,z ставит камеру в точку,
## --look=x,y,z направляет её. Орбитальный риг при этом отключается.
var _cam_pos := Vector3.INF
var _cam_look := Vector3.INF
var _cam_fov := 0.0           # --fov=градусы
## Камера ОТНОСИТЕЛЬНО игрока: --camrel=dx,dy,dz и --lookrel=dx,dy,dz.
## У особняка свой трансформ, и абсолютные координаты для интерьера подбирать
## бессмысленно — один и тот же крупный план черепа должен сниматься одной
## строкой в любой локации. Скелет смотрит в -Z, поэтому лицо снимается
## отрицательным dz.
var _cam_rel := Vector3.INF
var _look_rel := Vector3.INF
var _shatter := false         # --shatter — рассыпать скелет после телепорта
var _detach := ""             # --detach=arm_l — оторвать одну деталь после телепорта
## --nohud — убрать интерфейс с кадра. Приёмочные снимки скелета нужны чистыми:
## подсказки и панель управления перекрывают ровно ту часть кадра, где череп.
var _nohud := false
## --witchstate=walk — включить ведьме состояние из WitchNPC.STATES перед снимком.
## Нужно, чтобы крепления шляпы, волос и метлы проверялись кадрами в РАЗНЫХ позах,
## а не только в той, в которой её ставит миссия.
var _witch_state := ""
var _witch_done: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # переживать паузу мини-игр
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
		elif arg.begins_with("--yaw="):
			_yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))
		elif arg.begins_with("--cam="):
			_cam_pos = _vec3(arg.trim_prefix("--cam="))
		elif arg.begins_with("--look="):
			_cam_look = _vec3(arg.trim_prefix("--look="))
		elif arg.begins_with("--camrel="):
			_cam_rel = _vec3(arg.trim_prefix("--camrel="))
		elif arg.begins_with("--lookrel="):
			_look_rel = _vec3(arg.trim_prefix("--lookrel="))
		elif arg.begins_with("--fov="):
			_cam_fov = float(arg.trim_prefix("--fov="))
		elif arg == "--fpv":
			_first_person = true
		elif arg == "--nohud":
			_nohud = true
		elif arg == "--shatter":
			_shatter = true
		elif arg.begins_with("--detach="):
			_detach = arg.trim_prefix("--detach=")
		elif arg.begins_with("--minigame="):
			var mg := load("res://scripts/tools/shot_minigame.gd")
			if mg:
				var node: Node = (mg as GDScript).new()
				node.call("setup", arg.trim_prefix("--minigame="))
				add_child.call_deferred(node)
		elif arg.begins_with("--witchstate="):
			# для приёмки: снять накладки ведьмы в любой поддержанной позе
			_witch_state = arg.trim_prefix("--witchstate=")
		elif arg == "--witchprobe":
			# численный промер крепления накладок ведьмы к костям (scripts/tools/probe_witch.gd)
			var wp := load("res://scripts/tools/probe_witch.gd")
			if wp:
				add_child.call_deferred((wp as GDScript).new())
		elif arg == "--seatprobe":
			# численный промер посадки на диван (scripts/tools/probe_seat.gd)
			var sp := load("res://scripts/tools/probe_seat.gd")
			if sp:
				add_child.call_deferred((sp as GDScript).new())
		elif arg == "--selftest":
			var st := load("res://scripts/core/selftest.gd")
			if st:
				var node: Node = (st as GDScript).new()
				add_child.call_deferred(node)
	if _loc != "" and _shot_path != "":
		_quit_frame = 170
	if (_shatter or _detach != "") and _quit_frame > 0:
		_quit_frame += 100          # дать костям упасть и успокоиться

func _process(_delta: float) -> void:
	if _quit_frame < 0:
		return
	_frame += 1
	# Каждый кадр, а не один раз: смена локации пересоздаёт интерфейс, и
	# спрятанный на старте HUD к моменту снимка снова оказывался бы на экране.
	if _nohud:
		for node in get_tree().get_nodes_in_group("hud"):
			var cl := node as CanvasLayer
			if cl:
				cl.visible = false
	if _frame == 8 and _loc != "" and Game.main_node:
		Game.main_node.switch_location(_loc)
	# Каждый кадр, а не один раз: ведьма появляется не сразу после смены локации,
	# а миссия может переставить ей позу уже после старта.
	if _witch_state != "":
		for node in get_tree().get_nodes_in_group("interactable"):
			var w := node as WitchNPC
			if w == null or _witch_done.has(w.get_instance_id()):
				continue
			# ровно одна попытка на ведьму: у неподдержанного состояния set_state
			# честно возвращает false и пишет предупреждение, и без этой отметки
			# оно сыпалось бы в консоль каждый кадр
			_witch_done[w.get_instance_id()] = true
			w.set_state(_witch_state)
	var tp_frame := 110 if _loc != "" else 5
	# Сборка вынесена из-под условия на --tp: игра начинается с пролога, где
	# скелет лежит кучей, и снимок без телепорта (например «встань где стоишь,
	# но в особняке») до сих пор приходил на россыпь костей вместо скелета.
	if _frame == tp_frame and is_instance_valid(Game.player_skeleton):
		var skel := Game.player_skeleton as SkeletonPlayer
		if skel.state == SkeletonPlayer.State.SHATTERED:
			skel.force_reassemble()
		if _teleport != Vector3.INF:
			skel.global_position = _teleport
		var rig := Game.camera_rig as CameraRig
		if rig and _yaw != INF:
			rig.yaw = _yaw
		if _first_person and rig:
			rig.toggle_view()
	if _frame == tp_frame + 4 and is_instance_valid(Game.player_skeleton) \
			and (_shatter or _detach != ""):
		var s := Game.player_skeleton as SkeletonPlayer
		if _detach != "":
			s.detach_part(_detach, Vector3(0.6, 0.2, -0.8))
		else:
			s.shatter(Vector3.UP)
	# Относительная камера пересчитывается КАЖДЫЙ кадр: после телепорта скелет
	# ещё оседает на пол, и снятая один раз позиция промахивалась бы по высоте.
	if _frame >= tp_frame and _cam_rel != Vector3.INF and is_instance_valid(Game.player_skeleton):
		var pn := Game.player_skeleton as Node3D
		var base := pn.global_position
		# Смещение задаётся в СИСТЕМЕ СКЕЛЕТА, а не мира: в особняке он стоит с
		# другим поворотом, и мировой «-Z» приходился ему в бок. Теперь
		# --camrel=0,1.6,-0.7 значит «0.7 м перед лицом» в любой локации.
		var b := pn.global_transform.basis.orthonormalized()
		_cam_pos = base + b * _cam_rel
		_cam_look = base + b * (_look_rel if _look_rel != Vector3.INF else Vector3.ZERO)
	if _frame >= tp_frame and _cam_pos != Vector3.INF:
		_place_freecam()
	if _frame >= _quit_frame:
		if is_instance_valid(Game.player_skeleton):
			print("player at ", (Game.player_skeleton as Node3D).global_position)
		if _shot_path != "":
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			print("shot saved: ", _shot_path)
		print("devshot: done after ", _frame, " frames")
		get_tree().quit()

static func _vec3(s: String) -> Vector3:
	var parts := s.split(",")
	if parts.size() != 3:
		return Vector3.INF
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

## Свободная камера приёмки: отдельный Camera3D поверх орбитального рига.
var _free_cam: Camera3D = null

func _place_freecam() -> void:
	if _free_cam == null:
		_free_cam = Camera3D.new()
		get_tree().root.add_child(_free_cam)
		if _cam_fov > 0.0:
			_free_cam.fov = _cam_fov
	_free_cam.global_position = _cam_pos
	if _cam_look != Vector3.INF and _cam_look.distance_to(_cam_pos) > 0.001:
		_free_cam.look_at(_cam_look, Vector3.UP)
	_free_cam.current = true
