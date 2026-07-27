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
			_mansion = get_tree().get_first_node_in_group("mansion") as Mansion
			if not _skel or not _mansion:
				_fail("нет скелета или особняка")
				_finish()
				return
			_wait = 60
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
				_ok("Tab вернул управление скелету")
			else:
				_fail("Tab не вернул управление скелету")
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
			if _skel.state == SkeletonPlayer.State.SHATTERED and Game.possessed is SkullEntity:
				_ok("череп брошен, тело рассыпалось, камера на черепе")
			else:
				_fail("бросок черепа: state=%s possessed=%s" % [_skel.state, Game.possessed])
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
			Input.action_press("collapse")
			_wait = 2
			_step = 15
		15:
			Input.action_release("collapse")
			if _skel.state == SkeletonPlayer.State.SHATTERED:
				_ok("R — добровольное рассыпание работает")
			else:
				_fail("R не рассыпал скелета")
			_mark = Vector3(_frames, 0, 0)
			_step = 16
		16:
			if _skel.state == SkeletonPlayer.State.ACTIVE:
				_ok("повторная сборка работает")
				_step = 17
			elif _frames - _mark.x > 900:
				_fail("повторная сборка не произошла")
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
			_step = 21
		21:
			# плита: кладём рецепт и готовим
			var sp := _mansion.stove.global_position
			var egg := BreakableProp.make(get_tree().current_scene, "egg", Vector3.ZERO)
			egg.global_position = sp + Vector3(0, 1.11, -0.25)
			var flour := BreakableProp.make(get_tree().current_scene, "flour", Vector3.ZERO)
			flour.global_position = sp + Vector3(0, 1.23, 0)
			var wine := BreakableProp.make(get_tree().current_scene, "bottle", Vector3.ZERO)
			wine.global_position = sp + Vector3(0, 1.17, 0.25)
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
