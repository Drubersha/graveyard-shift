extends Node
## Интеграционный самотест (запуск: godot --headless --path . -- --selftest).
## Скриптованными инпутами и прямыми манипуляциями проверяет: ходьбу, отрыв руки,
## ползание, возврат в тело, бросок черепа + сборку, ломаемые пропсы,
## веник+пыль, мойку посуды, плиту (завтрак) и зону подачи.

var _step := 0
var _frames := 0
var _wait := 0
var _errors: PackedStringArray = []
var _skel: SkeletonPlayer
var _mark := Vector3.ZERO
var _mess_before := 0
var _mansion: Mansion
var _dust_ok := false
var _serve_ok := false
var _sink_plate: BreakableProp
var _pile_origin := Vector3.ZERO
## Куча, а не взрыв: критик мерил разлёт в три метра. Порог с запасом — при
## нынешних импульсах (±0.8 вбок, 0.6..1.5 вверх) детали ложатся в пределах
## метра с небольшим, а прежние ±2.5/4.2 давали втрое больше и сюда не влезут.
const PILE_RADIUS_MAX := 1.8

func _ready() -> void:
	# мини-игры ставят дерево на паузу — тест должен продолжать тикать
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("SELFTEST: старт")

## Ведьма на диване: накладки должны сидеть на КОСТЯХ, а не на фиксированной
## высоте. Раньше шляпа висела на 1.58 от корня, и в сидячей позе оставалась в
## воздухе над головой. Меряем расстояние шляпа-кость прямо в сидячей позе —
## если крепление снова прибьют гвоздями, тест это увидит.
const HAT_TO_HEAD_MAX := 0.32

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect_meshes(c, out)

func _check_witch() -> void:
	var w: WitchNPC = null
	if _mansion:
		w = _mansion.witch
	if w == null or not is_instance_valid(w):
		_fail("ведьмы нет в интерьере")
		return
	if w.state != "sit":
		_fail("ведьма в интерьере в состоянии «%s», а должна сидеть" % w.state)
	# модель должна быть не только «в наличии», но и реально видимой в кадре
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(w, meshes)
	if meshes.is_empty():
		_fail("у ведьмы нет ни одного MeshInstance3D — модель не видна")
	else:
		var box := ModelLib.merged_aabb(w)
		var hidden := 0
		for m in meshes:
			if not m.is_visible_in_tree():
				hidden += 1
		var mesh_box := ModelLib.merged_aabb(meshes[0])
		print("SELFTEST ведьма: мешей %d (скрыто %d) | узел в %s | AABB(w) %s+%s | AABB(меш) %s+%s | scale %s"
			% [meshes.size(), hidden, w.global_position.snappedf(0.01),
			box.position.snappedf(0.01), box.size.snappedf(0.01),
			mesh_box.position.snappedf(0.01), mesh_box.size.snappedf(0.01),
			meshes[0].global_transform.basis.get_scale().snappedf(0.001)])
		# рост меряем по костям: у скинованной модели AABB меша не отражает кадр
		var h := w.height()
		if hidden == meshes.size():
			_fail("все меши ведьмы скрыты")
		elif h < 1.2 or h > 2.2:
			_fail("ведьма не человеческого роста: %.2f м по костям" % h)
		else:
			_ok("модель ведьмы видима, рост %.2f м" % h)
		# «сидит задом»: узел повёрнут верно, а меш внутри — наоборот. Ловим по
		# кости лица: headfront обязан быть с той же стороны, куда смотрит узел.
		var face_dot := w.model_face_dir().dot(-w.global_transform.basis.z)
		if face_dot > 0.5:
			_ok("модель смотрит туда же, куда узел (dot %.2f)" % face_dot)
		else:
			_fail("модель развёрнута задом к направлению узла (dot %.2f)" % face_dot)
	var d := w.hat_world_position().distance_to(w.head_bone_world_position())
	if d > HAT_TO_HEAD_MAX:
		_fail("шляпа оторвалась от головы: %.2f м до кости в позе «%s»" % [d, w.state])
	else:
		_ok("шляпа сидит на кости головы: %.2f м в позе «%s»" % [d, w.state])
	if w.broom_visible():
		_fail("метла осталась в руке сидящей ведьмы")
	else:
		_ok("метла исчезает при сидении")
	_check_seat(w)
	if not w.set_state("stand"):
		_fail("состояние «stand» не включилось")
	var d2 := w.hat_world_position().distance_to(w.head_bone_world_position())
	if d2 > HAT_TO_HEAD_MAX:
		_fail("шляпа оторвалась от головы стоя: %.2f м" % d2)
	if w.set_state("fly_broom"):
		_fail("состояние «fly_broom» включилось — анимации полёта в паке нет, "
			+ "его нельзя выдавать за сделанное")
	else:
		_ok("несуществующие позы (полёт, лежание) честно отказываются включаться")
	w.set_state("sit")

## Ведьма должна сидеть НА ДИВАНЕ, а не перед ним. Проверяется ровно тот дефект,
## который был: маркер стоял на подобранном z=8.55, диван при HOUSE_SCALE занимает
## 8.695..9.890, и таз оказался на 14 см впереди переднего среза — под ним был
## виден паркет. Меряем по фактическому AABB дивана и фактической кости Hips в
## сидячей позе, а числа печатаем: подгонка одной константы этот тест не пройдёт.
const SEAT_GAP_MAX := 0.02      # низ таза над подушкой: щель или утопание в ткань

func _check_seat(w: WitchNPC) -> void:
	if _mansion.couch_body == null or not is_instance_valid(_mansion.couch_body):
		_fail("дивана в гостиной нет — посадку не от чего считать")
		return
	if not bool(_mansion.couch_seat.get("ok", false)):
		_fail("ModelLib.seat_spot не нашёл подушку по геометрии дивана: %s" % [_mansion.couch_seat])
		return
	var box := ModelLib.merged_aabb(_mansion.couch_body)
	# всё в системе особняка: он смещён, и мировые координаты тут ни с чем не сходятся
	var hips := _mansion.to_local(w.hips_bone_world_position())
	var cushion: float = _mansion.couch_seat["cushion_y"]
	print("SELFTEST диван: AABB z %.3f..%.3f y %.3f..%.3f | подушка y=%.3f | таз %s"
		% [box.position.z, box.end.z, box.position.y, box.end.y, cushion, hips.snappedf(0.001)])
	var gap: float = hips.y - WitchNPC.PELVIS_HALF_H - cushion
	if absf(gap) <= SEAT_GAP_MAX:
		_ok("низ таза лежит на подушке: расхождение %+.4f м (порог %.2f)" % [gap, SEAT_GAP_MAX])
	else:
		_fail("таз не на подушке: низ таза y=%.3f против подушки y=%.3f (%+.3f м)"
			% [hips.y - WitchNPC.PELVIS_HALF_H, cushion, gap])
	# таз целиком над диваном: ни спереди (щель и паркет), ни сзади (в спинке)
	var front := hips.z - WitchNPC.PELVIS_HALF_Z - box.position.z
	var back := box.end.z - (hips.z + WitchNPC.PELVIS_HALF_Z)
	if front > 0.0 and back > 0.0:
		_ok("таз целиком над диваном: %.3f м от переднего среза, %.3f м от заднего" % [front, back])
	else:
		_fail("таз свисает с дивана: запас спереди %+.3f м, сзади %+.3f м "
			% [front, back] + "(передний срез z=%.3f, таз z=%.3f)" % [box.position.z, hips.z])
	# Ноги не должны тонуть в мебели. Мерим по СТУПНЕ, а не по колену: у позы
	# «сидя» колени законно остаются над подушкой (так сидит человек на глубоком
	# диване), а вот стопа обязана либо выйти перед передней плоскостью, либо
	# оказаться ниже подушки — иначе ботинок торчит из обивки.
	var foot := _mansion.to_local(w.foot_bone_world_position())
	if foot.z <= box.position.z + 0.06 or foot.y <= cushion - 0.05:
		_ok("ступня не в обивке: z=%.3f (плоскость %.3f), y=%.3f (подушка %.3f)"
			% [foot.z, box.position.z, foot.y, cushion])
	else:
		_fail("нога тонет в диване: ступня z=%.3f y=%.3f при плоскости z=%.3f и подушке y=%.3f"
			% [foot.z, foot.y, box.position.z, cushion])
	# сидящая смотрит В КОМНАТУ, а не в стену: спинка обязана быть за спиной
	var facing := -(w.global_transform.basis.z)
	var to_open := Vector3(0, 0, box.position.z - hips.z).normalized()
	if facing.dot(to_open) > 0.7:
		_ok("сидит лицом в комнату, спинка за спиной (скалярное %.2f)" % facing.dot(to_open))
	else:
		_fail("сидит не в ту сторону: направление взгляда %s против открытой стороны %s"
			% [facing.snappedf(0.01), to_open.snappedf(0.01)])

func _fail(msg: String) -> void:
	_errors.append("шаг %d: %s" % [_step, msg])
	print("SELFTEST FAIL — ", msg)

func _ok(msg: String) -> void:
	print("SELFTEST ok — ", msg)

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 9000:
		_fail("общий таймаут")
		_finish()
		return
	if _wait > 0:
		_wait -= 1
		return
	match _step:
		0:
			_skel = Game.player_skeleton as SkeletonPlayer
			if not _skel:
				_fail("нет скелета")
				_finish()
				return
			# старт игры — рассыпанным (пролог): ждём сборку
			if _skel.state != SkeletonPlayer.State.SHATTERED:
				if _frames > 300:
					_fail("пролог не рассыпал скелета (state=%d)" % _skel.state)
					_finish()
				return
			_wait = 120
			_step = 40
		40:
			# авто-сборки больше нет: две секунды в куче должны остаться кучей
			if _skel.state != SkeletonPlayer.State.SHATTERED:
				_fail("скелет собрался сам, без R — таймер сборки не убран")
				_finish()
				return
			_ok("сам не собирается: 2 с в куче — всё ещё куча")
			Input.action_press("collapse")
			_wait = 2
			_step = 41
		41:
			Input.action_release("collapse")
			_wait = 60
			_step = 42
		42:
			if _skel.state == SkeletonPlayer.State.ACTIVE and _skel.parts_missing() == 0:
				_ok("R собрал скелета вручную (пролог), все детали на месте")
			else:
				_fail("R не собрал скелета (state=%d, потеряно деталей: %d)" % [_skel.state, _skel.parts_missing()])
			_wait = 10
			_step = 1
		1:
			# чистый участок дорожки двора
			_skel.global_position = Vector3(0, 0.5, -5)
			_mark = _skel.global_position
			Input.action_press("move_forward")
			_wait = 90
			_step = 2
		2:
			Input.action_release("move_forward")
			var moved := _skel.global_position.distance_to(_mark)
			if moved < 2.0:
				_fail("ходьба: сдвинулся всего на %.2f м" % moved)
			else:
				_ok("ходьба: %.1f м" % moved)
			_step = 3
		3:
			Input.action_press("detach_arm")
			_wait = 2
			_step = 4
		4:
			Input.action_release("detach_arm")
			if Game.possessed is DetachedArm:
				_ok("рука оторвана, управление перешло руке")
			else:
				_fail("после F управление не у руки (possessed=%s)" % [Game.possessed])
			_step = 5
		5:
			if Game.camera_target == _skel:
				_ok("камера осталась у черепа: рука управляется удалённо")
			else:
				_fail("камера уехала за рукой (camera_target=%s)" % [Game.camera_target])
			_mark = (Game.possessed as Node3D).global_position
			Input.action_press("move_forward")
			_wait = 60
			_step = 6
		6:
			Input.action_release("move_forward")
			var arm := Game.possessed as Node3D
			var crawled := arm.global_position.distance_to(_mark)
			if crawled < 0.4:
				_fail("рука не ползёт (%.2f м)" % crawled)
			else:
				_ok("рука ползёт: %.1f м" % crawled)
			Input.action_press("switch_body")
			_wait = 2
			_step = 7
		7:
			Input.action_release("switch_body")
			if Game.possessed == _skel:
				_ok("Tab вернул управление телу")
			else:
				_fail("Tab не вернул управление телу (possessed=%s)" % [Game.possessed])
			if is_instance_valid(_skel.arm_entity) and _skel.arm_entity.global_position.distance_to(_skel.global_position) < 2.2:
				_skel.reattach_arm()
			_step = 8
		8:
			Input.action_press("throw_skull")
			_wait = 25
			_step = 9
		9:
			Input.action_release("throw_skull")
			_wait = 5
			_step = 10
		10:
			if not _skel.skull_attached and Game.possessed is SkullEntity and Game.camera_target is SkullEntity:
				_ok("череп снят: камера и управление на нём, тело осталось на ногах")
			else:
				_fail("снятие черепа: attached=%s possessed=%s cam=%s" % [_skel.skull_attached, Game.possessed, Game.camera_target])
			if _skel.state == SkeletonPlayer.State.ACTIVE:
				_ok("безголовое тело живо и управляемо")
			else:
				_fail("тело развалилось при снятии черепа")
			# возвращаем череп на плечи через respawn-кнопку
			Game.main_node.skeleton.respawn_at(_skel.global_position)
			_wait = 5
			_step = 105
		105:
			if _skel.skull_attached and Game.camera_target == _skel and Game.possessed == _skel:
				_ok("H собрал скелета целиком и вернул камеру в череп")
			else:
				_fail("respawn не собрал скелета")
			Input.action_press("collapse")
			_wait = 2
			_step = 106
		106:
			Input.action_release("collapse")
			if _skel.state == SkeletonPlayer.State.SHATTERED and Game.possessed is SkullEntity:
				_ok("R — рассыпание, камера улетела с черепом")
			else:
				_fail("R не рассыпал скелета")
			_pile_origin = _skel.global_position
			_wait = 30
			_step = 107
		107:
			if _skel.state != SkeletonPlayer.State.SHATTERED:
				_fail("скелет собрался сам за полсекунды — авто-сборка не убрана")
			# Разлёт меряем по горизонтали: вверх кости подпрыгивают законно,
			# «взрывом» читается именно то, как далеко они расползлись по полу.
			var spread := 0.0
			for node in get_tree().get_nodes_in_group("bone_part"):
				var bp := node as Node3D
				if not is_instance_valid(bp):
					continue
				var off := bp.global_position - _pile_origin
				spread = maxf(spread, Vector2(off.x, off.z).length())
			if spread <= PILE_RADIUS_MAX:
				_ok("кости легли кучей: разлёт %.2f м (порог %.1f)" % [spread, PILE_RADIUS_MAX])
			else:
				_fail("кости разлетелись на %.2f м — это взрыв, а не куча (порог %.1f)"
					% [spread, PILE_RADIUS_MAX])
			Input.action_press("collapse")   # вторая R — сборка
			_wait = 2
			_step = 108
		108:
			Input.action_release("collapse")
			_mark = Vector3(_frames, 0, 0)
			_step = 11
		11:
			if _skel.state == SkeletonPlayer.State.ACTIVE and Game.possessed == _skel:
				_ok("вторая R стянула кости к черепу за %.1f c" % ((_frames - _mark.x) / 60.0))
				_step = 110
			elif _frames - _mark.x > 240:
				_fail("R не собрала скелета за 4 с")
				_step = 110
		110:
			_skel.respawn_at(Vector3(0, 0.6, -5))
			_wait = 20
			_step = 111
		111:
			_skel.apply_shock(SkeletonPlayer.SHOCK_PART - 2.0, Vector3.UP)
			if _skel.state == SkeletonPlayer.State.ACTIVE and _skel.parts_missing() == 0:
				_ok("слабый удар (%.1f) — ничего не отвалилось" % (SkeletonPlayer.SHOCK_PART - 2.0))
			else:
				_fail("слабый удар оторвал деталь (потеряно %d)" % _skel.parts_missing())
			_skel.apply_shock((SkeletonPlayer.SHOCK_PART + SkeletonPlayer.SHOCK_FULL) * 0.5, Vector3.UP)
			_wait = 5
			_step = 112
		112:
			if _skel.state == SkeletonPlayer.State.ACTIVE and _skel.parts_missing() == 1:
				_ok("средний удар снизу оторвал ровно одну деталь (%s), тело живо"
					% ", ".join(_skel.missing_labels()))
			else:
				_fail("средний удар: state=%d, потеряно деталей %d (ждали ровно 1 и ACTIVE)"
					% [_skel.state, _skel.parts_missing()])
			_mark = _skel.global_position
			Input.action_press("move_forward")
			_wait = 60
			_step = 113
		113:
			Input.action_release("move_forward")
			if _skel.global_position.distance_to(_mark) > 0.8:
				_ok("без детали тело продолжает ходить (%.1f м)" % _skel.global_position.distance_to(_mark))
			else:
				_fail("без детали тело перестало ходить (%.2f м)" % _skel.global_position.distance_to(_mark))
			_skel.apply_shock(SkeletonPlayer.SHOCK_FULL + 2.0, Vector3.UP)
			_wait = 5
			_step = 114
		114:
			if _skel.state == SkeletonPlayer.State.SHATTERED:
				_ok("сильный удар рассыпал целиком")
			else:
				_fail("сильный удар не рассыпал скелета (state=%d)" % _skel.state)
			_wait = 120
			_step = 115
		115:
			if _skel.state == SkeletonPlayer.State.SHATTERED:
				_ok("после удара тоже не собирается сам")
			else:
				_fail("скелет собрался сам после удара — таймер сборки где-то остался")
			Input.action_press("collapse")
			_wait = 2
			_step = 116
		116:
			Input.action_release("collapse")
			_wait = 60
			_step = 117
		117:
			if _skel.state == SkeletonPlayer.State.ACTIVE and _skel.parts_missing() == 0:
				_ok("R вернула все детали на место")
			else:
				_fail("после R не хватает деталей: %d (state=%d)" % [_skel.parts_missing(), _skel.state])
			_step = 12
		12:
			_mess_before = Game.mess_points
			BreakableProp.make(get_tree().current_scene, "vase",
				_skel.global_position + Vector3(1.5, 3.5, 0))
			_wait = 90
			_step = 13
		13:
			if Game.mess_points > _mess_before:
				_ok("ваза разбилась при падении (+%d срача)" % (Game.mess_points - _mess_before))
			else:
				_fail("ваза не разбилась при падении")
			_step = 14
		14:
			_step = 17
		17:
			# веник чистит пыль
			var pos := _skel.global_position + Vector3(2, 0.1, 0)
			var d := DustPatch.make(get_tree().current_scene, pos)
			d.cleaned.connect(func() -> void: _dust_ok = true)
			var b := Broom.new()
			get_tree().current_scene.add_child(b)
			b.global_position = pos + Vector3.UP * 0.5
			_wait = 40
			_step = 18
		18:
			if _dust_ok:
				_ok("веник чистит пыль")
			else:
				_fail("пыль не почистилась веником")
			_step = 19
		19:
			# переключаемся в интерьер особняка (отдельная локация)
			if Game.main_node.location_name != "indoor":
				Game.main_node.switch_location("indoor")
				_wait = 90
				return
			_mansion = get_tree().get_first_node_in_group("mansion") as Mansion
			if not _mansion or _mansion.mode != "interior":
				_fail("интерьер особняка не загрузился")
				_finish()
				return
			_ok("локация переключилась: улица → интерьер")
			_check_witch()
			# мытьё посуды: берём грязную тарелку в руки и открываем мини-игру у мойки
			_sink_plate = BreakableProp.make(get_tree().current_scene, "plate_dirty", Vector3.ZERO)
			# роняем с 0.35 м, а не с метра: с метра тарелка иногда разбивается
			# раньше, чем тест успевает взять её в руки
			_sink_plate.global_position = _skel.global_position + Vector3(0, 0.35, 0)
			_sink_plate.freeze = true   # шаг 195 её всё равно заморозит; так тест не зависит
			                            # от того, разобьётся ли она о пол по дороге
			_wait = 10
			_step = 195
		195:
			# Берём РОВНО тем же путём, что и игрок (_take), а не присваиванием held.
			# Присваивание оставляло carried=false и живой коллайдер: предмет в
			# «руках» продолжал сталкиваться с хозяином, и стоило скорости скелета
			# перевалить порог (у тарелки 2.0 м/с), body_entered разбивал её ещё до
			# мойки. Отсюда и был плавающий провал шага 20 примерно раз в четыре
			# прогона. _take гасит скорость, ставит carried и убирает коллизии.
			_skel._take(_sink_plate)
			_mansion.sink.interact(_skel)
			_wait = 5
			_step = 20
		20:
			var mg := get_tree().current_scene.find_children("", "DishMinigame", true, false)
			if mg.is_empty():
				# Диагностика в самом сообщении: чаще всего мини-игра не открывается
				# не «сама по себе», а потому что тарелки уже нет — разбилась по пути.
				_fail("мини-игра мытья не открылась (тарелка: жива=%s вид=%s разбита=%s в руках=%s)" % [
					is_instance_valid(_sink_plate),
					(_sink_plate.kind if is_instance_valid(_sink_plate) else "-"),
					(_sink_plate.broken if is_instance_valid(_sink_plate) else "-"),
					is_instance_valid(_skel.held)])
				_step = 21
				return
			_ok("мини-игра мытья открылась (тарелка в руках + E у мойки)")
			(mg[0] as DishMinigame).finish_wash()
			_wait = 10
			_step = 205
		205:
			if is_instance_valid(_sink_plate) and _sink_plate.kind == "plate":
				_ok("после мини-игры тарелка чистая и осталась в руках")
			else:
				_fail("тарелка не отмылась в мини-игре")
			# аккуратная кладка: короткий клик должен поставить, а не разбить
			_mess_before = Game.mess_points
			# Берём РОВНО тем же путём, что и игрок (_take), а не присваиванием held.
			# Присваивание оставляло carried=false и живой коллайдер: предмет в
			# «руках» продолжал сталкиваться с хозяином, и стоило скорости скелета
			# перевалить порог (у тарелки 2.0 м/с), body_entered разбивал её ещё до
			# мойки. Отсюда и был плавающий провал шага 20 примерно раз в четыре
			# прогона. _take гасит скорость, ставит carried и убирает коллизии.
			_skel._take(_sink_plate)
			Input.action_press("grab")
			_wait = 2
			_step = 206
		206:
			Input.action_release("grab")
			_wait = 60
			_step = 207
		207:
			if is_instance_valid(_sink_plate) and Game.mess_points == _mess_before:
				_ok("короткий клик кладёт предмет аккуратно, не разбивая")
			else:
				_fail("предмет разбился при аккуратной кладке")
			_step = 21
		21:
			# плита: кладём рецепт аккуратно на поверхность (по top_y) и готовим
			var sp := _mansion.stove.global_position
			var ty: float = _mansion.stove.top_y
			var egg := BreakableProp.make(get_tree().current_scene, "egg", Vector3.ZERO)
			egg.global_position = sp + Vector3(0, ty + 0.1, -0.25)
			var flour := BreakableProp.make(get_tree().current_scene, "flour", Vector3.ZERO)
			flour.global_position = sp + Vector3(0, ty + 0.23, 0)
			var wine := BreakableProp.make(get_tree().current_scene, "bottle", Vector3.ZERO)
			wine.global_position = sp + Vector3(0, ty + 0.17, 0.25)
			_wait = 25
			_step = 22
		22:
			_mansion.stove.interact(null)
			_wait = 5
			_step = 23
		23:
			if is_instance_valid(_mansion.stove._breakfast):
				_ok("плита приготовила завтрак из ингредиентов")
			else:
				_fail("плита не приготовила завтрак")
				print("  DIAG: stove top_y=", _mansion.stove.top_y, " zone_bodies:")
				for b in _mansion.stove._zone.get_overlapping_bodies():
					print("    ", b, " kind=", b.kind if b is BreakableProp else "-", " pos=", (b as Node3D).global_position)
			_step = 24
		24:
			# подача завтрака на диван
			_mansion.serve_zone.served.connect(func() -> void: _serve_ok = true)
			_mansion.serve_zone.active = true
			if is_instance_valid(_mansion.stove._breakfast):
				_mansion.stove._breakfast.global_position = _mansion.serve_zone.global_position + Vector3(0, 0.8, 0)
			_wait = 40
			_step = 25
		25:
			if _serve_ok:
				_ok("завтрак подан, зона у дивана сработала")
			else:
				_fail("зона подачи не приняла завтрак")
			# проверяем спуск в подвал и перенос предмета в руках между локациями
			_sink_plate = BreakableProp.make(get_tree().current_scene, "bottle", Vector3.ZERO)
			_sink_plate.global_position = _skel.global_position + Vector3(0.6, 0.6, 0)
			_wait = 20
			_step = 26
		26:
			# Берём РОВНО тем же путём, что и игрок (_take), а не присваиванием held.
			# Присваивание оставляло carried=false и живой коллайдер: предмет в
			# «руках» продолжал сталкиваться с хозяином, и стоило скорости скелета
			# перевалить порог (у тарелки 2.0 м/с), body_entered разбивал её ещё до
			# мойки. Отсюда и был плавающий провал шага 20 примерно раз в четыре
			# прогона. _take гасит скорость, ставит carried и убирает коллизии.
			_skel._take(_sink_plate)
			Game.main_node.switch_location("cellar", "from_kitchen")
			_wait = 100
			_step = 27
		27:
			var dungeon := get_tree().get_first_node_in_group("dungeon")
			if dungeon:
				_ok("локация переключилась: особняк → подвал")
			else:
				_fail("подвал не загрузился")
			if is_instance_valid(_skel.held) and _skel.held == _sink_plate:
				_ok("предмет в руках переехал вместе с игроком")
			else:
				_fail("предмет в руках потерялся при переходе")
			Game.main_node.switch_location("indoor", "kitchen_door")
			_wait = 90
			_step = 28
		28:
			# спуск по парадной лестнице: ставим на балкон у верхней ступени
			_mansion = get_tree().get_first_node_in_group("mansion") as Mansion
			_skel.respawn_at(_mansion.to_global(Vector3(-3.6, Mansion.F2 + 0.4, 5.2)))
			_wait = 30
			_step = 29
		29:
			_mark = _skel.global_position
			Input.action_press("move_forward")
			_wait = 200
			_step = 30
		30:
			Input.action_release("move_forward")
			var dropped: float = _mark.y - _skel.global_position.y
			if dropped > 2.5:
				_ok("спуск по парадной лестнице работает (−%.1f м)" % dropped)
			else:
				_fail("по лестнице не спуститься: перепад всего %.2f м (застрял на %.2f)" % [dropped, _skel.global_position.y])
			_mark = _skel.global_position
			Input.action_press("move_back")
			_wait = 220
			_step = 31
		31:
			Input.action_release("move_back")
			var climbed: float = _skel.global_position.y - _mark.y
			if climbed > 2.5:
				_ok("подъём по той же лестнице работает (+%.1f м)" % climbed)
			else:
				_fail("подъём не работает: набрал всего %.2f м" % climbed)
			# спуск в подвал по пандусу шахты (кухня)
			_skel.respawn_at(_mansion.to_global(Vector3(
				Mansion.SHAFT_W.position.x + Mansion.SHAFT_W.size.x / 2.0, 0.5, Mansion.SHAFT_W.position.y - 0.9)))
			_wait = 30
			_step = 32
		32:
			_mark = _skel.global_position
			Input.action_press("move_back")   # шахта уходит вниз по +Z
			_wait = 150
			_step = 33
		33:
			Input.action_release("move_back")
			var down: float = _mark.y - _skel.global_position.y
			if down > 1.2:
				_ok("спуск в подвал по пандусу работает (−%.1f м)" % down)
			else:
				_fail("в подвал не спуститься: перепад %.2f м, застрял на y=%.2f" % [down, _skel.global_position.y])
			# подбор с дистанции: тарелка в 2.6 м, брать нужно не вплотную
			_skel.respawn_at(_mansion.to_global(Vector3(-12.0, 0.5, 7.0)))
			# оставляем в сцене ровно один хватаемый предмет — иначе тест возьмёт чужой
			for n in get_tree().get_nodes_in_group("grabbable"):
				(n as Node).queue_free()
			_sink_plate = BreakableProp.make(get_tree().current_scene, "plate_dirty", Vector3.ZERO)
			_sink_plate.global_position = _skel.global_position + Vector3(0, -0.22, -2.6)
			_wait = 25
			_step = 34
		34:
			_skel.held = null
			_skel.call("_try_grab")
			_wait = 5
			_step = 35
		35:
			if _skel.held == _sink_plate:
				_ok("предмет берётся с расстояния (2.6 м), а не вплотную")
			else:
				_fail("не удалось взять предмет с 2.6 м")
				print("  DIAG: valid=", is_instance_valid(_sink_plate),
					" skel=", _skel.global_position,
					" plate=", _sink_plate.global_position if is_instance_valid(_sink_plate) else Vector3.INF,
					" dist=", _skel.global_position.distance_to(_sink_plate.global_position) if is_instance_valid(_sink_plate) else -1,
					" los=", Game.has_line_of_sight(_skel, _sink_plate) if is_instance_valid(_sink_plate) else false,
					" state=", _skel.state, " held=", _skel.held)
			# пороги обязаны быть выше того, что даёт обычная игра: ходьба,
			# прыжок, лестницы и пандус не должны отрывать ноги
			if _skel.peak_impact < SkeletonPlayer.SHOCK_PART:
				_ok("самый сильный удар за прогон %.1f м/с — ниже порога отрыва %.1f"
					% [_skel.peak_impact, SkeletonPlayer.SHOCK_PART])
			else:
				_fail("ходьба/лестницы дают удар %.1f м/с — это выше порога отрыва %.1f, деталь отвалится на ровном месте"
					% [_skel.peak_impact, SkeletonPlayer.SHOCK_PART])
			_finish()

func _finish() -> void:
	if _errors.is_empty():
		print("SELFTEST: PASS (все механики работают, %d кадров)" % _frames)
		get_tree().quit(0)
	else:
		print("SELFTEST: FAIL — %d ошибок" % _errors.size())
		for e in _errors:
			print("  - ", e)
		get_tree().quit(1)
