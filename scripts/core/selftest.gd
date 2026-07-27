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

func _ready() -> void:
	print("SELFTEST: старт")

func _fail(msg: String) -> void:
	_errors.append("шаг %d: %s" % [_step, msg])
	print("SELFTEST FAIL — ", msg)

func _ok(msg: String) -> void:
	print("SELFTEST ok — ", msg)

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 4000:
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
			if _skel.state != SkeletonPlayer.State.ACTIVE:
				if _frames > 1200:
					_fail("стартовая сборка так и не случилась")
					_finish()
				return
			_ok("стартовое рассыпание собралось (пролог)")
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
			_mark = Vector3(_frames, 0, 0)
			_step = 11
		11:
			if _skel.state == SkeletonPlayer.State.ACTIVE and Game.possessed == _skel:
				_ok("скелет собрался у черепа за %.1f c" % ((_frames - _mark.x) / 60.0))
				_step = 12
			elif _frames - _mark.x > 900:
				_fail("сборка не произошла за 15 с")
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
			# мойка отмывает грязную тарелку
			_sink_plate = BreakableProp.make(get_tree().current_scene, "plate_dirty", Vector3.ZERO)
			_sink_plate.global_position = _mansion.sink.global_position + Vector3(0, 1.15, 0)
			_wait = 40
			_step = 20
		20:
			if is_instance_valid(_sink_plate) and _sink_plate.kind == "plate":
				_ok("мойка отмыла тарелку")
			else:
				_fail("тарелка не отмылась в раковине")
				print("  DIAG: plate valid=", is_instance_valid(_sink_plate),
					" kind=", _sink_plate.kind if is_instance_valid(_sink_plate) else "-",
					" pos=", _sink_plate.global_position if is_instance_valid(_sink_plate) else Vector3.INF,
					" sink=", _mansion.sink.global_position)
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
			_skel.held = _sink_plate
			_sink_plate.freeze = true
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
			_finish()

func _finish() -> void:
	if _errors.is_empty():
		print("SELFTEST: PASS (все механики работают)")
		get_tree().quit(0)
	else:
		print("SELFTEST: FAIL — %d ошибок" % _errors.size())
		for e in _errors:
			print("  - ", e)
		get_tree().quit(1)
