class_name Mansion extends Node3D
## Двухэтажный готический особняк некромантки. Задний фасад (+z) смотрит на
## кладбище — оно же задний двор. Вход с чёрного крыльца ведёт на кухню.
## Этаж 1: кухня, запертая кладовка (рычаг внутри, вентиляция для руки), зал
## с камином и лестницей. Этаж 2: спальня и библиотека.

const W := 12.0   # ширина (x)
const D := 9.0    # глубина (z)
const FH := 2.8   # высота этажа
const T := 0.3    # толщина внешних стен
const F2 := 2.96  # уровень пола 2-го этажа (верх плиты)

var back_door: DoorGate
var front_door: DoorGate
var pantry_door: DoorGate
var pantry_lever: Lever
var vent_marker: Node3D
var witch: WitchNPC
var couch_marker: Node3D
var meet_marker: Node3D
var sink: SinkCounter
var stove: Stove
var fridge: Fridge
var serve_zone: ServeZone
var broom: Broom
var dust_list: Array[DustPatch] = []
var dirty_plates: Array[BreakableProp] = []

func _ready() -> void:
	add_to_group("mansion")
	_floors()
	_exterior_walls()
	_interior_walls_f1()
	_interior_walls_f2()
	_stairs()
	_roof()
	_exterior_details()
	_kitchen()
	_pantry()
	_hall()
	_bedroom()
	_library()
	_witch_meet()
	_lights()

# ================================================================ каркас

func _floors() -> void:
	# пол 1-го этажа
	MeshLib.solid_box(self, Vector3(W, 0.12, D), Vector3(0, 0.06, 0), MeshLib.WOOD_DARK)
	# плита 2-го этажа с проёмом под лестницу (x -6..-4.6, z -4.0..0.5)
	MeshLib.solid_box(self, Vector3(10.6, 0.16, D), Vector3(0.7, 2.88, 0), MeshLib.WOOD_DARK)
	MeshLib.solid_box(self, Vector3(1.4, 0.16, 4.0), Vector3(-5.3, 2.88, 2.5), MeshLib.WOOD_DARK)
	MeshLib.solid_box(self, Vector3(1.4, 0.16, 0.5), Vector3(-5.3, 2.88, -4.25), MeshLib.WOOD_DARK)
	# потолок 2-го этажа
	MeshLib.solid_box(self, Vector3(W, 0.16, D), Vector3(0, 5.68, 0), MeshLib.HOUSE_TRIM)
	# перила вокруг проёма лестницы (на 2-м этаже)
	MeshLib.solid_box(self, Vector3(0.07, 0.9, 4.5), Vector3(-4.62, 3.41, -1.75), MeshLib.WOOD_DARK)
	MeshLib.solid_box(self, Vector3(1.4, 0.9, 0.07), Vector3(-5.3, 3.41, 0.46), MeshLib.WOOD_DARK)

func _exterior_walls() -> void:
	var wc := MeshLib.HOUSE_WALL
	var hz := D / 2.0
	var hx := W / 2.0
	# боковые — сплошные, во всю высоту
	MeshLib.solid_box(self, Vector3(T, 5.6, D), Vector3(-hx, 2.8, 0), wc)
	MeshLib.solid_box(self, Vector3(T, 5.6, D), Vector3(hx, 2.8, 0), wc)
	# задний фасад (к кладбищу): проём чёрного входа x -0.5..0.5, h 2.1
	MeshLib.solid_box(self, Vector3(5.5, 5.6, T), Vector3(-3.25, 2.8, hz), wc)
	MeshLib.solid_box(self, Vector3(5.5, 5.6, T), Vector3(3.25, 2.8, hz), wc)
	MeshLib.solid_box(self, Vector3(1.0, 3.38, T), Vector3(0, 3.91, hz), wc)
	# передний фасад (город, M2): проём парадной x -0.6..0.6
	MeshLib.solid_box(self, Vector3(5.4, 5.6, T), Vector3(-3.3, 2.8, -hz), wc)
	MeshLib.solid_box(self, Vector3(5.4, 5.6, T), Vector3(3.3, 2.8, -hz), wc)
	MeshLib.solid_box(self, Vector3(1.2, 3.38, T), Vector3(0, 3.91, -hz), wc)

func _interior_walls_f1() -> void:
	var wc := MeshLib.HOUSE_WALL.lightened(0.06)
	# стена кухня/кладовка ↔ зал (z = 0.5): проёмы — дверь кухни x 1.2..2.2
	# и дверь кладовки x -4.45..-3.55
	MeshLib.solid_box(self, Vector3(1.55, 2.76, 0.25), Vector3(-5.225, 1.5, 0.5), wc)
	MeshLib.solid_box(self, Vector3(4.75, 2.76, 0.25), Vector3(-1.175, 1.5, 0.5), wc)
	MeshLib.solid_box(self, Vector3(3.8, 2.76, 0.25), Vector3(4.1, 1.5, 0.5), wc)
	MeshLib.solid_box(self, Vector3(1.0, 0.66, 0.25), Vector3(1.7, 2.55, 0.5), wc)    # над дверью кухни
	MeshLib.solid_box(self, Vector3(0.9, 0.71, 0.25), Vector3(-4.0, 2.525, 0.5), wc)  # над дверью кладовки
	# стена кухня ↔ кладовка (x = -2) с вентиляцией у пола (z 2.2..2.7, h 0.45)
	MeshLib.solid_box(self, Vector3(0.25, 2.76, 1.7), Vector3(-2, 1.5, 1.35), wc)
	MeshLib.solid_box(self, Vector3(0.25, 2.76, 1.8), Vector3(-2, 1.5, 3.6), wc)
	MeshLib.solid_box(self, Vector3(0.25, 2.31, 0.5), Vector3(-2, 1.735, 2.45), wc)
	# рамка вентиляции со стороны кухни
	MeshLib.box(self, Vector3(0.08, 0.06, 0.6), Vector3(-1.85, 0.56, 2.45), MeshLib.METAL)
	for i in 3:
		MeshLib.box(self, Vector3(0.04, 0.4, 0.05), Vector3(-1.84, 0.32, 2.28 + i * 0.17), MeshLib.METAL, Vector3(14, 0, 0))
	vent_marker = Node3D.new()
	vent_marker.position = Vector3(-1.6, 0.3, 2.45)
	add_child(vent_marker)

func _interior_walls_f2() -> void:
	var wc := MeshLib.HOUSE_WALL.lightened(0.06)
	# стена спальня ↔ библиотека (x = 0) с дверным проёмом z -0.5..0.5
	MeshLib.solid_box(self, Vector3(0.25, 2.72, 4.0), Vector3(0, 4.24, -2.5), wc)
	MeshLib.solid_box(self, Vector3(0.25, 2.72, 4.0), Vector3(0, 4.24, 2.5), wc)
	MeshLib.solid_box(self, Vector3(0.25, 0.67, 1.0), Vector3(0, 5.265, 0), wc)

func _stairs() -> void:
	# пандус-коллизия + ступени-визуал: из зала (z 0.4) на 2-й этаж (z -4.0)
	MeshLib.solid_invisible(self, Vector3(1.2, 0.15, 5.25), Vector3(-5.4, 1.46, -1.8), Vector3(32.5, 0, 0))
	for i in 11:
		var frac := i / 10.0
		var z := 0.4 - frac * 4.4
		var h := 0.06 + frac * 2.8
		MeshLib.box(self, Vector3(1.2, 0.12, 0.46), Vector3(-5.4, h, z), MeshLib.WOOD if i % 2 == 0 else MeshLib.WOOD_DARK)
		MeshLib.box(self, Vector3(1.2, maxf(h - 0.05, 0.05), 0.4), Vector3(-5.4, h / 2.0, z), MeshLib.HOUSE_TRIM.darkened(0.2))
	# перила лестницы
	for i in 4:
		var z := 0.2 - i * 1.1
		var h := 2.8 * (0.4 - z) / 4.4
		MeshLib.box(self, Vector3(0.07, 0.85, 0.07), Vector3(-4.78, h + 0.42, z), MeshLib.WOOD_DARK)
	MeshLib.box(self, Vector3(0.07, 0.09, 5.2), Vector3(-4.78, 2.3, -1.8), MeshLib.WOOD_DARK, Vector3(32.5, 0, 0))

func _roof() -> void:
	MeshLib.solid_box(self, Vector3(13.4, 0.16, 5.6), Vector3(0, 7.1, 2.175), MeshLib.ROOF, Vector3(30, 0, 0))
	MeshLib.solid_box(self, Vector3(13.4, 0.16, 5.6), Vector3(0, 7.1, -2.175), MeshLib.ROOF, Vector3(-30, 0, 0))
	MeshLib.box(self, Vector3(13.5, 0.25, 0.5), Vector3(0, 8.55, 0), MeshLib.ROOF.darkened(0.2))
	# ступенчатые готические фронтоны на торцах
	for sx in [-5.95, 5.95]:
		MeshLib.box(self, Vector3(0.25, 0.9, 8.6), Vector3(sx, 6.05, 0), MeshLib.HOUSE_WALL)
		MeshLib.box(self, Vector3(0.25, 0.9, 5.4), Vector3(sx, 6.95, 0), MeshLib.HOUSE_WALL)
		MeshLib.box(self, Vector3(0.25, 0.9, 2.6), Vector3(sx, 7.85, 0), MeshLib.HOUSE_WALL)

func _exterior_details() -> void:
	var hz := D / 2.0
	# башня на углу у кухни
	var tower := Node3D.new()
	tower.position = Vector3(W / 2.0 + 0.35, 0, hz - 0.1)
	add_child(tower)
	MeshLib.solid_box(tower, Vector3(1.7, 7.2, 1.7), Vector3(0, 3.6, 0), MeshLib.HOUSE_WALL.darkened(0.1))
	MeshLib.cone(tower, 1.4, 2.6, Vector3(0, 8.5, 0), MeshLib.ROOF)
	_glow_panel(tower, Vector3(0.5, 0.7, 0.06), Vector3(0, 5.6, 0.87))
	MeshLib.cylinder(tower, 0.035, 1.3, Vector3(0, 10.3, 0), MeshLib.METAL)
	MeshLib.box(tower, Vector3(0.44, 0.24, 0.03), Vector3(0.25, 10.6, 0), MeshLib.WINE)
	# камин зала → труба снаружи восточной стены + дым
	MeshLib.box(self, Vector3(0.55, 3.4, 0.55), Vector3(6.35, 6.9, -2.0), MeshLib.STONE_DARK)
	var puffs := [[Vector3(6.4, 8.85, -2.0), 0.18], [Vector3(6.55, 9.3, -2.05), 0.26], [Vector3(6.8, 9.9, -2.1), 0.36]]
	for p in puffs:
		MeshLib.sphere(self, p[1], p[0], MeshLib.STONE.lightened(0.3), 0.9)
	# окна: этаж 1 зад (кухня/кладовка), этаж 2, перед
	_glow_panel(self, Vector3(0.8, 0.9, 0.05), Vector3(3.2, 1.8, hz + 0.17))
	_glow_panel(self, Vector3(0.7, 0.9, 0.05), Vector3(-4.0, 1.8, hz + 0.17))
	_glow_panel(self, Vector3(0.8, 1.0, 0.05), Vector3(-3.0, 4.35, hz + 0.17))
	_glow_panel(self, Vector3(0.8, 1.0, 0.05), Vector3(3.0, 4.35, hz + 0.17))
	for fx in [-3.0, 3.0]:
		_glow_panel(self, Vector3(0.8, 0.9, 0.05), Vector3(fx, 1.8, -hz - 0.17))
		_glow_panel(self, Vector3(0.8, 1.0, 0.05), Vector3(fx, 4.35, -hz - 0.17))
	for sx in [-W / 2.0 - 0.17, W / 2.0 + 0.17]:
		_glow_panel(self, Vector3(0.05, 1.0, 0.8), Vector3(sx, 4.35, -2.0))
	# заднее крыльцо (встреча с ведьмой) с козырьком
	MeshLib.solid_box(self, Vector3(3.4, 0.12, 1.9), Vector3(0, 0.06, hz + 0.95), MeshLib.STONE_DARK)
	MeshLib.box(self, Vector3(2.2, 0.1, 1.3), Vector3(0, 2.6, hz + 0.55), MeshLib.ROOF, Vector3(12, 0, 0))
	for px in [-1.0, 1.0]:
		MeshLib.box(self, Vector3(0.08, 2.5, 0.08), Vector3(px, 1.3, hz + 1.05), MeshLib.WOOD_DARK)
	# фонари у чёрного входа
	for lx in [-0.85, 0.85]:
		var lamp := MeshLib.box(self, Vector3(0.15, 0.2, 0.15), Vector3(lx, 2.25, hz + 0.3), MeshLib.HOUSE_TRIM)
		lamp.material_override = MeshLib.mat(MeshLib.HOUSE_TRIM, 0.6, 0.3, MeshLib.ACCENT)
	# переднее крыльцо (на будущую улицу)
	MeshLib.solid_box(self, Vector3(2.6, 0.12, 1.4), Vector3(0, 0.06, -hz - 0.75), MeshLib.STONE_DARK)
	# двери
	back_door = DoorGate.make(self, Vector3(-0.5, 0.12, hz), 0.0, 1.0, 2.05)
	back_door.prompt = "Войти в особняк"
	front_door = DoorGate.make(self, Vector3(-0.6, 0.12, -hz), 180.0, 1.2, 2.05)
	front_door.locked = true
	front_door.locked_hint = "Парадная. За ней город. Город спит. Не сегодня. (M2)"

func _glow_panel(parent: Node, size: Vector3, pos: Vector3) -> void:
	var p := MeshLib.box(parent, size, pos, Color(0.4, 0.6, 0.3))
	p.material_override = MeshLib.mat(Color(0.4, 0.6, 0.3), 1.0, 0.0, MeshLib.ACCENT)

# ================================================================ кухня

func _kitchen() -> void:
	# плита и холодильник у восточной стены
	stove = Stove.new()
	stove.position = Vector3(5.45, 0.12, 3.5)
	stove.rotation_degrees = Vector3(0, 90, 0)
	add_child(stove)
	fridge = Fridge.new()
	fridge.position = Vector3(5.45, 0.12, 1.2)
	fridge.rotation_degrees = Vector3(0, 90, 0)
	add_child(fridge)
	# мойка под окном задней стены
	sink = SinkCounter.new()
	sink.position = Vector3(3.2, 0.12, 4.1)
	sink.rotation_degrees = Vector3(0, 180, 0)
	add_child(sink)
	# столешница между дверью и мойкой + верхние шкафчики
	MeshLib.solid_box(self, Vector3(1.5, 0.9, 0.6), Vector3(1.9, 0.57, 4.05), MeshLib.WOOD_DARK)
	MeshLib.box(self, Vector3(1.54, 0.05, 0.64), Vector3(1.9, 1.05, 4.05), MeshLib.METAL)
	MeshLib.box(self, Vector3(1.5, 0.7, 0.4), Vector3(1.9, 2.2, 4.15), MeshLib.WOOD_DARK)
	for i in 3:
		MeshLib.cylinder(self, 0.04, 0.12, Vector3(1.5 + i * 0.35, 1.14, 4.1), [MeshLib.ACCENT, MeshLib.WINE, Color(0.8, 0.7, 0.3)][i])
	# яйца на столешнице
	BreakableProp.make(self, "egg", Vector3(1.55, 1.16, 3.95))
	BreakableProp.make(self, "egg", Vector3(2.25, 1.16, 4.0))
	# кухонный стол со стульями
	BreakableProp.make(self, "table", Vector3(1.8, 0.5, 2.0))
	BreakableProp.make(self, "chair", Vector3(0.8, 0.45, 2.2), Vector3(0, 80, 0))
	BreakableProp.make(self, "chair", Vector3(2.8, 0.45, 1.7), Vector3(0, -95, 0))
	# грязная посуда: на столе, на столешнице, на полу
	for ppos in [Vector3(1.6, 1.0, 1.8), Vector3(2.1, 1.0, 2.25),
			Vector3(1.35, 1.12, 4.0), Vector3(2.45, 1.12, 4.1), Vector3(0.3, 0.18, 3.4)]:
		var plate := BreakableProp.make(self, "plate_dirty", ppos)
		dirty_plates.append(plate)
	# бутылка вина для рецепта — прямо на кухне
	BreakableProp.make(self, "bottle", Vector3(4.7, 1.28, 4.05))
	# веник у двери
	broom = Broom.new()
	broom.position = Vector3(-1.3, 0.3, 4.0)
	broom.rotation_degrees = Vector3(0, 70, 0)
	add_child(broom)
	# пыль — цель уборки
	for dpos in [Vector3(0.5, 0.13, 1.4), Vector3(2.2, 0.13, 1.1), Vector3(4.6, 0.13, 2.2),
			Vector3(-0.9, 0.13, 2.6), Vector3(3.4, 0.13, 3.6), Vector3(1.2, 0.13, 3.1)]:
		dust_list.append(DustPatch.make(self, dpos, randf_range(0.4, 0.55)))
	# мелкий декор: ведро, разделочная доска
	MeshLib.box(self, Vector3(0.28, 0.04, 0.2), Vector3(2.3, 1.08, 3.9), MeshLib.WOOD)
	BreakableProp.make(self, "pot", Vector3(4.9, 0.25, 0.9))

# ================================================================ кладовка

func _pantry() -> void:
	pantry_door = DoorGate.make(self, Vector3(-4.45, 0.12, 0.5), 0.0, 0.9, 2.05)
	pantry_door.locked = true
	pantry_door.locked_hint = "Кладовка заперта изнутри. Зачем?.. Не спрашивай. В стене кухни у пола — вентиляция."
	pantry_lever = Lever.new()
	pantry_lever.position = Vector3(-3.7, 0.35, 0.85)
	pantry_lever.rotation_degrees = Vector3(0, 180, 0)
	pantry_lever.prompt = "Рычаг кладовки"
	add_child(pantry_lever)
	# мука — цель рейда
	BreakableProp.make(self, "flour", Vector3(-4.4, 0.35, 2.2))
	BreakableProp.make(self, "flour", Vector3(-3.2, 0.35, 3.4))
	# полки с хламом
	MeshLib.solid_box(self, Vector3(0.35, 0.05, 2.6), Vector3(-5.6, 1.0, 2.6), MeshLib.WOOD)
	MeshLib.solid_box(self, Vector3(0.35, 0.05, 2.6), Vector3(-5.6, 1.7, 2.6), MeshLib.WOOD)
	BreakableProp.make(self, "vase", Vector3(-5.55, 1.25, 2.0))
	BreakableProp.make(self, "skullpot", Vector3(-5.55, 1.86, 3.0))
	BreakableProp.make(self, "crate", Vector3(-2.8, 0.4, 3.9))
	BreakableProp.make(self, "crate", Vector3(-4.8, 0.4, 3.95))
	BreakableProp.make(self, "pot", Vector3(-3.9, 0.2, 2.9))

# ================================================================ зал

func _hall() -> void:
	# ковёр и диван у восточной стены, лицом к камину
	MeshLib.box(self, Vector3(3.4, 0.03, 2.6), Vector3(4.2, 0.14, -2.0), Color(0.35, 0.12, 0.2))
	couch_marker = Node3D.new()
	couch_marker.position = Vector3(2.8, 0.12, -2.0)
	couch_marker.rotation_degrees = Vector3(0, -90, 0)
	add_child(couch_marker)
	_build_couch(couch_marker)
	serve_zone = ServeZone.make(self, Vector3(4.2, 0.12, -2.0))
	# камин в восточной стене
	MeshLib.solid_box(self, Vector3(0.5, 1.5, 1.6), Vector3(5.6, 0.87, -2.0), MeshLib.STONE_DARK)
	MeshLib.box(self, Vector3(0.12, 0.95, 0.95), Vector3(5.32, 0.65, -2.0), Color(0.06, 0.04, 0.04))
	var fire := MeshLib.box(self, Vector3(0.15, 0.4, 0.65), Vector3(5.35, 0.4, -2.0), Color(1.0, 0.45, 0.1))
	fire.material_override = MeshLib.mat(Color(1.0, 0.45, 0.1), 1.0, 0.0, Color(1.0, 0.5, 0.1))
	MeshLib.box(self, Vector3(0.55, 0.1, 1.7), Vector3(5.55, 1.68, -2.0), MeshLib.WOOD_DARK)
	_candle(self, Vector3(5.5, 1.78, -1.5))
	_candle(self, Vector3(5.5, 1.78, -2.5))
	# столик с вином у дивана
	MeshLib.solid_box(self, Vector3(0.55, 0.5, 0.55), Vector3(2.7, 0.37, -0.7), MeshLib.WOOD_DARK)
	BreakableProp.make(self, "bottle", Vector3(2.6, 0.78, -0.6))
	BreakableProp.make(self, "bottle", Vector3(2.8, 0.78, -0.8))
	# люстра-канделябр
	MeshLib.cylinder(self, 0.02, 0.5, Vector3(0, 2.62, -1.5), MeshLib.METAL)
	MeshLib.cylinder(self, 0.5, 0.06, Vector3(0, 2.35, -1.5), MeshLib.METAL.darkened(0.3))
	for i in 6:
		var ang := i * TAU / 6.0
		_candle(self, Vector3(cos(ang) * 0.42, 2.4, -1.5 + sin(ang) * 0.42), 0.1)
	# прочая мебель зала
	BreakableProp.make(self, "shelf", Vector3(-3.5, 0.97, -4.05))
	BreakableProp.make(self, "tv", Vector3(0.5, 0.85, -4.0), Vector3(0, 180, 0))
	BreakableProp.make(self, "crate", Vector3(0.5, 0.3, -4.0))
	BreakableProp.make(self, "lamp", Vector3(-1.5, 0.82, -0.2))
	BreakableProp.make(self, "vase", Vector3(-3.2, 0.32, 0.0))

func _build_couch(parent: Node3D) -> void:
	var c := MeshLib.WITCH_DRESS.lightened(0.12)
	MeshLib.solid_box(parent, Vector3(2.3, 0.4, 0.95), Vector3(0, 0.3, 0), c)
	MeshLib.solid_box(parent, Vector3(2.3, 0.7, 0.25), Vector3(0, 0.75, 0.42), c)
	MeshLib.solid_box(parent, Vector3(0.28, 0.45, 0.95), Vector3(-1.12, 0.62, 0), c)
	MeshLib.solid_box(parent, Vector3(0.28, 0.45, 0.95), Vector3(1.12, 0.62, 0), c)
	for sx in [-1.0, 1.0]:
		MeshLib.box(parent, Vector3(0.08, 0.2, 0.08), Vector3(sx, 0.1, 0.35), MeshLib.WOOD_DARK)

# ================================================================ этаж 2

func _bedroom() -> void:
	# кровать с балдахином у задней стены
	var bed := Node3D.new()
	bed.position = Vector3(-3.0, F2, 3.2)
	add_child(bed)
	MeshLib.solid_box(bed, Vector3(2.0, 0.35, 1.5), Vector3(0, 0.175, 0), MeshLib.WOOD_DARK)
	MeshLib.box(bed, Vector3(1.9, 0.18, 1.4), Vector3(0, 0.44, 0), MeshLib.WITCH_DRESS.lightened(0.2))
	MeshLib.box(bed, Vector3(0.5, 0.12, 0.35), Vector3(-0.55, 0.56, 0.45), MeshLib.BONE)
	MeshLib.box(bed, Vector3(0.5, 0.12, 0.35), Vector3(0.15, 0.56, 0.45), MeshLib.BONE)
	for corner in [Vector3(-0.95, 0, -0.7), Vector3(0.95, 0, -0.7), Vector3(-0.95, 0, 0.7), Vector3(0.95, 0, 0.7)]:
		MeshLib.box(bed, Vector3(0.08, 1.9, 0.08), corner + Vector3(0, 0.95, 0), MeshLib.WOOD_DARK)
	MeshLib.box(bed, Vector3(2.1, 0.06, 1.6), Vector3(0, 1.92, 0), MeshLib.WITCH_DRESS.darkened(0.2))
	# шкаф и туалетный столик
	BreakableProp.make(self, "shelf", Vector3(-5.55, F2 + 0.85, 0.0), Vector3(0, 90, 0))
	MeshLib.solid_box(self, Vector3(0.9, 0.75, 0.4), Vector3(-1.6, F2 + 0.375, 4.1), MeshLib.WOOD_DARK)
	var mirror := MeshLib.box(self, Vector3(0.6, 0.8, 0.04), Vector3(-1.6, F2 + 1.3, 4.32), Color(0.6, 0.75, 0.8))
	mirror.material_override = MeshLib.mat(Color(0.6, 0.75, 0.8), 0.2, 0.6, Color(0.3, 0.4, 0.45))
	BreakableProp.make(self, "vase", Vector3(-1.85, F2 + 0.97, 4.05))
	BreakableProp.make(self, "bottle", Vector3(-1.35, F2 + 0.95, 4.15))
	# ковёр и свечи
	MeshLib.box(self, Vector3(2.2, 0.03, 1.6), Vector3(-3.0, F2 + 0.02, 1.6), Color(0.3, 0.1, 0.18))
	_candle(self, Vector3(-5.5, F2 + 0.02, 3.8))
	_candle(self, Vector3(-0.4, F2 + 0.02, 3.9))

func _library() -> void:
	BreakableProp.make(self, "shelf", Vector3(5.5, F2 + 0.85, 1.5), Vector3(0, 90, 0))
	BreakableProp.make(self, "shelf", Vector3(5.5, F2 + 0.85, -1.0), Vector3(0, 90, 0))
	BreakableProp.make(self, "shelf", Vector3(3.0, F2 + 0.85, -4.05))
	BreakableProp.make(self, "table", Vector3(2.8, F2 + 0.375, 0.5))
	BreakableProp.make(self, "chair", Vector3(2.0, F2 + 0.33, 1.3), Vector3(0, 140, 0))
	# глобус мира, до которого никому нет дела
	MeshLib.cylinder(self, 0.16, 0.5, Vector3(1.2, F2 + 0.25, -1.8), MeshLib.WOOD_DARK)
	MeshLib.sphere(self, 0.28, Vector3(1.2, F2 + 0.75, -1.8), Color(0.25, 0.4, 0.35))
	# стопки книг
	for bpos in [Vector3(4.2, F2 + 0.06, 2.9), Vector3(1.6, F2 + 0.06, -3.5)]:
		for i in 3:
			MeshLib.box(self, Vector3(0.28 - i * 0.04, 0.06, 0.2), bpos + Vector3(0, i * 0.065, 0),
				[MeshLib.WINE, MeshLib.ACCENT.darkened(0.4), MeshLib.STONE][i])
	_candle(self, Vector3(3.1, F2 + 0.79, 0.3), 0.1)
	MeshLib.box(self, Vector3(2.4, 0.03, 1.8), Vector3(3.0, F2 + 0.02, 0.3), Color(0.16, 0.2, 0.3))

func _candle(parent: Node, pos: Vector3, size := 0.16) -> void:
	MeshLib.cylinder(parent, 0.035, size, pos + Vector3(0, size / 2.0, 0), MeshLib.BONE)
	var flame := MeshLib.sphere(parent, 0.028, pos + Vector3(0, size + 0.04, 0), Color(1.0, 0.8, 0.4), 1.4)
	flame.material_override = MeshLib.mat(Color(1.0, 0.8, 0.4), 1.0, 0.0, Color(1.0, 0.7, 0.3))

# ================================================================ ведьма и свет

func _witch_meet() -> void:
	meet_marker = Node3D.new()
	meet_marker.position = Vector3(1.1, 0.12, D / 2.0 + 0.8)
	meet_marker.rotation_degrees = Vector3(0, 180, 0)
	add_child(meet_marker)
	witch = WitchNPC.new()
	witch.position = meet_marker.position
	witch.rotation_degrees = meet_marker.rotation_degrees
	add_child(witch)

func _lights() -> void:
	var specs := [
		[Vector3(2.0, 2.35, 2.5), Color(1.0, 0.8, 0.55), 8.0, 1.0],    # кухня
		[Vector3(0, 2.4, -1.5), Color(1.0, 0.75, 0.5), 9.0, 1.0],      # зал (люстра)
		[Vector3(5.1, 1.0, -2.0), Color(1.0, 0.5, 0.15), 5.0, 1.5],    # камин
		[Vector3(-3.0, 5.1, 1.0), Color(0.9, 0.7, 0.6), 7.0, 0.8],     # спальня
		[Vector3(3.0, 5.1, 0.0), Color(0.9, 0.75, 0.55), 7.0, 0.8],    # библиотека
		[Vector3(0, 2.6, D / 2.0 + 0.9), MeshLib.ACCENT, 6.0, 1.2],    # заднее крыльцо
		[Vector3(-4.0, 0.9, 2.5), Color(0.8, 0.75, 0.6), 4.0, 0.5],    # кладовка (тускло)
	]
	for s in specs:
		var light := OmniLight3D.new()
		light.position = s[0]
		light.light_color = s[1]
		light.omni_range = s[2]
		light.light_energy = s[3]
		add_child(light)
