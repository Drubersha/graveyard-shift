class_name GraveyardScene extends Node3D
## Кладбище — стартовая локация и задний двор особняка. Открытая могила (спавн),
## модельные надгробия (Spooky Graveyard), запертые ворота с рычагом снаружи
## (рука пролезает в щель под створками), фонари, скамейка, мёртвые деревья.

signal gate_opened

var spawn_point := Vector3(3, 0.5, 8)
var gate_lever: Lever
var walk_marker_out := Vector3(3, 0.3, 13.5)   # «пройдись туда»
var walk_marker_back := Vector3(3, 0.3, 8.6)   # «и обратно»
var gate_center := Vector3(0, 0.3, 2)
var gate_is_open := false
var _gate_l: StaticBody3D
var _gate_r: StaticBody3D

func _ready() -> void:
	_ground()
	_fence()
	_gate()
	_graves()
	_trees()
	_path_and_lamps()
	_bench()
	_scatter_decor()
	_crows()
	_warmup_props()

func _ground() -> void:
	# общая земля под кладбище и дом
	MeshLib.solid_box(self, Vector3(70, 1.0, 90), Vector3(0, -0.5, -12), MeshLib.GRASS)
	# невидимые стены по периметру мира
	for wall in [
		[Vector3(70, 8, 1), Vector3(0, 4, 33)],
		[Vector3(70, 8, 1), Vector3(0, 4, -57)],
		[Vector3(1, 8, 90), Vector3(-35, 4, -12)],
		[Vector3(1, 8, 90), Vector3(35, 4, -12)],
	]:
		MeshLib.solid_invisible(self, wall[0], wall[1])

func _fence() -> void:
	# кладбищенский забор: прямоугольник x±14, z 2..18, ворота на z=2 (в сторону дома)
	var rail_c := MeshLib.STONE_DARK
	for x in range(-14, 15, 2):
		MeshLib.solid_box(self, Vector3(0.18, 1.4, 0.18), Vector3(x, 0.7, 18), rail_c)
	MeshLib.solid_box(self, Vector3(28, 0.12, 0.1), Vector3(0, 1.25, 18), rail_c)
	for z in range(2, 19, 2):
		MeshLib.solid_box(self, Vector3(0.18, 1.4, 0.18), Vector3(-14, 0.7, z), rail_c)
		MeshLib.solid_box(self, Vector3(0.18, 1.4, 0.18), Vector3(14, 0.7, z), rail_c)
	MeshLib.solid_box(self, Vector3(0.1, 0.12, 16), Vector3(-14, 1.25, 10), rail_c)
	MeshLib.solid_box(self, Vector3(0.1, 0.12, 16), Vector3(14, 1.25, 10), rail_c)
	# передняя линия с проёмом ворот (|x| > 1.6)
	for x in range(-14, 15, 2):
		if absf(x) > 1.9:
			MeshLib.solid_box(self, Vector3(0.18, 1.4, 0.18), Vector3(x, 0.7, 2), rail_c)
	MeshLib.solid_box(self, Vector3(11.5, 0.12, 0.1), Vector3(-7.9, 1.25, 2), rail_c)
	MeshLib.solid_box(self, Vector3(11.5, 0.12, 0.1), Vector3(7.9, 1.25, 2), rail_c)
	# столбы ворот с черепами
	for sx in [-1.9, 1.9]:
		MeshLib.solid_box(self, Vector3(0.4, 2.2, 0.4), Vector3(sx, 1.1, 2), MeshLib.STONE)
		MeshLib.sphere(self, 0.14, Vector3(sx, 2.35, 2), MeshLib.BONE_DARK)
	# арка с вывеской — читается по E, чтобы не висела на пол-экрана
	MeshLib.box(self, Vector3(4.4, 0.35, 0.3), Vector3(0, 2.5, 2), MeshLib.STONE_DARK)
	SignPost.make(self, Vector3(0, 2.9, 2.0),
		"КЛАДБИЩЕ «ТИХАЯ ГАВАНЬ»\nмест нет, но для своих найдём", "Прочитать вывеску")

## Ворота кладбища: заперты, рычаг снаружи. Низ створок сплошной (скелет не
## дотянется), под ними щель 0.26 — оторванная рука проползает и жмёт рычаг.
func _gate() -> void:
	for side: float in [-1.0, 1.0]:
		var gate := StaticBody3D.new()
		gate.position = Vector3(side * 1.85, 0, 2)
		add_child(gate)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.75, 1.8, 0.08)
		col.shape = shape
		col.position = Vector3(-side * 0.875, 1.16, 0)
		gate.add_child(col)
		# сплошной лист снизу
		MeshLib.box(gate, Vector3(1.72, 0.62, 0.06), Vector3(-side * 0.875, 0.57, 0), MeshLib.METAL.darkened(0.45))
		# рама и прутья
		MeshLib.box(gate, Vector3(1.75, 0.07, 0.07), Vector3(-side * 0.875, 2.02, 0), MeshLib.METAL.darkened(0.3))
		MeshLib.box(gate, Vector3(1.75, 0.07, 0.07), Vector3(-side * 0.875, 0.9, 0), MeshLib.METAL.darkened(0.3))
		for i in 5:
			var bx := -side * (0.18 + i * 0.35)
			MeshLib.box(gate, Vector3(0.06, 1.15, 0.06), Vector3(bx, 1.46, 0), MeshLib.METAL.darkened(0.35))
			MeshLib.cone(gate, 0.06, 0.14, Vector3(bx, 2.1, 0), MeshLib.METAL.darkened(0.25))
		# накладка-замок у свободного края: перекрывает центральный стык,
		# чтобы нельзя было дёрнуть рычаг сквозь щель между створками
		MeshLib.box(gate, Vector3(0.42, 0.8, 0.07), Vector3(-side * 1.62, 1.28, 0), MeshLib.METAL.darkened(0.5))
		if side > 0:
			MeshLib.sphere(gate, 0.09, Vector3(-side * 1.62, 1.3, -0.08), MeshLib.BONE_DARK)
		if side < 0:
			_gate_l = gate
		else:
			_gate_r = gate
	# рычаг снаружи за воротами, на столбике
	MeshLib.solid_box(self, Vector3(0.22, 0.55, 0.22), Vector3(0, 0.28, 0.55), MeshLib.STONE_DARK)
	gate_lever = Lever.new()
	gate_lever.position = Vector3(0, 0.62, 0.55)
	gate_lever.rotation_degrees = Vector3(0, 180, 0)
	gate_lever.prompt = "Рычаг ворот"
	add_child(gate_lever)
	gate_lever.activated.connect(open_gate)

func open_gate() -> void:
	if gate_is_open:
		return
	gate_is_open = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_gate_l, "rotation_degrees:y", 95.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gate_r, "rotation_degrees:y", -95.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gate_opened.emit()

func _graves() -> void:
	# модельные надгробия Spooky Graveyard, расставлены ровной сеткой рядами
	const GRAVES := ["grave_01", "grave_02", "grave_03", "grave_05", "grave_06", "grave_07",
		"grave_08", "broken_grave_01", "broken_grave_02", "broken_grave_03", "grave_02"]
	const EPITAPHS := [
		"ЗДЕСЬ ЛЕЖИТ ГРЕГОРИ\nговорил, что подержит стремянку",
		"МАРТА, 1841–1898\nвсю жизнь копила. Накопила.",
		"СЭМ «ОСТОРОЖНЫЙ»\nпроверял, заряжено ли",
		"ЭДВАРД\nсказал: «да я быстро, тут рядом»",
		"МИССИС ХОЛЛОУЭЙ\nдиета. Строгая. Слишком.",
		"ЮНЫЙ ТОБИ\nхотел погладить чужую собаку",
		"ДОКТОР ПРАЙС\nлечил всех. Кроме себя.",
		"БАРНАБИ\nспорил с кучером о правилах",
		"АГНЕС\nставила чайник на ночь глядя",
		"НЕИЗВЕСТНЫЙ\nне подписал завещание. И плиту.",
		"ФИНЕАС ГРАУТ\nизобрёл летающий сундук. Один раз.",
		"ЛЮСИ\nчитала на ходу. Дочитала.",
		"СТАРЫЙ ХЬЮ\nпережил трёх жён и одну ступеньку",
		"ПОЛЛИ\nкормила ворон. Вороны помнят.",
		"МИСТЕР ДАРРОУ\nпоследние слова: «а что тут сложного»",
		"ГЕРТРУДА\nне верила в привидения. Теперь верит.",
	]
	const STEP_X := 4.0
	const STEP_Z := 4.0
	var occupied: Array[Vector2] = [Vector2(spawn_point.x, spawn_point.z), Vector2(-4, 6)]  # могила игрока и скамейка
	var idx := 0
	for col in 7:
		var x := -12.0 + col * STEP_X
		for row in 4:
			var z := 5.0 + row * STEP_Z
			var busy := false
			for o in occupied:
				if Vector2(x, z).distance_to(o) < 2.5:
					busy = true
			if busy:
				continue
			# лёгкий крен «от старости», но позиция строго по сетке
			var tilt := (idx % 3 - 1) * 3.0
			ModelLib.grave(self, GRAVES[idx % GRAVES.size()], Vector3(x, 0, z), tilt)
			MeshLib.box(self, Vector3(0.55, 0.08, 1.05), Vector3(x, 0.04, z - 0.7), MeshLib.DIRT.darkened(0.3))
			SignPost.make(self, Vector3(x, 1.5, z - 0.35), EPITAPHS[idx % EPITAPHS.size()], "Прочитать эпитафию")
			idx += 1
	# открытая могила игрока
	MeshLib.box(self, Vector3(1.0, 0.14, 2.0), Vector3(spawn_point.x, 0.02, spawn_point.z), Color(0.08, 0.06, 0.05))
	MeshLib.box(self, Vector3(1.3, 0.3, 0.4), Vector3(spawn_point.x, 0.1, spawn_point.z + 1.3), MeshLib.DIRT.darkened(0.25))
	ModelLib.grave(self, "grave_04", Vector3(spawn_point.x, 0, spawn_point.z - 1.2), 0)
	SignPost.make(self, Vector3(spawn_point.x, 1.5, spawn_point.z - 1.55),
		"ЗДЕСЬ БЫЛ Я\nи, кажется, до сих пор есть", "Прочитать свою эпитафию")

func _trees() -> void:
	# деревья — строго между узлами сетки надгробий и снаружи ограды
	for data in [Vector3(-6, 0, 7), Vector3(6, 0, 15), Vector3(-10, 0, 11), Vector3(10, 0, 7),
			Vector3(-16.5, 0, 12), Vector3(16.5, 0, 6), Vector3(-16.5, 0, 4), Vector3(16.5, 0, 15)]:
		var tree := Node3D.new()
		tree.position = data
		add_child(tree)
		MeshLib.cylinder(tree, 0.28, 3.4, Vector3(0, 1.7, 0), MeshLib.WOOD_DARK, Vector3(0, 0, randf_range(-7, 7)))
		# корявые голые ветки
		for j in 4:
			var ang := j * 90.0 + randf_range(-25, 25)
			MeshLib.cylinder(tree, 0.08, 1.6, Vector3(cos(deg_to_rad(ang)) * 0.7, 3.1 + j * 0.15, sin(deg_to_rad(ang)) * 0.7),
				MeshLib.WOOD_DARK, Vector3(randf_range(30, 70), ang, 0), 0.02)
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = 3.4
		col.shape = cyl
		col.position = Vector3(0, 1.7, 0)
		var body := StaticBody3D.new()
		body.add_child(col)
		tree.add_child(body)

func _path_and_lamps() -> void:
	# дорожка от ворот изгибается к кухонному крыльцу особняка (x -11, z ≈ -17)
	for i in 10:
		var z := 1.0 - i * 2.0
		var t := clampf((1.0 - z) / 17.0, 0.0, 1.0)
		var x := lerpf(0.0, -11.0, t * t * (3.0 - 2.0 * t))
		MeshLib.box(self, Vector3(2.2, 0.06, 1.8), Vector3(x, 0.03, z), MeshLib.DIRT.darkened(0.1))
	# фонари вдоль изгиба
	for z in [0.0, -7.0, -14.0]:
		var t := clampf((1.0 - z) / 17.0, 0.0, 1.0)
		var px := lerpf(0.0, -11.0, t * t * (3.0 - 2.0 * t))
		for sx in [-1.6, 1.6]:
			var lamp := Node3D.new()
			lamp.position = Vector3(px + sx, 0, z)
			add_child(lamp)
			MeshLib.solid_box(lamp, Vector3(0.12, 2.4, 0.12), Vector3(0, 1.2, 0), MeshLib.STONE_DARK)
			var bulb := MeshLib.sphere(lamp, 0.16, Vector3(0, 2.5, 0), Color(1.0, 0.85, 0.5))
			bulb.material_override = MeshLib.mat(Color(1.0, 0.85, 0.5), 1.0, 0.0, Color(1.0, 0.8, 0.4))
			var light := OmniLight3D.new()
			light.position = Vector3(0, 2.5, 0)
			light.light_color = Color(1.0, 0.8, 0.5)
			light.omni_range = 7.0
			light.light_energy = 1.4
			lamp.add_child(light)

func _bench() -> void:
	var bench := Node3D.new()
	bench.position = Vector3(-4.0, 0, 6.0)
	bench.rotation_degrees = Vector3(0, -30, 0)
	add_child(bench)
	MeshLib.solid_box(bench, Vector3(1.6, 0.08, 0.45), Vector3(0, 0.42, 0), MeshLib.WOOD)
	MeshLib.solid_box(bench, Vector3(1.6, 0.5, 0.08), Vector3(0, 0.75, 0.24), MeshLib.WOOD)
	for sx in [-0.7, 0.7]:
		MeshLib.solid_box(bench, Vector3(0.1, 0.42, 0.4), Vector3(sx, 0.21, 0), MeshLib.WOOD_DARK)
	var snap := SnapPoint.new()
	snap.position = Vector3(0, 0.35, -0.05)
	snap.prompt = "Присесть подумать"
	bench.add_child(snap)

func _scatter_decor() -> void:
	# косточки, камешки и пучки сухой травы — чисто визуальные, без коллизий.
	# Дорожку (|x| < 1.4) и зону спавна обходим с запасом.
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	for i in 24:
		var x := rng.randf_range(-13.0, 13.0)
		var z := rng.randf_range(3.0, 17.0)
		if absf(x) < 1.8 or Vector3(x, 0, z).distance_to(spawn_point) < 1.8:
			continue
		var pick := i % 3
		if pick == 0:
			# косточка, иногда пара крест-накрест
			MeshLib.capsule(self, 0.035, 0.28, Vector3(x, 0.035, z), MeshLib.BONE_DARK,
				Vector3(90, rng.randf_range(0, 360), 0))
			if i % 6 == 0:
				MeshLib.capsule(self, 0.035, 0.24, Vector3(x + 0.12, 0.035, z + 0.06), MeshLib.BONE_DARK,
					Vector3(90, rng.randf_range(0, 360), 0))
		elif pick == 1:
			# камешек — приплюснутая полузарытая сфера
			var r := rng.randf_range(0.06, 0.12)
			MeshLib.sphere(self, r, Vector3(x, r * 0.35, z), MeshLib.STONE_DARK.darkened(rng.randf_range(0.0, 0.2)), 0.6)
		else:
			# пучок сухой травы: три тонких конуса враскос
			var g := MeshLib.GRASS.darkened(0.25)
			for t in 3:
				var h := rng.randf_range(0.25, 0.45)
				MeshLib.cone(self, 0.025, h,
					Vector3(x + rng.randf_range(-0.08, 0.08), h * 0.45, z + rng.randf_range(-0.08, 0.08)),
					g.lightened(rng.randf_range(0.0, 0.1)),
					Vector3(rng.randf_range(-16, 16), 0, rng.randf_range(-16, 16)))

func _crows() -> void:
	# вороны-силуэты: две на заборе, одна на дереве
	var c := MeshLib.ROOF.darkened(0.6)
	for data in [
		[Vector3(-6.0, 1.31, 18.0), 180.0],
		[Vector3(14.0, 1.31, 7.0), -90.0],
		[Vector3(11.4, 3.5, 15.2), 210.0],
	]:
		var crow := Node3D.new()
		crow.position = data[0]
		var yaw: float = data[1]
		crow.rotation_degrees = Vector3(0, yaw, 0)
		add_child(crow)
		MeshLib.sphere(crow, 0.11, Vector3(0, 0.1, 0), c, 0.85)
		MeshLib.sphere(crow, 0.065, Vector3(0, 0.2, 0.08), c)
		MeshLib.cone(crow, 0.022, 0.09, Vector3(0, 0.2, 0.16), MeshLib.BONE_DARK.darkened(0.35), Vector3(90, 0, 0))
		MeshLib.box(crow, Vector3(0.05, 0.03, 0.14), Vector3(0, 0.09, -0.13), c, Vector3(-20, 0, 0))

func _warmup_props() -> void:
	# ломаемый хлам возле скамейки для разминки — RigidBody, в стороне от дорожки
	BreakableProp.make(self, "pot", Vector3(-3.1, 0.2, 5.0))
	BreakableProp.make(self, "crate", Vector3(-5.2, 0.3, 6.9), Vector3(0, 25, 0))
	BreakableProp.make(self, "skullpot", Vector3(-2.4, 0.16, 7.4))
