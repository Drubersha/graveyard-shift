extends Node
## Интеграционный самотест (запуск: godot --headless --path . -- --selftest).
## Скриптованными инпутами проверяет: ходьбу, отрыв руки, ползание руки,
## возврат в тело, бросок черепа + рассыпание + сборку, ломаемые пропсы.

var _step := 0
var _frames := 0
var _wait := 0
var _errors: PackedStringArray = []
var _skel: SkeletonPlayer
var _mark := Vector3.ZERO
var _test_prop: BreakableProp = null
var _mess_before := 0

func _ready() -> void:
	print("SELFTEST: старт")

func _fail(msg: String) -> void:
	_errors.append("шаг %d: %s" % [_step, msg])
	print("SELFTEST FAIL — ", msg)

func _ok(msg: String) -> void:
	print("SELFTEST ok — ", msg)

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 3000:
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
				_fail("скелет не создан")
				_finish()
				return
			_wait = 60  # приземлиться
			_step = 1
		1:
			# телепорт на чистый участок дорожки: у могилы спереди стоит
			# собственное надгробие, тест шёл ровно в него
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
			# прирастить руку обратно (рядом же)
			if is_instance_valid(_skel.arm_entity) and _skel.arm_entity.global_position.distance_to(_skel.global_position) < 2.2:
				_skel.reattach_arm()
			_step = 8
		8:
			# бросок черепа
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
			_mark = Vector3(_frames, 0, 0)  # запомним кадр для таймаута сборки
			_step = 11
		11:
			if _skel.state == SkeletonPlayer.State.ACTIVE and Game.possessed == _skel:
				_ok("скелет собрался у черепа за %.1f c" % ((_frames - _mark.x) / 60.0))
				_step = 12
			elif _frames - _mark.x > 900:
				_fail("сборка не произошла за 15 с")
				_step = 12
		12:
			# ломаемый пропс: ваза падает с высоты и разбивается
			_mess_before = Game.mess_points
			_test_prop = BreakableProp.make(get_tree().current_scene, "vase",
				_skel.global_position + Vector3(1.5, 3.5, 0))
			_wait = 90
			_step = 13
		13:
			if Game.mess_points > _mess_before:
				_ok("ваза разбилась, срач засчитан (+%d)" % (Game.mess_points - _mess_before))
			else:
				_fail("ваза не разбилась при падении")
			_step = 14
		14:
			# добровольное рассыпание R и сборка
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
				_finish()
			elif _frames - _mark.x > 900:
				_fail("повторная сборка не произошла")
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
