extends Node
## Промер посадки на мебель: что нашла ModelLib.seat_spot по геометрии дивана и
## где в итоге оказался таз сидящей ведьмы.
##
## Нужен потому, что «на глаз сидит» — это ровно то, чем прежняя посадка и жила:
## маркер стоял на подобранном z=8.55, а диван при HOUSE_SCALE занимает 8.695..9.890,
## и ведьма висела на 14 см впереди переднего среза.
##
##   godot --headless --path . -- --seatprobe

var _frames := 0
var _step := 0
var _wait := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 3000:
		print("SEATPROBE: таймаут")
		get_tree().quit(1)
		return
	if _wait > 0:
		_wait -= 1
		return
	match _step:
		0:
			if Game.main_node == null:
				return
			Game.main_node.switch_location("indoor")
			_wait = 120
			_step = 1
		1:
			var m := get_tree().get_first_node_in_group("mansion") as Mansion
			if m == null or m.mode != "interior":
				print("SEATPROBE: интерьер не загрузился")
				get_tree().quit(1)
				return
			_report(m)
			get_tree().quit(0)


func _report(m: Mansion) -> void:
	print("SEATPROBE: старт")
	var box := ModelLib.merged_aabb(m.couch_body)
	var lb := ModelLib.local_aabb(m.couch_body)
	var tris := ModelLib.local_faces(m.couch_body)
	print("--- диван Couch_Large1")
	print("  AABB в системе особняка: x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % [
		box.position.x, box.end.x, box.position.y, box.end.y, box.position.z, box.end.z])
	print("  AABB в осях модели:      z %.3f..%.3f, высота %.3f" % [
		lb.position.z, lb.end.z, lb.size.y])
	print("  треугольников для скана: %d" % (tris.size() / 3))
	# сырой профиль опоры по глубине — по нему видно, где подушка, а где спинка
	var ceil_y := lb.position.y + lb.size.y * 0.62
	var cx := lb.position.x + lb.size.x * 0.5
	var line := []
	for i in 21:
		var z := lerpf(lb.position.z, lb.end.z, float(i) / 20.0)
		var y := ModelLib.surface_y(tris, cx, z, ceil_y)
		var yall := ModelLib.surface_y(tris, cx, z, INF)
		line.append("z=%.2f y=%s(всё %s)" % [z,
			("нет" if y == -INF else "%.3f" % y), ("нет" if yall == -INF else "%.3f" % yall)])
	print("  профиль опоры при x=%.2f, потолок %.3f:" % [cx, ceil_y])
	for s in line:
		print("    " + s)
	var pl := ModelLib.seat_plateau(m.couch_body)
	print("  площадка сиденья: ok=%s  верх y=%.3f  глубина z %.3f..%.3f  открыта снизу=%s" % [
		pl["ok"], pl["y"], pl["lo"], pl["hi"], pl["open_low"]])
	print("  seat_spot: точка %s, поворот %.1f, запас до края %.3f, глубина %.3f" % [
		(m.couch_seat["point"] as Vector3).snappedf(0.001), m.couch_seat["yaw"],
		m.couch_seat["front_clear"], m.couch_seat["depth"]])
	print("  маркер: %s поворот %s" % [
		m.couch_marker.position.snappedf(0.001), m.couch_marker.rotation_degrees])
	print("--- ведьма")
	var w := m.witch
	if w == null or not is_instance_valid(w):
		print("  ведьмы нет")
		return
	# Особняк смещён (MANSION_POS), поэтому таз переводим в систему особняка —
	# в ней же лежат AABB дивана и маркер, иначе сравнение бессмысленно.
	var hips := m.to_local(w.hips_bone_world_position())
	var cushion: float = m.couch_seat["cushion_y"]
	print("  корень %s, поза «%s»" % [m.to_local(w.global_position).snappedf(0.001), w.state])
	print("  таз (кость Hips) %s" % hips.snappedf(0.001))
	print("  низ таза y=%.3f, верх подушки y=%.3f, зазор %+.4f м" % [
		hips.y - WitchNPC.PELVIS_HALF_H, cushion,
		hips.y - WitchNPC.PELVIS_HALF_H - cushion])
	print("  передний срез дивана z=%.3f, передняя точка таза z=%.3f, запас %+.3f м" % [
		box.position.z, hips.z - WitchNPC.PELVIS_HALF_Z,
		hips.z - WitchNPC.PELVIS_HALF_Z - box.position.z])
	print("  задний срез дивана  z=%.3f, задняя точка таза  z=%.3f, запас %+.3f м" % [
		box.end.z, hips.z + WitchNPC.PELVIS_HALF_Z,
		box.end.z - (hips.z + WitchNPC.PELVIS_HALF_Z)])
	_check_other_furniture(m)


## ПРОВЕРКА ОБОБЩЕНИЯ, А НЕ ОДНОГО ДИВАНА. Правка, которая работает только на
## Couch_Large1, ничем не лучше подобранного числа: то же самое повторится на
## следующей мебели. В той же гостиной стоят ещё две модели — из ДРУГОГО пака
## (FURN_SCALE вместо HOUSE_SCALE) и развёрнутые на ±90. Если на них площадка
## находится и открытая сторона смотрит наружу, значит считается геометрия, а не
## угаданная ориентация.
func _check_other_furniture(m: Mansion) -> void:
	print("--- та же логика на другой мебели (другой пак, поворот ±90)")
	var probe := Node3D.new()
	m.add_child(probe)
	for row in [["SofaDouble", Vector3(-8.4, Mansion.F2, 8.4), -90.0],
			["SofaLong", Vector3(-14.2, Mansion.F2, 7.0), 90.0],
			["CoffeeTable", Vector3(-12.6, Mansion.F2, 6.6), 0.0]]:
		var body := ModelLib.solid(probe, row[0] as String, row[1] as Vector3,
			row[2] as float, ModelLib.FURN_SCALE)
		var lb := ModelLib.local_aabb(body)
		var pl := ModelLib.seat_plateau(body)
		var spot := ModelLib.seat_spot(body, WitchNPC.PELVIS_HALF_Z, WitchNPC.THIGH_LEN)
		print("  %-12s поворот %+5.0f  габарит модели X=%.3f Y=%.3f Z=%.3f" % [
			row[0], row[2] as float, lb.size.x, lb.size.y, lb.size.z])
		print("      площадка ok=%s верх(лок) y=%.3f глубина %.3f открыта снизу=%s" % [
			pl["ok"], pl["y"], float(pl["hi"]) - float(pl["lo"]), pl["open_low"]])
		print("      посадка %s, смотреть %.0f, высота подушки %.3f (пол %.2f)" % [
			(spot["point"] as Vector3).snappedf(0.001), spot["yaw"],
			float(spot["cushion_y"]) - Mansion.F2, Mansion.F2])
		print("      треугольников %d, ось глубины %s%s" % [
			ModelLib.local_faces(body).size() / 3,
			"X" if int(pl["axis"]) == 0 else "Z",
			"" if bool(pl["ok"]) else "  (спинка не найдена — сиденьем НЕ считается)"])
	probe.queue_free()
