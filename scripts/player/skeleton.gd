class_name SkeletonPlayer extends CharacterBody3D
## Игрок-скелет. Бессмертный, но хрупкий.
## Умеет: ходить, хватать и швырять предметы, отрывать правую руку (РУ-режим),
## кидать собственный череп (тело рассыпается и собирается у черепа),
## рассыпаться от сильного удара с кулдауном на сборку.

signal shattered
signal reassembled
signal skull_thrown

const SPEED := 4.2
const ACCEL := 12.0
const JUMP := 4.6
const PUSH_FORCE := 1.6
const SHOCK_LIMIT := 7.5           # резкая смена скорости (м/с) → рассыпание
const REASSEMBLE_COOLDOWN := 4.0
const GRAB_RANGE := 3.4      # рука у скелета длинная, а прицел — ещё длиннее
const INTERACT_RANGE := 3.2
const THROW_MIN := 4.0
const THROW_MAX := 15.0

enum State { ACTIVE, SITTING, SHATTERED }
var state := State.ACTIVE

var arm_attached := true
var arm_entity: DetachedArm = null
var skull_attached := true
var skull_entity: SkullEntity = null
var held: RigidBody3D = null

var _held_layer := 1
var _held_mask := 1
var _charge := 0.0                 # общий заряд броска (предмет или череп)
var _charging_action := ""         # "grab" или "throw_skull"
var _cooldown_left := 0.0
var _gathering := false
var _bones: Array[BoneDebris] = []
var _last_ground_pos := Vector3.ZERO
var _sit_point: Node3D = null

var _visual: Node3D
var _arm_r_pivot: Node3D
var _arm_l_pivot: Node3D
var _leg_r_pivot: Node3D
var _leg_l_pivot: Node3D
var _skull_vis: Node3D
var _walk_phase := 0.0

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
	anchor.position = Vector3(0, 1.62, 0)   # уровень глазниц черепа
	add_child(anchor)
	_build_visual()
	Game.possess(self)

# ---------------------------------------------------------------- визуал

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	# таз и позвоночник
	MeshLib.box(_visual, Vector3(0.34, 0.16, 0.2), Vector3(0, 0.9, 0), MeshLib.BONE_DARK)
	MeshLib.capsule(_visual, 0.05, 0.5, Vector3(0, 1.15, 0), MeshLib.BONE)
	# рёбра — три сплющенных кольца
	for i in 3:
		MeshLib.box(_visual, Vector3(0.42 - i * 0.04, 0.07, 0.26), Vector3(0, 1.16 + i * 0.11, 0), MeshLib.BONE)
	# череп (отдельный узел — прячем при броске)
	_skull_vis = Node3D.new()
	_skull_vis.position = Vector3(0, 1.62, 0)
	_visual.add_child(_skull_vis)
	MeshLib.sphere(_skull_vis, 0.17, Vector3.ZERO, MeshLib.BONE)
	MeshLib.box(_skull_vis, Vector3(0.16, 0.1, 0.12), Vector3(0, -0.13, -0.03), MeshLib.BONE)
	var eye_l := MeshLib.sphere(_skull_vis, 0.042, Vector3(-0.062, 0.02, -0.155), Color.BLACK)
	var eye_r := MeshLib.sphere(_skull_vis, 0.042, Vector3(0.062, 0.02, -0.155), Color.BLACK)
	eye_l.material_override = MeshLib.mat(Color.BLACK, 1.0)
	eye_r.material_override = MeshLib.mat(Color.BLACK, 1.0)
	# руки
	_arm_l_pivot = _make_arm(-1)
	_arm_r_pivot = _make_arm(1)
	# ноги
	_leg_l_pivot = _make_leg(-1)
	_leg_r_pivot = _make_leg(1)

func _make_arm(side: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.28, 1.38, 0)
	_visual.add_child(pivot)
	MeshLib.capsule(pivot, 0.045, 0.34, Vector3(0, -0.18, 0), MeshLib.BONE)
	MeshLib.capsule(pivot, 0.04, 0.3, Vector3(0, -0.5, 0), MeshLib.BONE)
	MeshLib.box(pivot, Vector3(0.09, 0.11, 0.05), Vector3(0, -0.7, 0), MeshLib.BONE)
	return pivot

func _make_leg(side: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.12, 0.82, 0)
	_visual.add_child(pivot)
	MeshLib.capsule(pivot, 0.05, 0.38, Vector3(0, -0.2, 0), MeshLib.BONE)
	MeshLib.capsule(pivot, 0.045, 0.34, Vector3(0, -0.56, 0), MeshLib.BONE)
	MeshLib.box(pivot, Vector3(0.09, 0.06, 0.2), Vector3(0, -0.76, -0.04), MeshLib.BONE)
	return pivot

func _animate(delta: float, moving: bool) -> void:
	if moving:
		_walk_phase += delta * 9.0
		var s := sin(_walk_phase)
		_leg_l_pivot.rotation.x = s * 0.7
		_leg_r_pivot.rotation.x = -s * 0.7
		_arm_l_pivot.rotation.x = -s * 0.5
		if arm_attached:
			_arm_r_pivot.rotation.x = s * 0.5
	else:
		_walk_phase = 0.0
		for p: Node3D in [_leg_l_pivot, _leg_r_pivot, _arm_l_pivot, _arm_r_pivot]:
			p.rotation.x = lerpf(p.rotation.x, 0.0, delta * 8.0)
	# лёгкое покачивание черепа — живость
	if _skull_vis.visible:
		_skull_vis.rotation.z = sin(Time.get_ticks_msec() * 0.002) * 0.06

# ---------------------------------------------------------------- физика

func _physics_process(delta: float) -> void:
	match state:
		State.SHATTERED:
			_tick_shattered(delta)
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
		var target := dir * SPEED
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
		if moving:
			var face := atan2(dir.x, dir.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, face + PI, delta * 10.0)
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP
		_handle_actions(delta)

	var pre_vel := velocity
	move_and_slide()
	# толкаем физические объекты
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb and not rb.freeze:
			rb.apply_central_impulse(-c.get_normal() * PUSH_FORCE)
	# хрупкость: резкая остановка → рассыпание
	var dv := (velocity - pre_vel).length()
	if dv > SHOCK_LIMIT:
		shatter(Vector3.UP)
		return
	_animate(delta, moving)
	_update_held()

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
		shatter(Vector3.UP)
	elif Input.is_action_just_pressed("switch_body") \
			and Game.last_switch_frame != int(Engine.get_physics_frames()):
		Game.cycle_control()

# ---------------------------------------------------------------- хват

func _hold_point() -> Vector3:
	return global_position + -_visual.global_transform.basis.z * 0.9 + Vector3.UP * 1.1

## Берём то, на что смотрит прицел; если прицел мимо — ближайшее в радиусе руки.
func _try_grab() -> void:
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
	# поза "сидя"
	_leg_l_pivot.rotation.x = 1.4
	_leg_r_pivot.rotation.x = 1.4

func stand_up() -> void:
	state = State.ACTIVE
	_sit_point = null
	_leg_l_pivot.rotation.x = 0.0
	_leg_r_pivot.rotation.x = 0.0
	global_position += Vector3.UP * 0.2

# ---------------------------------------------------------------- рука

func _toggle_arm() -> void:
	if arm_attached:
		arm_attached = false
		_arm_r_pivot.visible = false
		var arm := DetachedArm.new()
		get_parent().add_child(arm)
		arm.global_position = _arm_r_pivot.global_position + -_visual.global_transform.basis.z * 0.4
		arm.owner_skeleton = self
		arm_entity = arm
		Game.possess(arm)
		Game.hint("Рука на радиоуправлении: камера остаётся у черепа, рука ползёт сама. WASD — ползти, Space — подскок, E — нажать, Tab — сменить управление.")
	elif is_instance_valid(arm_entity):
		if arm_entity.global_position.distance_to(global_position) < 2.2:
			reattach_arm()
		else:
			Game.hint("Рука слишком далеко. Подойди к ней или переключись (Tab) и приползи сам")

func reattach_arm() -> void:
	if is_instance_valid(arm_entity):
		arm_entity.queue_free()
	arm_entity = null
	arm_attached = true
	_arm_r_pivot.visible = true

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
	skull_attached = false
	_skull_vis.visible = false
	var skull := SkullEntity.new()
	get_parent().add_child(skull)
	skull.global_position = _skull_vis.global_position
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
	skull_attached = true
	_skull_vis.visible = true
	Game.set_camera_target(self)
	Game.possess(self)

func shatter(dir: Vector3) -> void:
	if state == State.SHATTERED:
		return
	if skull_attached:
		_spawn_skull(dir * 3.0 + Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2)))
	_shatter_body(true)

## Общая часть рассыпания. Череп уже создан вызывающим кодом.
func _shatter_body(_from_damage: bool) -> void:
	_release_held()
	_charging_action = ""
	state = State.SHATTERED
	_gathering = false
	_cooldown_left = REASSEMBLE_COOLDOWN
	velocity = Vector3.ZERO
	visible = false
	collision_layer = 0
	collision_mask = 0
	# кости разлетаются
	_bones.clear()
	var bone_count := 8 if arm_attached else 7
	for i in bone_count:
		var b := BoneDebris.new()
		get_parent().add_child(b)
		b.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.6 + randf_range(0, 0.8), randf_range(-0.3, 0.3))
		b.linear_velocity = Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3))
		_bones.append(b)
	if is_instance_valid(skull_entity):
		Game.possess(skull_entity)
	shattered.emit()

func _tick_shattered(delta: float) -> void:
	if _gathering:
		return
	# череп улетел за пределы мира — спасаем
	if is_instance_valid(skull_entity) and skull_entity.global_position.y < -10.0:
		skull_entity.global_position = _last_ground_pos + Vector3.UP
		skull_entity.linear_velocity = Vector3.ZERO
	_cooldown_left -= delta
	if _cooldown_left <= 0.0 and is_instance_valid(skull_entity):
		# собираемся, когда череп остановился; если он всё катается — через 5 с принудительно
		if skull_entity.linear_velocity.length() < 0.8 or _cooldown_left < -5.0:
			_begin_gather()

func cooldown_ratio() -> float:
	return clampf(_cooldown_left / REASSEMBLE_COOLDOWN, 0.0, 1.0)

## Текущий заряд броска (0..1) для индикатора на HUD.
func charge_ratio() -> float:
	return _charge if _charging_action != "" else 0.0

func _begin_gather() -> void:
	_gathering = true
	var target := skull_entity.global_position
	var tw := create_tween()
	for b in _bones:
		if is_instance_valid(b):
			b.freeze = true
			tw.parallel().tween_property(b, "global_position", target, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_finish_reassemble)

func _finish_reassemble() -> void:
	var pos := skull_entity.global_position if is_instance_valid(skull_entity) else _last_ground_pos
	for b in _bones:
		if is_instance_valid(b):
			b.queue_free()
	_bones.clear()
	if is_instance_valid(skull_entity):
		skull_entity.queue_free()
	skull_entity = null
	skull_attached = true
	_skull_vis.visible = true
	Game.set_camera_target(self)
	global_position = pos + Vector3.UP * 0.4
	velocity = Vector3.ZERO
	visible = true
	collision_layer = 1
	collision_mask = 1
	state = State.ACTIVE
	_gathering = false
	Game.possess(self)
	reassembled.emit()

## Внешний урон (машины, отдача и т.п. — используется контентом)
func apply_shock(strength: float, dir: Vector3) -> void:
	if strength >= SHOCK_LIMIT:
		shatter(dir.normalized())

## Вид от первого лица: собственный скелет не должен закрывать обзор изнутри.
func set_view_mode(first_person: bool) -> void:
	if is_instance_valid(_visual):
		_visual.visible = not first_person

## Мгновенная сборка (переход между локациями): кости не должны остаться в выгруженной сцене.
func force_reassemble() -> void:
	if state != State.SHATTERED:
		return
	_gathering = true
	_finish_reassemble()

## Кнопка H: собрать себя целиком и телепортироваться на вход локации.
func respawn_at(pos: Vector3) -> void:
	_release_held()
	_charging_action = ""
	_charge = 0.0
	for b in _bones:
		if is_instance_valid(b):
			b.queue_free()
	_bones.clear()
	if is_instance_valid(arm_entity):
		arm_entity.queue_free()
	arm_entity = null
	arm_attached = true
	_arm_r_pivot.visible = true
	if is_instance_valid(skull_entity):
		skull_entity.queue_free()
	skull_entity = null
	skull_attached = true
	_skull_vis.visible = true
	_gathering = false
	_cooldown_left = 0.0
	state = State.ACTIVE
	visible = true
	collision_layer = 1
	collision_mask = 1
	velocity = Vector3.ZERO
	global_position = pos
	Game.set_camera_target(self)
	Game.possess(self)
	Game.hint("Собрался. Как новенький. Ну, как подержанный.")
