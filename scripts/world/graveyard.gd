class_name GraveyardScene extends Node3D
## Кладбище — стартовая локация. Открытая могила (спавн), надгробия, забор с
## воротами в сторону дома, фонари вдоль дорожки, скамейка, мёртвые деревья.

var spawn_point := Vector3(3, 0.5, 8)

func _ready() -> void:
	_ground()
	_fence()
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
	# арка с вывеской
	var arch := MeshLib.box(self, Vector3(4.4, 0.35, 0.3), Vector3(0, 2.5, 2), MeshLib.STONE_DARK)
	MeshLib.label(arch, "КЛАДБИЩЕ «ТИХАЯ ГАВАНЬ»", Vector3(0, 0.55, 0), 36, MeshLib.BONE)

func _graves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 14:
		var x := rng.randf_range(-12.0, 12.0)
		var z := rng.randf_range(4.5, 16.5)
		if absf(x) < 2.0 or Vector3(x, 0, z).distance_to(spawn_point) < 2.0:
			continue
		var tilt := Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 360), rng.randf_range(-10, 10))
		var kind := i % 5
		var has_mound := true
		if kind == 0:
			# классическая плита
			MeshLib.solid_box(self, Vector3(0.7, 0.9, 0.18), Vector3(x, 0.45, z), MeshLib.STONE if i % 2 == 0 else MeshLib.STONE_DARK, tilt)
		elif kind == 1:
			# обелиск: постамент + узкий высокий столб + каменное остриё
			var ob := Node3D.new()
			ob.position = Vector3(x, 0, z)
			ob.rotation_degrees = tilt
			add_child(ob)
			MeshLib.box(ob, Vector3(0.52, 0.18, 0.52), Vector3(0, 0.09, 0), MeshLib.STONE_DARK)
			MeshLib.solid_box(ob, Vector3(0.3, 1.5, 0.3), Vector3(0, 0.85, 0), MeshLib.STONE)
			MeshLib.cone(ob, 0.23, 0.45, Vector3(0, 1.8, 0), MeshLib.STONE_DARK)
		elif kind == 2:
			# крест
			MeshLib.solid_box(self, Vector3(0.16, 1.1, 0.16), Vector3(x, 0.55, z), MeshLib.STONE, tilt)
			MeshLib.box(self, Vector3(0.6, 0.14, 0.14), Vector3(x, 0.8, z), MeshLib.STONE, tilt)
		elif kind == 3:
			# сломанная колонна: покосившийся обломок и упавший кусок рядом
			MeshLib.cylinder(self, 0.17, 0.75, Vector3(x, 0.35, z), MeshLib.STONE, Vector3(tilt.x, tilt.y, 14 + tilt.z))
			MeshLib.cylinder(self, 0.15, 0.6, Vector3(x + 0.55, 0.15, z + 0.3), MeshLib.STONE_DARK, Vector3(90, tilt.y, 0))
		else:
			# плита, вросшая в землю
			MeshLib.box(self, Vector3(0.85, 0.06, 1.5), Vector3(x, 0.035, z - 0.5), MeshLib.STONE_DARK, Vector3(0, tilt.y, 0))
			MeshLib.box(self, Vector3(0.6, 0.05, 1.15), Vector3(x, 0.075, z - 0.5), MeshLib.STONE, Vector3(0, tilt.y, 0))
			has_mound = false
		if has_mound:
			# холмик: два перекрывающихся плоских бокса — ниже, меньше, темнее
			var mound_c := MeshLib.DIRT.darkened(0.3)
			MeshLib.box(self, Vector3(0.55, 0.08, 1.05), Vector3(x, 0.04, z - 0.7), mound_c, Vector3(0, tilt.y, 0))
			MeshLib.box(self, Vector3(0.38, 0.07, 0.8), Vector3(x, 0.09, z - 0.7), mound_c.lightened(0.05), Vector3(0, tilt.y + 12, 0))
	# открытая могила игрока
	MeshLib.box(self, Vector3(1.0, 0.14, 2.0), Vector3(spawn_point.x, 0.02, spawn_point.z), Color(0.08, 0.06, 0.05))
	MeshLib.box(self, Vector3(1.3, 0.3, 0.4), Vector3(spawn_point.x, 0.1, spawn_point.z + 1.3), MeshLib.DIRT.darkened(0.25))
	var stone := MeshLib.solid_box(self, Vector3(0.8, 1.0, 0.2), Vector3(spawn_point.x, 0.5, spawn_point.z - 1.2), MeshLib.STONE, Vector3(-6, 0, 3))
	MeshLib.label(stone, "ЗДЕСЬ\nБЫЛ Я", Vector3(0, 0.1, -0.15), 40, Color(0.2, 0.2, 0.25))

func _trees() -> void:
	for data in [Vector3(-11, 0, 16), Vector3(11.5, 0, 15), Vector3(-12, 0, 5), Vector3(9, 0, 4),
			Vector3(-13, 0, 12.5), Vector3(13, 0, 6.5)]:
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
	# дорожка от ворот к дому (дом на z ≈ -22.5)
	for i in 13:
		var z := 1.0 - i * 2.0
		MeshLib.box(self, Vector3(2.0, 0.06, 1.6), Vector3(randf_range(-0.15, 0.15), 0.03, z), MeshLib.DIRT.darkened(0.1))
	# фонари
	for z in [0.0, -8.0, -16.0]:
		for sx in [-1.6, 1.6]:
			var lamp := Node3D.new()
			lamp.position = Vector3(sx, 0, z)
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
