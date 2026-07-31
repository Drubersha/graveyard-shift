class_name SkeletonPlayer extends CharacterBody3D
## Игрок-скелет. Бессмертный, но хрупкий, и собран из ОТДЕЛЬНЫХ деталей:
## череп, торс, две руки, две ноги (BoneParts). Каждая может отвалиться по одной.
##
## Хрупкость на двух порогах (BoneParts + apply_shock):
##   удар слабее SHOCK_PART — ничего;
##   SHOCK_PART..SHOCK_FULL — отрывается ОДНА деталь по месту удара, тело работает
##     дальше (без ноги — ковыляет, без руки — не берёт, без черепа — не видит);
##   SHOCK_FULL и выше — рассыпается целиком.
## Удар считается от реального столкновения: скорость приземления и скорость,
## погашенная стеной, — а не только внешними вызовами из контента.
##
## СБОРКА ТОЛЬКО ВРУЧНУЮ. Никаких таймеров: R в рассыпанном виде стягивает кости
## к черепу. R в активном виде — наоборот, рассыпает. H — полный респавн у входа.

signal shattered
signal reassembled
signal skull_thrown
signal part_lost(part_id: String)

const SPEED := 4.2
const ACCEL := 12.0
const JUMP := 4.6
const PUSH_FORCE := 1.6
## Пороги удара (м/с погашенной скорости). ЗАМЕРЕНО селфтестом (peak_impact):
## ходьба, прыжок, парадная лестница и пандус в подвал дают максимум 4.2 —
## вдвое ниже SHOCK_PART, так что на ровном месте ничего не отваливается.
## 8.0 ≈ падение с 3.3 м (второй этаж), 14.0 ≈ падение с 10 м.
const SHOCK_PART := 8.0            # оторвать одну деталь
const SHOCK_FULL := 14.0           # рассыпаться целиком
const SHOCK_LIMIT := SHOCK_FULL    # старое имя полного порога: оставлено для контента
## Подъём визуала над началом координат тела. Капсула стоит от локальной Y=0.20
## (позиция 0.85 минус половина высоты 0.65), а подошвы деталей приходятся на
## локальную Y=0.024 (крепление ноги 0.84 минус 0.816 модели) — без поправки
## скелет уходил ступнями на 18 см В ПОЛ. Тот же подъём получает и CamAnchor,
## иначе вид от первого лица смотрит из-под глазниц.
## Было 0.181 при низе модели -0.821: тогда под стопой лежала тёмная пластина
## «грязи», из-за которой стопа читалась подошвой ботинка. Пластину убрали,
## низ стал -0.816, подъём пересчитан — иначе скелет висел бы на 5 мм.
const VISUAL_LIFT := 0.176
const GRAB_RANGE := 3.4      # рука у скелета длинная, а прицел — ещё длиннее
const INTERACT_RANGE := 3.2
const THROW_MIN := 4.0
const THROW_MAX := 15.0

enum State { ACTIVE, SITTING, SHATTERED }
var state := State.ACTIVE

## Какие детали сейчас на теле. Единственный источник правды о комплектности.
var _part_on := {"skull": true, "torso": true, "arm_l": true, "arm_r": true,
	"leg_l": true, "leg_r": true}

## Правая рука и череп имеют собственные сущности-механики, остальное — BonePart.
var arm_attached: bool:
	get:
		return _part_on["arm_r"]
	set(value):
		_part_on["arm_r"] = value
var skull_attached: bool:
	get:
		return _part_on["skull"]
	set(value):
		_part_on["skull"] = value

var arm_entity: DetachedArm = null
var skull_entity: SkullEntity = null
var held: RigidBody3D = null

var _held_layer := 1
var _held_mask := 1
var _charge := 0.0                 # общий заряд броска (предмет или череп)
var _charging_action := ""         # "grab" или "throw_skull"
var _gathering := false
var _gather_block := 0             # кадры, пока R после рассыпания не считается сборкой
var _bones: Array[RigidBody3D] = []      # безымянная мелочь
var _loose := {}                         # id детали -> BonePart на земле
var _last_ground_pos := Vector3.ZERO
var _sit_point: Node3D = null
var _fall_speed := 0.0             # набранная в полёте скорость снижения
## Самый сильный удар об поверхность за сессию. Нужен, чтобы пороги были
## ЗАМЕРЕНЫ, а не выдуманы: селфтест в конце сверяет его с SHOCK_PART.
var peak_impact := 0.0

var _visual: Node3D
var _pivot := {}                   # id детали -> Node3D (точка крепления и поворота)
var _walk_phase := 0.0
var _limp := 0.0

const LOST_HINT := {
	"skull": "Череп отвалился и укатился. Камера уехала с ним — он же глаза. R — рассыпаться и собрать всё разом.",
	"arm_l": "Левая рука отвалилась. Работать можно и одной. R — рассыпаться и собраться заново.",
	"arm_r": "Правая рука отвалилась. Подойди и жми F, чтобы прирастить.",
	"leg_l": "Нога отскочила. Ковыляй. R — рассыпаться и собрать себя целиком.",
	"leg_r": "Нога отскочила. Ковыляй. R — рассыпаться и собрать себя целиком.",
}

func _ready() -> void:
	add_to_group("player")
	add_to_group("view_aware")
	Game.player_skeleton = self
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.3
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	# прилипание к полу на спусках: без него скелет «летит» по ступеням
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(52.0)
	Game.set_camera_target(self)
	var anchor := Node3D.new()
	anchor.name = "CamAnchor"
	anchor.position = Vector3(0, 1.62 + VISUAL_LIFT, 0)   # уровень глазниц черепа
	add_child(anchor)
	_build_visual()
	Game.possess(self)

# ---------------------------------------------------------------- визуал

## Тело — шесть отдельных деталей на своих пивотах. Пивот = сустав, поэтому
## анимация просто крутит пивот, а отрыв просто прячет его и роняет BonePart.
func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position.y = VISUAL_LIFT
	add_child(_visual)
	for id: String in BoneParts.IDS:
		var piv := Node3D.new()
		piv.name = "Pivot_" + id
		piv.position = BoneParts.MOUNT[id]
		_visual.add_child(piv)
		BoneParts.build(piv, id)
		_pivot[id] = piv

func _animate(delta: float, moving: bool) -> void:
	var legs := _legs_on()
	if moving and legs > 0:
		_walk_phase += delta * (9.0 if legs == 2 else 12.0)
		var s := sin(_walk_phase)
		_swing("leg_l", s * 0.7)
		_swing("leg_r", -s * 0.7)
		_swing("arm_l", -s * 0.5)
		_swing("arm_r", s * 0.5)
		# на одной ноге тело заваливает — ковыляние видно, а не только медленнее
		_visual.rotation.z = lerpf(_visual.rotation.z, _limp * absf(s) * 0.22, delta * 8.0)
		_visual.position.y = lerpf(_visual.position.y,
			VISUAL_LIFT - absf(s) * (0.10 if legs == 1 else 0.0), delta * 8.0)
	else:
		_walk_phase = 0.0
		for id: String in ["leg_l", "leg_r", "arm_l", "arm_r"]:
			var p := _pivot.get(id) as Node3D
			if p:
				p.rotation.x = lerpf(p.rotation.x, 0.0, delta * 8.0)
		_visual.rotation.z = lerpf(_visual.rotation.z, _limp * 0.12, delta * 6.0)
		_visual.position.y = lerpf(_visual.position.y, VISUAL_LIFT, delta * 6.0)
	# лёгкое покачивание черепа — живость
	var skull := _pivot.get("skull") as Node3D
	if skull and skull.visible:
		skull.rotation.z = sin(Time.get_ticks_msec() * 0.002) * 0.06

func _swing(id: String, value: float) -> void:
	var p := _pivot.get(id) as Node3D
	if p and _part_on.get(id, false):
		p.rotation.x = value

func _legs_on() -> int:
	return int(_part_on["leg_l"]) + int(_part_on["leg_r"])

## Без ног скелет не бегает: одна — ковыляние, ни одной — ползёт на руках.
func _speed_factor() -> float:
	match _legs_on():
		2: return 1.0
		1: return 0.58
		_: return 0.32

## Сколько деталей сейчас не на теле (для HUD и селфтеста).
func parts_missing() -> int:
	var n := 0
	for id: String in BoneParts.IDS:
		if not _part_on[id]:
			n += 1
	return n

## Список подписей отсутствующих деталей — HUD показывает его игроку.
func missing_labels() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in BoneParts.IDS:
		if not _part_on[id]:
			out.append(str(BoneParts.LABEL[id]))
	return out

func has_part(id: String) -> bool:
	return bool(_part_on.get(id, false))

# ---------------------------------------------------------------- физика

func _physics_process(delta: float) -> void:
	match state:
		State.SHATTERED:
			_tick_shattered()
		State.SITTING:
			_tick_sitting()
		State.ACTIVE:
			_tick_active(delta)

func _tick_active(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		_last_ground_pos = global_position

	var moving := false
	if Game.is_possessed(self):
		var rig := Game.camera_rig as CameraRig
		var input := Vector2.ZERO
		input.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var dir := Vector3.ZERO
		if rig and input.length() > 0.1:
			dir = (rig.forward() * input.y + rig.right() * input.x).normalized()
			moving = true
		var target := dir * SPEED * _speed_factor()
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
		if moving:
			var face := atan2(dir.x, dir.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, face + PI, delta * 10.0)
		if Input.is_action_just_pressed("jump") and is_on_floor() and _legs_on() > 0:
			velocity.y = JUMP
		_handle_actions(delta)

	var pre_vel := velocity
	var was_floor := is_on_floor()
	move_and_slide()
	# толкаем физические объекты
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb and not rb.freeze:
			rb.apply_central_impulse(-c.get_normal() * PUSH_FORCE)
	if not _check_impacts(pre_vel, was_floor):
		return
	_animate(delta, moving)
	_update_held()

## Связывает столкновения с apply_shock — то, чего раньше не было: удар об
## поверхность считался только для полного рассыпания и по dv после slide,
## из-за чего ступеньки и снап пола давали ложные срабатывания.
## Падение меряем по набранной в ПОЛЁТЕ скорости снижения: лестница пол не
## теряет, значит и удара по ней не бывает. Стену — по погашенной скорости
## вдоль её нормали.
## Возвращает false, если после удара тик надо прервать (состояние сменилось).
func _check_impacts(pre_vel: Vector3, was_floor: bool) -> bool:
	var on_floor := is_on_floor()
	if on_floor and not was_floor:
		var impact := maxf(_fall_speed, -pre_vel.y)
		_fall_speed = 0.0
		peak_impact = maxf(peak_impact, impact)
		if impact >= SHOCK_PART:
			apply_shock(impact, Vector3.UP)
			return state == State.ACTIVE
	if on_floor:
		_fall_speed = 0.0
	else:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if n.y > 0.6:
			continue                       # пол уже посчитан приземлением
		# сюда попадают и стены, и ПОТОЛОК (n.y < 0): удар макушкой снизу вверх
		# даёт dir вниз, а _part_for_hit по нему выбирает череп
		var into := pre_vel.dot(-n)
		peak_impact = maxf(peak_impact, into)
		if into >= SHOCK_PART:
			apply_shock(into, n)
			return state == State.ACTIVE
	return true

func _tick_sitting() -> void:
	if Game.is_possessed(self) and (Input.is_action_just_pressed("jump")
			or Input.is_action_just_pressed("move_forward")
			or Input.is_action_just_pressed("interact")):
		stand_up()

func _handle_actions(delta: float) -> void:
	# заряд броска (предмета или черепа)
	if _charging_action != "":
		_charge = minf(_charge + delta * 1.4, 1.0)
		if not Input.is_action_pressed(_charging_action):
			var power := lerpf(THROW_MIN, THROW_MAX, _charge)
			if _charging_action == "grab":
				# короткий клик — поставить аккуратно, удержание — швырнуть
				if _charge < 0.18:
					_place_held()
				else:
					_throw_held(power)
			else:
				_detach_skull(power)
			_charging_action = ""
			_charge = 0.0
		return
	if Input.is_action_just_pressed("grab"):
		if held:
			_charging_action = "grab"
		else:
			_try_grab()
	elif Input.is_action_just_pressed("throw_skull"):
		if skull_attached:
			_charging_action = "throw_skull"   # удержание заряжает бросок черепа
		else:
			try_attach_skull()
	elif Input.is_action_just_pressed("interact"):
		_try_interact()
	elif Input.is_action_just_pressed("detach_arm"):
		_toggle_arm()
	elif Input.is_action_just_pressed("collapse"):
		# R в активном виде — рассыпаться. Собирает та же R, но уже в куче.
		shatter(Vector3.UP)
	elif Input.is_action_just_pressed("switch_body") \
			and Game.last_switch_frame != int(Engine.get_physics_frames()):
		Game.cycle_control()

# ---------------------------------------------------------------- хват

func _hold_point() -> Vector3:
	return global_position + -_visual.global_transform.basis.z * 0.9 + Vector3.UP * 1.1

## Берём то, на что смотрит прицел; если прицел мимо — ближайшее в радиусе руки.
func _try_grab() -> void:
	if not (_part_on["arm_l"] or _part_on["arm_r"]):
		Game.hint("Брать нечем: обе руки где-то там. R — рассыпаться и собраться.")
		return
	var best := Game.aimed(self, "grabbable", GRAB_RANGE) as RigidBody3D
	if best and best.mass > 25.0:
		best = null
	if best == null:
		var best_d := GRAB_RANGE
		for node in get_tree().get_nodes_in_group("grabbable"):
			var rb := node as RigidBody3D
			if not rb or rb.mass > 25.0:
				continue
			var d := rb.global_position.distance_to(global_position)
			if d < best_d and Game.has_line_of_sight(self, rb):
				best_d = d
				best = rb
	if best:
		_take(best)
		Game.hint("Короткий клик ЛКМ — поставить аккуратно. Держать и отпустить — швырнуть.")

## Взять предмет: он «выключается» из физики, чтобы не толкать хозяина и не биться в руках.
func _take(rb: RigidBody3D) -> void:
	held = rb
	rb.freeze = true
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	_held_layer = rb.collision_layer
	_held_mask = rb.collision_mask
	rb.collision_layer = 0
	rb.collision_mask = 0
	if rb is BreakableProp:
		(rb as BreakableProp).carried = true
	Game.item_picked.emit(rb)

## Вернуть предмету физику (общая часть для «поставить» и «швырнуть»).
func _release_physics(rb: RigidBody3D) -> void:
	rb.collision_layer = _held_layer if _held_layer != 0 else 1
	rb.collision_mask = _held_mask if _held_mask != 0 else 1
	rb.freeze = false
	if rb is BreakableProp:
		(rb as BreakableProp).carried = false
	Game.item_picked.emit(null)

func _update_held() -> void:
	if not is_instance_valid(held):
		held = null
		return
	held.global_position = held.global_position.lerp(_hold_point(), 0.4)

func _throw_held(power: float) -> void:
	if not is_instance_valid(held):
		held = null
		return
	var rig := Game.camera_rig as CameraRig
	var rb := held
	held = null
	_release_physics(rb)
	rb.linear_velocity = (rig.aim() if rig else Vector3.FORWARD) * power + Vector3.UP * 1.5
	rb.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))

## Аккуратно поставить предмет на поверхность перед собой — без импульса,
## ровно и не разбив. Короткий клик ЛКМ.
func _place_held() -> void:
	if not is_instance_valid(held):
		held = null
		return
	var rb := held
	held = null
	var from := _hold_point()
	var params := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5, 1, [rb.get_rid(), get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit:
		rb.global_position = (hit["position"] as Vector3) + Vector3.UP * 0.12
	rb.global_rotation = Vector3(0, rb.global_rotation.y, 0)
	_release_physics(rb)
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	Game.hint("Поставил. Целую.")

func _release_held() -> void:
	if is_instance_valid(held):
		_release_physics(held)
	held = null

# ---------------------------------------------------------------- взаимодействие

func _try_interact() -> void:
	var target := nearest_interactable(INTERACT_RANGE)
	if target:
		target.interact(self)

func nearest_interactable(range_: float) -> Node:
	# сначала то, во что целишься, потом — ближайшее вокруг
	var aimed := Game.aimed(self, "interactable", range_)
	if aimed and aimed.has_method("interact"):
		return aimed
	var best: Node = null
	var best_d := range_
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node3D:
			continue
		var d: float = (node as Node3D).global_position.distance_to(global_position)
		if d < best_d and Game.has_line_of_sight(self, node):
			best_d = d
			best = node
	return best

## Присесть на снап-точку (скамейка и т.п.)
func sit_at(point: Node3D) -> void:
	if state != State.ACTIVE:
		return
	state = State.SITTING
	_sit_point = point
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position", point.global_position, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_visual, "rotation:y", point.global_rotation.y - global_rotation.y, 0.35)
	# поза "сидя" — только теми ногами, что на месте
	_swing("leg_l", 1.4)
	_swing("leg_r", 1.4)

func stand_up() -> void:
	state = State.ACTIVE
	_sit_point = null
	_swing("leg_l", 0.0)
	_swing("leg_r", 0.0)
	global_position += Vector3.UP * 0.2

# ---------------------------------------------------------------- рука

func _toggle_arm() -> void:
	if _part_on["arm_r"]:
		_part_on["arm_r"] = false
		(_pivot["arm_r"] as Node3D).visible = false
		var arm := DetachedArm.new()
		get_parent().add_child(arm)
		arm.global_position = (_pivot["arm_r"] as Node3D).global_position \
			+ -_visual.global_transform.basis.z * 0.4
		arm.owner_skeleton = self
		arm_entity = arm
		Game.possess(arm)
		Game.hint("Рука на радиоуправлении: камера остаётся у черепа, рука ползёт сама. WASD — ползти, Space — подскок, E — нажать, Tab — сменить управление.")
	elif is_instance_valid(arm_entity):
		if arm_entity.global_position.distance_to(global_position) < 2.2:
			reattach_arm()
		else:
			Game.hint("Рука слишком далеко. Подойди к ней или переключись (Tab) и приползи сам")
	elif _loose.has("arm_r") and is_instance_valid(_loose["arm_r"]):
		# руку не оторвали кнопкой, а отбили ударом — она просто валяется
		var p := _loose["arm_r"] as BonePart
		if p.global_position.distance_to(global_position) < 2.2:
			_attach_loose("arm_r")
			Game.hint("Рука на месте. Держится на честном слове, но держится.")
		else:
			Game.hint("Отбитая рука валяется вон там. Подойди к ней и жми F.")

func reattach_arm() -> void:
	if is_instance_valid(arm_entity):
		arm_entity.queue_free()
	arm_entity = null
	if _loose.has("arm_r"):
		_attach_loose("arm_r")
	else:
		_part_on["arm_r"] = true
		(_pivot["arm_r"] as Node3D).visible = true

## Вернуть на место деталь, которая валяется рядом отдельным телом.
func _attach_loose(id: String) -> void:
	var p := _loose.get(id) as Node3D
	if is_instance_valid(p):
		p.queue_free()
	_loose.erase(id)
	_part_on[id] = true
	var piv := _pivot.get(id) as Node3D
	if piv:
		piv.visible = true
	_update_limp()

# ---------------------------------------------------------------- отрыв деталей

## Куда пришёлся удар — та деталь и отлетает.
## `dir` — куда толкнуло тело, значит прилетело с противоположной стороны:
## снизу (приземление) — нога, сверху — череп, сбоку — рука с той стороны.
func _part_for_hit(dir: Vector3) -> String:
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	var order: Array = []
	if d.y > 0.5:
		order = ["leg_r", "leg_l", "arm_r", "arm_l", "skull"] if randf() < 0.5 \
			else ["leg_l", "leg_r", "arm_l", "arm_r", "skull"]
	elif d.y < -0.4:
		order = ["skull", "arm_r", "arm_l", "leg_r", "leg_l"]
	else:
		# сторона удара в системе координат тела: pivot +X — правая рука
		var local := _visual.global_transform.basis.inverse() * (-d)
		order = ["arm_r", "arm_l", "skull", "leg_r", "leg_l"] if local.x > 0.0 \
			else ["arm_l", "arm_r", "skull", "leg_l", "leg_r"]
	for id in order:
		if _part_on.get(id, false):
			return id
	return ""

## Оторвать конкретную деталь. Тело продолжает работать без неё.
func detach_part(id: String, dir: Vector3) -> void:
	if id == "" or not _part_on.get(id, false) or state == State.SHATTERED:
		return
	var piv := _pivot.get(id) as Node3D
	var at := piv.global_position if piv else global_position + Vector3.UP
	# одиночный отрыв заметно бодрее рассыпания (это акцент удара), но всё равно
	# в пределах пары шагов, а не через полкомнаты
	var vel := dir.normalized() * 1.4 + Vector3(randf_range(-0.7, 0.7), 1.6, randf_range(-0.7, 0.7))
	if id == "skull":
		_spawn_skull(vel)
	else:
		_part_on[id] = false
		if piv:
			piv.visible = false
		_loose[id] = BonePart.make(get_parent(), id, at, vel)
	_update_limp()
	part_lost.emit(id)

func _update_limp() -> void:
	if _part_on["leg_l"] == _part_on["leg_r"]:
		_limp = 0.0
	else:
		_limp = 1.0 if _part_on["leg_r"] else -1.0

# ---------------------------------------------------------------- череп и рассыпание

## Снять череп и запустить его. Тело остаётся стоять и слушается удалённо,
## а камера уезжает с черепом — он же глаза.
func _detach_skull(power: float) -> void:
	if state != State.ACTIVE or not skull_attached:
		return
	var rig := Game.camera_rig as CameraRig
	_spawn_skull((rig.aim() if rig else Vector3.FORWARD) * power + Vector3.UP * 2.0)
	skull_thrown.emit()
	Game.possess(skull_entity)
	Game.hint("Череп отделён. Tab — переключить управление (череп / тело / рука), G у тела — вернуть на место.")

func _spawn_skull(velocity_: Vector3) -> void:
	var piv := _pivot["skull"] as Node3D
	_part_on["skull"] = false
	piv.visible = false
	var skull := SkullEntity.new()
	get_parent().add_child(skull)
	skull.global_position = piv.global_position
	skull.linear_velocity = velocity_
	skull.owner_skeleton = self
	skull_entity = skull
	Game.set_camera_target(skull)

## Вернуть череп на плечи (если он рядом с телом).
func try_attach_skull() -> void:
	if skull_attached or not is_instance_valid(skull_entity):
		return
	if skull_entity.global_position.distance_to(global_position) > 2.6:
		Game.hint("Череп далеко. Прикати его к телу (Tab) или собери всё разом — H.")
		return
	skull_entity.queue_free()
	skull_entity = null
	_part_on["skull"] = true
	(_pivot["skull"] as Node3D).visible = true
	Game.set_camera_target(self)
	Game.possess(self)

func shatter(dir: Vector3) -> void:
	if state == State.SHATTERED:
		return
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	if skull_attached:
		_spawn_skull(d * 1.1 + Vector3(randf_range(-0.7, 0.7), 1.5, randf_range(-0.7, 0.7)))
	_shatter_body(true)

## Общая часть рассыпания. Череп уже создан вызывающим кодом.
## Куча теперь именная: разлетаются те самые детали, что были на теле.
func _shatter_body(_from_damage: bool) -> void:
	_release_held()
	_charging_action = ""
	state = State.SHATTERED
	_gathering = false
	_gather_block = 2
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	visible = false
	collision_layer = 0
	collision_mask = 0
	for id: String in ["torso", "arm_l", "arm_r", "leg_l", "leg_r"]:
		if not _part_on[id]:
			continue                       # уже валяется отдельно — пусть лежит
		var piv := _pivot[id] as Node3D
		_part_on[id] = false
		piv.visible = false
		# Импульсы намеренно слабые: раньше (±2.5 вбок, до 4.2 вверх) детали
		# улетали метра на три и это читалось взрывом. Теперь они оседают
		# кучей у ног — кости сложились, а не сдетонировали.
		_loose[id] = BonePart.make(get_parent(), id, piv.global_position,
			Vector3(randf_range(-0.8, 0.8), randf_range(0.6, 1.5), randf_range(-0.8, 0.8)))
	# мелочь: рёбра, позвонки, что там ещё отваливается
	_bones.clear()
	for i in 5:
		var b := BoneDebris.new()
		get_parent().add_child(b)
		b.global_position = global_position + Vector3(randf_range(-0.2, 0.2),
			0.5 + randf_range(0, 0.6), randf_range(-0.2, 0.2))
		b.linear_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.8),
			randf_range(-1.0, 1.0))
		_bones.append(b)
	_update_limp()
	if is_instance_valid(skull_entity):
		Game.possess(skull_entity)
	Game.hint("Рассыпался. Жми R ещё раз — кости слетятся к черепу.")
	shattered.emit()

## В рассыпанном виде ждём ТОЛЬКО кнопку. Никаких таймеров: сборка ручная.
func _tick_shattered() -> void:
	if _gathering:
		return
	if _gather_block > 0:
		_gather_block -= 1
		return
	# череп улетел за пределы мира — спасаем, иначе собираться будет некуда
	if is_instance_valid(skull_entity) and skull_entity.global_position.y < -10.0:
		skull_entity.global_position = _last_ground_pos + Vector3.UP
		skull_entity.linear_velocity = Vector3.ZERO
	if Input.is_action_just_pressed("collapse"):
		_begin_gather()

## Текущий заряд броска (0..1) для индикатора на HUD.
func charge_ratio() -> float:
	return _charge if _charging_action != "" else 0.0

func _begin_gather() -> void:
	_gathering = true
	var target := skull_entity.global_position if is_instance_valid(skull_entity) \
		else _last_ground_pos + Vector3.UP * 0.4
	var pieces: Array[Node3D] = []
	for b in _bones:
		if is_instance_valid(b):
			pieces.append(b)
	for id: String in _loose.keys():
		if is_instance_valid(_loose[id]):
			pieces.append(_loose[id])
	if is_instance_valid(arm_entity):
		pieces.append(arm_entity)
	var tw := create_tween()
	for p in pieces:
		if p is RigidBody3D:
			(p as RigidBody3D).freeze = true
		tw.parallel().tween_property(p, "global_position", target, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_finish_reassemble)

## Освободить всё, что валяется отдельно от тела.
func _clear_pieces() -> void:
	for b in _bones:
		if is_instance_valid(b):
			b.queue_free()
	_bones.clear()
	for id: String in _loose.keys():
		var p := _loose[id] as Node
		if is_instance_valid(p):
			p.queue_free()
	_loose.clear()
	if is_instance_valid(arm_entity):
		arm_entity.queue_free()
	arm_entity = null
	if is_instance_valid(skull_entity):
		skull_entity.queue_free()
	skull_entity = null

## Все детали обратно на тело.
func _restore_parts() -> void:
	for id: String in BoneParts.IDS:
		_part_on[id] = true
		var piv := _pivot.get(id) as Node3D
		if piv:
			piv.visible = true
			piv.rotation = Vector3.ZERO
	_visual.rotation.z = 0.0
	_visual.position.y = VISUAL_LIFT
	_update_limp()

func _finish_reassemble() -> void:
	var pos := skull_entity.global_position if is_instance_valid(skull_entity) else _last_ground_pos
	_clear_pieces()
	_restore_parts()
	Game.set_camera_target(self)
	global_position = pos + Vector3.UP * 0.4
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	visible = true
	collision_layer = 1
	collision_mask = 1
	state = State.ACTIVE
	_gathering = false
	Game.possess(self)
	reassembled.emit()

## Внешний урон (машины, отдача, падающие шкафы — используется контентом).
## Два порога: средне-сильный отрывает одну деталь, очень сильный — рассыпает.
func apply_shock(strength: float, dir: Vector3) -> void:
	if state == State.SHATTERED:
		return
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	if strength >= SHOCK_FULL:
		shatter(d)
		return
	if strength < SHOCK_PART:
		return
	var id := _part_for_hit(d)
	if id == "":
		shatter(d)          # отрывать больше нечего — значит рассыпаемся
		return
	detach_part(id, d)
	Game.hint(str(LOST_HINT.get(id, "Деталь отвалилась. R — рассыпаться и собрать себя заново.")))

## Вид от первого лица: собственный скелет не должен закрывать обзор изнутри.
func set_view_mode(first_person: bool) -> void:
	if is_instance_valid(_visual):
		_visual.visible = not first_person

## Мгновенная сборка (переход между локациями): ничего не должно остаться
## в выгружаемой сцене — ни костей, ни отбитых деталей.
func force_reassemble() -> void:
	if state == State.SHATTERED:
		_gathering = true
		_finish_reassemble()
	elif parts_missing() > 0:
		# тело на ногах, но чего-то не хватает — приращиваем, не двигая игрока
		_clear_pieces()
		_restore_parts()
		Game.set_camera_target(self)
		Game.possess(self)

## Кнопка H: собрать себя целиком и телепортироваться на вход локации.
func respawn_at(pos: Vector3) -> void:
	_release_held()
	_charging_action = ""
	_charge = 0.0
	_clear_pieces()
	_restore_parts()
	_gathering = false
	_gather_block = 0
	_fall_speed = 0.0
	state = State.ACTIVE
	visible = true
	collision_layer = 1
	collision_mask = 1
	velocity = Vector3.ZERO
	global_position = pos
	Game.set_camera_target(self)
	Game.possess(self)
	Game.hint("Собрался. Как новенький. Ну, как подержанный.")
