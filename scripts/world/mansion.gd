class_name Mansion extends Node3D
## Особняк некромантки 4.0 — просторный двухкрылый manor 44×20.
## Задний фасад (+z) выходит на кладбище-задний двор, чёрный вход ведёт на кухню.
## Парадный вход перекрыт невидимой стеной (город — это M2).
##
## Этаж 1: парадный зал (атриум на два света с двумя лестницами), кухня,
## обеденный зал, швейная, туалет W, коридор W — запад; зал шабаша, амулетная,
## зельеварочная (заперта: рычаг + вентиляция), туалет E, коридор E — восток.
## Из кухни и из зала шабаша — спуски в подвал (отдельная локация).
## Этаж 2: гостиная (диван хозяйки), спальни 1-3, туалет W — запад;
## библиотека с сатанинским кругом, спальни 4-5, кладовка мётел, туалет E — восток.

const W := 44.0
const D := 20.0
const HX := 22.0        # половина ширины
const HZ := 10.0        # половина глубины
const T := 0.4          # внешние стены
const WT := 0.3         # внутренние стены
const FLOOR_Y := 0.2    # уровень пола 1-го этажа
const SLAB_BOT := 3.4   # низ плиты 2-го этажа
const F2 := 3.6         # пол 2-го этажа
const CEIL := 7.2       # низ потолка
const DOOR_H := 2.4     # высота дверных проёмов
const H1 := SLAB_BOT - FLOOR_Y
const H2 := CEIL - F2
const HALL_HX := 7.0    # полуширина парадного зала
const WING_X := 15.0    # внутренняя перегородка крыла

const BACK_DOOR_X := -11.0
const SHAFT_W := Rect2(-10.5, 1.5, 2.5, 3.5)   # спуск в подвал: кухня
const SHAFT_E := Rect2(8.0, 1.5, 2.5, 3.5)     # спуск в подвал: зал шабаша
const SHAFT_BOTTOM := -1.8

const HS := ModelLib.HOUSE_SCALE
const FS := ModelLib.FURN_SCALE

var mode := "interior"   # "exterior" — оболочка для улицы, "interior" — комнаты
var portals: Array[Portal] = []
var spawns := {}

var front_door: DoorGate
var pantry_door: DoorGate      # зельеварочная (миссия «мука»)
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

var _mat_floor1: StandardMaterial3D
var _mat_floor2: StandardMaterial3D
var _mat_wall_out: StandardMaterial3D
var _mat_wall_in: StandardMaterial3D
var _mat_stone: StandardMaterial3D

func _ready() -> void:
	add_to_group("mansion")
	_materials()
	_ext_walls()
	if mode == "exterior":
		_exterior()
		spawns["back_porch"] = Vector3(BACK_DOOR_X, FLOOR_Y + 0.2, HZ + 2.2)
		portals.append(Portal.make(self, Vector3(BACK_DOOR_X, FLOOR_Y, HZ + 0.7),
			"Войти в особняк", "indoor", "kitchen_door"))
		_witch_meet()
		return
	_floors()
	_stairs_main()
	_walls_f1()
	_walls_f2()
	_grand_hall()
	_kitchen()
	_dining()
	_sewing()
	_toilet_w1()
	_corridor_w1()
	_sabbath()
	_amulet()
	_potion_room()
	_toilet_e1()
	_corridor_e1()
	_living_room()
	_bedrooms_west()
	_toilet_w2()
	_library()
	_bedrooms_east()
	_broom_closet()
	_toilet_e2()
	_shafts()
	_windows_inside()
	_witch_on_couch()
	_lights()
	spawns["kitchen_door"] = Vector3(BACK_DOOR_X, FLOOR_Y + 0.2, HZ - 1.6)
	spawns["kitchen_stairs"] = Vector3(SHAFT_W.position.x + SHAFT_W.size.x / 2.0, FLOOR_Y + 0.2, SHAFT_W.position.y - 1.2)
	spawns["sabbath_stairs"] = Vector3(SHAFT_E.position.x + SHAFT_E.size.x / 2.0, FLOOR_Y + 0.2, SHAFT_E.position.y - 1.2)
	portals.append(Portal.make(self, Vector3(BACK_DOOR_X, FLOOR_Y, HZ - 0.55),
		"Выйти во двор", "outdoor", "back_porch"))

func _materials() -> void:
	_mat_floor1 = ModelLib.pbr_mat("Mahogany_Planks", Color(0.85, 0.8, 0.78), 0.35)
	_mat_floor2 = ModelLib.pbr_mat("Oak_Parquet_01", Color(0.82, 0.78, 0.72), 0.4)
	_mat_wall_out = ModelLib.tex_mat("wood_panel.png", Color(0.5, 0.42, 0.62), 0.4)
	_mat_wall_in = ModelLib.tex_mat("wood_panel.png", Color(0.78, 0.7, 0.78), 0.45)
	_mat_stone = ModelLib.tex_mat("stone_light.png", Color(0.75, 0.78, 0.85), 0.4)

# ================================================================ хелперы

func _wall(size: Vector3, pos: Vector3, outer := false) -> StaticBody3D:
	var body := MeshLib.solid_box(self, size, pos, Color.WHITE)
	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _mat_wall_out if outer else _mat_wall_in
	return body

## Стена вдоль X с проёмами. openings: [[x_from, x_to], ...] или [[x0, x1, высота]].
## Проёмы обязаны идти по возрастанию.
func _wall_row_x(z: float, x0: float, x1: float, y0: float, h: float, openings := [], outer := false) -> void:
	var thick := T if outer else WT
	var cursor := x0
	for op: Array in openings:
		if op[0] > cursor:
			_wall(Vector3(op[0] - cursor, h, thick), Vector3((cursor + op[0]) / 2.0, y0 + h / 2.0, z), outer)
		var top: float = op[2] if op.size() > 2 else DOOR_H
		if h > top:
			_wall(Vector3(op[1] - op[0], h - top, thick), Vector3((op[0] + op[1]) / 2.0, y0 + top + (h - top) / 2.0, z), outer)
		cursor = op[1]
	if cursor < x1:
		_wall(Vector3(x1 - cursor, h, thick), Vector3((cursor + x1) / 2.0, y0 + h / 2.0, z), outer)

## Стена вдоль Z с проёмами.
func _wall_row_z(x: float, z0: float, z1: float, y0: float, h: float, openings := [], outer := false) -> void:
	var thick := T if outer else WT
	var cursor := z0
	for op: Array in openings:
		if op[0] > cursor:
			_wall(Vector3(thick, h, op[0] - cursor), Vector3(x, y0 + h / 2.0, (cursor + op[0]) / 2.0), outer)
		var top: float = op[2] if op.size() > 2 else DOOR_H
		if h > top:
			_wall(Vector3(thick, h - top, op[1] - op[0]), Vector3(x, y0 + top + (h - top) / 2.0, (op[0] + op[1]) / 2.0), outer)
		cursor = op[1]
	if cursor < z1:
		_wall(Vector3(thick, h, z1 - cursor), Vector3(x, y0 + h / 2.0, (cursor + z1) / 2.0), outer)

func _floor_rect(x0: float, z0: float, x1: float, z1: float, y_top: float, mat: Material) -> void:
	var s := MeshLib.solid_box(self, Vector3(x1 - x0, 0.2, z1 - z0),
		Vector3((x0 + x1) / 2.0, y_top - 0.1, (z0 + z1) / 2.0), Color.WHITE)
	for child in s.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat

func _tile(x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var mi := MeshLib.box(self, Vector3(x1 - x0, 0.03, z1 - z0),
		Vector3((x0 + x1) / 2.0, y + 0.015, (z0 + z1) / 2.0), Color.WHITE)
	mi.material_override = _mat_stone

func _candle(parent: Node, pos: Vector3, size := 0.16) -> void:
	MeshLib.cylinder(parent, 0.035, size, pos + Vector3(0, size / 2.0, 0), MeshLib.BONE)
	var flame := MeshLib.sphere(parent, 0.028, pos + Vector3(0, size + 0.04, 0), Color(1.0, 0.8, 0.4), 1.4)
	flame.material_override = MeshLib.mat(Color(1.0, 0.8, 0.4), 1.0, 0.0, Color(1.0, 0.7, 0.3))

func _lamp(pos: Vector3, color: Color, range_: float, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_
	l.light_energy = energy
	add_child(l)

# ================================================================ каркас

func _ext_walls() -> void:
	# боковые
	_wall_row_z(-HX, -HZ, HZ, FLOOR_Y, CEIL - FLOOR_Y, [], true)
	_wall_row_z(HX, -HZ, HZ, FLOOR_Y, CEIL - FLOOR_Y, [], true)
	# задний фасад: чёрный вход в кухню
	_wall_row_x(HZ, -HX, HX, FLOOR_Y, CEIL - FLOOR_Y,
		[[BACK_DOOR_X - 0.9, BACK_DOOR_X + 0.9]], true)
	# передний фасад: парадные двери (перекрыты невидимой стеной — город в M2)
	_wall_row_x(-HZ, -HX, HX, FLOOR_Y, CEIL - FLOOR_Y, [[-1.8, 1.8, 2.8]], true)
	MeshLib.solid_invisible(self, Vector3(3.6, 2.8, 0.5), Vector3(0, FLOOR_Y + 1.4, -HZ))

func _floors() -> void:
	# пол 1-го этажа: полосы с вырезами под спуски в подвал
	_floor_rect(-HX, -HZ, HX, SHAFT_W.position.y, FLOOR_Y, _mat_floor1)
	var z_end := SHAFT_W.position.y + SHAFT_W.size.y
	_floor_rect(-HX, SHAFT_W.position.y, SHAFT_W.position.x, z_end, FLOOR_Y, _mat_floor1)
	_floor_rect(SHAFT_W.position.x + SHAFT_W.size.x, SHAFT_W.position.y, SHAFT_E.position.x, z_end, FLOOR_Y, _mat_floor1)
	_floor_rect(SHAFT_E.position.x + SHAFT_E.size.x, SHAFT_W.position.y, HX, z_end, FLOOR_Y, _mat_floor1)
	_floor_rect(-HX, z_end, HX, HZ, FLOOR_Y, _mat_floor1)
	# плита 2-го этажа: крылья целиком + балкон над задней частью зала
	_floor_rect(-HX, -HZ, -HALL_HX, HZ, F2, _mat_floor2)
	_floor_rect(HALL_HX, -HZ, HX, HZ, F2, _mat_floor2)
	_floor_rect(-HALL_HX, 4.0, HALL_HX, HZ, F2, _mat_floor2)
	# потолок
	MeshLib.solid_box(self, Vector3(W, 0.2, D), Vector3(0, CEIL + 0.1, 0), MeshLib.HOUSE_TRIM)
	# ограждение балкона по краю атриума (кроме мест, где приходят лестницы)
	for seg in [[-HALL_HX, -4.8], [-2.4, 2.4], [4.8, HALL_HX]]:
		MeshLib.solid_box(self, Vector3(seg[1] - seg[0], 1.0, 0.1),
			Vector3((seg[0] + seg[1]) / 2.0, F2 + 0.5, 4.0), MeshLib.WOOD_DARK)
		ModelLib.tex_box(self, Vector3(seg[1] - seg[0], 0.08, 0.16),
			Vector3((seg[0] + seg[1]) / 2.0, F2 + 1.02, 4.0), "gold_band.png", Color(1, 0.95, 0.8), 0.8)

## Две парадные лестницы в пустоте атриума: снизу от входа — вверх на балкон.
func _stairs_main() -> void:
	for sx: float in [-1.0, 1.0]:
		var cx: float = sx * 3.6      # ближе к центру: у стен крыльев должны быть свободные проходы
		var run := 12.0     # z от -8 до 4
		var rise: float = F2 - FLOOR_Y
		var angle := rad_to_deg(atan2(rise, run))
		var slope := sqrt(run * run + rise * rise)
		# Наклонная плита-коллизия. Толстая и утопленная: её верхняя грань точно
		# совпадает с линией ступеней, а торцы прячутся под перекрытия — иначе
		# на стыке с полом торчит порог, об который спуск застревает.
		var thick := 0.8
		MeshLib.solid_invisible(self, Vector3(2.0, thick, slope + 2.4),
			Vector3(cx, (FLOOR_Y + F2) / 2.0 - (thick / 2.0) / cos(deg_to_rad(angle)), -2.0),
			Vector3(-angle, 0, 0))
		# ступени
		for i in 20:
			var frac := i / 19.0
			var z := -8.0 + frac * run
			var y := FLOOR_Y + frac * rise
			ModelLib.tex_box(self, Vector3(2.0, 0.12, 0.62), Vector3(cx, y, z),
				"wood_planks.png", Color(0.66, 0.6, 0.55), 0.4)
			ModelLib.tex_box(self, Vector3(1.94, maxf(y - FLOOR_Y, 0.05), 0.5),
				Vector3(cx, FLOOR_Y + (y - FLOOR_Y) / 2.0, z), "wood_panel.png", Color(0.45, 0.36, 0.3), 0.5)
		# перила с обеих сторон
		for rx: float in [cx - 1.05, cx + 1.05]:
			MeshLib.solid_box(self, Vector3(0.08, 0.95, slope),
				Vector3(rx, (FLOOR_Y + F2) / 2.0 + 0.5, -2.0), MeshLib.WOOD_DARK, Vector3(-angle, 0, 0))
			ModelLib.tex_box(self, Vector3(0.14, 0.09, slope),
				Vector3(rx, (FLOOR_Y + F2) / 2.0 + 1.0, -2.0), "gold_band.png", Color(1, 0.95, 0.8), 0.8, Vector3(-angle, 0, 0))
		# столбы у подножия
		ModelLib.tex_solid_box(self, Vector3(0.34, 1.5, 0.34), Vector3(cx - 1.05, FLOOR_Y + 0.75, -8.4),
			"wood_panel.png", Color(0.4, 0.32, 0.28), 0.6)
		ModelLib.tex_solid_box(self, Vector3(0.34, 1.5, 0.34), Vector3(cx + 1.05, FLOOR_Y + 0.75, -8.4),
			"wood_panel.png", Color(0.4, 0.32, 0.28), 0.6)

# ================================================================ стены этажей

func _walls_f1() -> void:
	# зал ↔ крылья
	_wall_row_z(-HALL_HX, -HZ, HZ, FLOOR_Y, H1, [[-6.8, -5.0], [5.0, 6.8]])
	_wall_row_z(HALL_HX, -HZ, HZ, FLOOR_Y, H1, [[-6.8, -5.0], [5.0, 6.8]])
	# запад: север/юг (кухня+столовая | коридор+швейная)
	_wall_row_x(0.0, -HX, -HALL_HX, FLOOR_Y, H1, [[-13.0, -11.2]])
	_wall_row_z(-WING_X, 0.0, HZ, FLOOR_Y, H1, [[4.0, 5.8]])          # кухня ↔ столовая
	_wall_row_z(-WING_X, -HZ, 0.0, FLOOR_Y, H1, [[-5.8, -4.0]])       # коридор ↔ швейная
	# туалет W1 (угол коридора)
	_wall_row_z(-11.5, -HZ, -7.0, FLOOR_Y, H1)
	_wall_row_x(-7.0, -WING_X, -11.5, FLOOR_Y, H1, [[-13.6, -12.4]])
	_tile(-WING_X, -HZ, -11.5, -7.0, FLOOR_Y)
	# восток: север/юг
	_wall_row_x(0.0, HALL_HX, HX, FLOOR_Y, H1, [[11.2, 13.0]])
	_wall_row_z(WING_X, 0.0, HZ, FLOOR_Y, H1, [[4.0, 5.8]])           # шабаш ↔ амулетная
	# зельеварочная: дверь + вентиляция у пола (проём высотой 0.55)
	_wall_row_z(WING_X, -HZ, 0.0, FLOOR_Y, H1, [[-5.8, -4.0], [-2.4, -1.6, 0.55]])
	# туалет E1
	_wall_row_z(11.5, -HZ, -7.0, FLOOR_Y, H1)
	_wall_row_x(-7.0, 11.5, WING_X, FLOOR_Y, H1, [[12.4, 13.6]])
	_tile(11.5, -HZ, WING_X, -7.0, FLOOR_Y)
	_tile(WING_X, -HZ, HX, 0.0, FLOOR_Y)   # каменный пол зельеварочной

func _walls_f2() -> void:
	# зал ↔ крылья: глухо над пустотой, проёмы с балкона
	_wall_row_z(-HALL_HX, -HZ, HZ, F2, H2, [[6.0, 7.8]])
	_wall_row_z(HALL_HX, -HZ, HZ, F2, H2, [[6.0, 7.8]])
	# --- запад
	_wall_row_x(4.0, -WING_X, -HALL_HX, F2, H2, [[-11.0, -9.2]])      # гостиная ↔ коридор
	_wall_row_z(-WING_X, 4.0, HZ, F2, H2, [[5.2, 7.0]])               # гостиная ↔ спальня 1
	_wall_row_z(-WING_X, -2.0, 4.0, F2, H2, [[0.0, 1.8]])             # коридор ↔ спальня 2
	_wall_row_z(-WING_X, -HZ, -2.0, F2, H2, [[-5.0, -3.2]])           # коридор ↔ спальня 3
	_wall_row_x(-6.5, -WING_X, -11.5, F2, H2, [[-13.6, -12.4]])       # туалет W2
	_wall_row_z(-11.5, -HZ, -6.5, F2, H2)
	_tile(-WING_X, -HZ, -11.5, -6.5, F2)
	# --- восток
	_wall_row_x(3.0, HALL_HX, HX, F2, H2, [[8.5, 10.3]])              # библиотека ↔ коридор
	_wall_row_z(WING_X, -2.0, 3.0, F2, H2, [[0.0, 1.8]])              # коридор ↔ спальня 4
	_wall_row_z(WING_X, -HZ, -2.0, F2, H2, [[-5.0, -3.2]])            # коридор ↔ спальня 5
	_wall_row_x(-6.5, 11.5, WING_X, F2, H2, [[12.4, 13.6]])           # туалет E2
	_wall_row_z(11.5, -HZ, -7.5, F2, H2)
	_wall_row_x(-7.5, HALL_HX, 11.5, F2, H2, [[8.4, 9.6]])            # кладовка мётел
	_tile(11.5, -HZ, WING_X, -6.5, F2)

# ================================================================ парадный зал

func _grand_hall() -> void:
	front_door = DoorGate.make_model(self, Vector3(-1.8, FLOOR_Y, -HZ), 180.0, 3.6, 2.8,
		ModelLib.HOUSE + "Door_Double.fbx")
	front_door.locked = true
	front_door.locked_hint = "Парадные двери заколочены. За ними город, а город — это уже другая история. (M2)"
	# ковровая дорожка от дверей к лестницам
	ModelLib.tex_box(self, Vector3(3.0, 0.03, 11.0), Vector3(0, FLOOR_Y + 0.015, -4.0),
		"wood_panel.png", Color(0.55, 0.13, 0.18), 0.5)
	# люстра под самым потолком атриума — иначе висит перед лицом на балконе
	var chandelier := ModelLib.visual(self, ModelLib.KIT + "Chandelier.gltf", Vector3(0, CEIL - 0.75, -2.0), 0.0, 1.1)
	MeshLib.cylinder(chandelier, 0.025, 0.7, Vector3(0, 0.7, 0), MeshLib.METAL)
	# колонны вдоль зала — строго между проёмами крыльев (z 5..6.8 и -6.8..-5)
	for cz: float in [-8.6, -2.0, 2.0, 8.6]:
		for cx: float in [-6.4, 6.4]:
			ModelLib.tex_solid_box(self, Vector3(0.55, H1, 0.55), Vector3(cx, FLOOR_Y + H1 / 2.0, cz),
				"stone_light.png", Color(0.7, 0.72, 0.8), 0.4)
	# баннеры и знамёна на торцевой стене
	ModelLib.visual(self, ModelLib.KIT + "Banner_1.gltf", Vector3(-3.6, 4.6, -HZ + 0.35))
	ModelLib.visual(self, ModelLib.KIT + "Banner_2.gltf", Vector3(3.6, 4.6, -HZ + 0.35))
	ModelLib.gothic_ornament(self, 1.6, Vector3(0, 5.2, -HZ + 0.3), 0, 2)
	# мебель — вплотную к задней стене зала, вне створов проёмов и лестниц
	ModelLib.solid(self, ModelLib.KIT + "Bench.gltf", Vector3(-4.6, FLOOR_Y, 9.3), 180)
	ModelLib.solid(self, ModelLib.KIT + "Bench.gltf", Vector3(4.6, FLOOR_Y, 9.3), 180)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_1.fbx", Vector3(-6.4, FLOOR_Y, 9.3), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_3.fbx", Vector3(6.4, FLOOR_Y, 9.3), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_Round.fbx", Vector3(0, FLOOR_Y + 0.02, 8.0), 0, HS * 1.4)
	_candle_stand_pair(Vector3(-6.4, FLOOR_Y, -0.6), Vector3(6.4, FLOOR_Y, -0.6))

func _candle_stand_pair(a: Vector3, b: Vector3) -> void:
	ModelLib.solid(self, ModelLib.KIT + "CandleStick_Stand.gltf", a)
	ModelLib.solid(self, ModelLib.KIT + "CandleStick_Stand.gltf", b)

# ================================================================ запад, этаж 1

func _kitchen() -> void:
	# кухня x -15..-7, z 0..10. Проёмы: x=-7 (z 5..6.8), z=0 (x -13..-11.2),
	# x=-15 (z 4..5.8), задняя дверь (x -11.9..-10.1), спуск в подвал x -10.5..-8, z 1.5..5.
	# Рабочий треугольник стоит единым блоком у ГЛУХОЙ части задней стены (левее двери).
	fridge = Fridge.new()
	fridge.model_path = ModelLib.HOUSE + "Kitchen_Fridge.fbx"
	fridge.position = Vector3(-14.3, FLOOR_Y, 9.25)
	add_child(fridge)
	stove = Stove.new()
	stove.model_path = ModelLib.HOUSE + "Kitchen_Oven_Large.fbx"
	stove.position = Vector3(-13.3, FLOOR_Y, 9.3)
	add_child(stove)
	sink = SinkCounter.new()
	sink.model_path = ModelLib.HOUSE + "Kitchen_Sink.fbx"
	sink.position = Vector3(-12.4, FLOOR_Y, 9.3)
	add_child(sink)
	# тумбы и шкафчики — по бокам блока, всё у стен, столов и стульев на кухне нет
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_2Drawers.fbx", Vector3(-9.6, FLOOR_Y, 9.3), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_1Drawers.fbx", Vector3(-8.6, FLOOR_Y, 9.3), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_Cabinet1.fbx", Vector3(-13.3, FLOOR_Y + 1.9, 9.5), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_CabinetSmall.fbx", Vector3(-9.0, FLOOR_Y + 1.9, 9.5), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_2Drawers.fbx", Vector3(-14.6, FLOOR_Y, 7.2), 90, HS)
	# пыль по всей кухне, обходя лестничный проём и дверные створы
	for dpos in [Vector3(-13.2, FLOOR_Y, 2.2), Vector3(-12.6, FLOOR_Y, 7.9), Vector3(-8.6, FLOOR_Y, 6.6),
			Vector3(-13.0, FLOOR_Y, 0.9), Vector3(-14.0, FLOOR_Y, 6.2), Vector3(-11.6, FLOOR_Y, 8.4)]:
		dust_list.append(DustPatch.make(self, dpos, 0.55))
	ModelLib.solid(self, ModelLib.HOUSE + "Trashcan_Small1.fbx", Vector3(-7.7, FLOOR_Y, 8.9), 0, HS)
	_lamp(Vector3(-11.0, 3.0, 6.0), Color(1.0, 0.8, 0.55), 10.0, 1.1)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Ceiling1.fbx", Vector3(-11.0, SLAB_BOT - 0.05, 6.0), 0, HS)

func _dining() -> void:
	# x -22..-15, z 0..10; проём в стене x=-15 при z 4..5.8
	ModelLib.solid(self, ModelLib.KIT + "Table_Large.gltf", Vector3(-18.5, FLOOR_Y, 7.4), 0)
	for i in 3:
		ModelLib.solid(self, ModelLib.HOUSE + "Chair_1.fbx", Vector3(-19.7 + i * 1.2, FLOOR_Y, 8.5), 180, HS)
		ModelLib.solid(self, ModelLib.HOUSE + "Chair_1.fbx", Vector3(-19.7 + i * 1.2, FLOOR_Y, 6.3), 0, HS)
	# грязная посуда после вчерашнего — ровно две, их и моем
	for ppos in [Vector3(-19.3, FLOOR_Y + 0.85, 7.8), Vector3(-17.7, FLOOR_Y + 0.85, 7.1)]:
		dirty_plates.append(BreakableProp.make(self, "plate_dirty", ppos))
	# место, куда чистые тарелки просятся обратно
	ModelLib.visual(self, ModelLib.HOUSE + "Plate_1.fbx", Vector3(-20.2, FLOOR_Y + 0.78, 7.2), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Plate_2.fbx", Vector3(-16.9, FLOOR_Y + 0.78, 7.9), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_CabinetSmall.fbx", Vector3(-21.0, FLOOR_Y, 2.0), 90, HS)
	ModelLib.solid(self, ModelLib.FURN + "Closet.fbx", Vector3(-16.2, FLOOR_Y, 1.4), -90, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Curtains_Double.fbx", Vector3(-18.5, FLOOR_Y, 9.5), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_2.fbx", Vector3(-18.5, FLOOR_Y + 0.02, 7.4), 0, HS * 1.3)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Chandelier.fbx", Vector3(-18.5, SLAB_BOT - 0.05, 7.4), 0, HS)
	_lamp(Vector3(-18.5, 2.9, 6.0), Color(1.0, 0.75, 0.5), 9.0, 0.9)

func _sewing() -> void:
	# x -22..-15, z -10..0; проём в стене x=-15 при z -5.8..-4
	ModelLib.solid(self, ModelLib.KIT + "Dummy.gltf", Vector3(-17.4, FLOOR_Y, -2.6), 30)
	ModelLib.solid(self, ModelLib.KIT + "Workbench_Drawers.gltf", Vector3(-19.6, FLOOR_Y, -8.6), 0)
	ModelLib.solid(self, ModelLib.KIT + "Workbench.gltf", Vector3(-16.6, FLOOR_Y, -8.6), 0)
	ModelLib.solid(self, ModelLib.FURN + "Closet2.fbx", Vector3(-21.0, FLOOR_Y, -5.0), 90, FS)
	ModelLib.solid(self, ModelLib.FURN + "Stool.fbx", Vector3(-19.2, FLOOR_Y, -7.0), 0, FS)
	ModelLib.visual(self, ModelLib.FURN + "Lamp.fbx", Vector3(-16.4, FLOOR_Y, -1.2), 0, FS)
	for i in 3:
		ModelLib.tex_box(self, Vector3(0.28, 1.5, 0.28), Vector3(-21.0 + i * 0.4, FLOOR_Y + 0.75, -1.4),
			"wood_panel.png", [Color(0.6, 0.2, 0.3), Color(0.3, 0.2, 0.5), Color(0.2, 0.4, 0.3)][i], 0.9,
			Vector3(0, 0, randf_range(-7, 7)))
	ModelLib.visual(self, ModelLib.KIT + "Peg_Rack.gltf", Vector3(-18.5, 1.9, -9.7))
	ModelLib.grab(self, ModelLib.KIT + "Pouch_Large.gltf", Vector3(-16.8, FLOOR_Y + 0.95, -8.4), 1.0)
	_lamp(Vector3(-18.5, 2.9, -5.0), Color(0.95, 0.8, 0.6), 9.0, 0.85)

func _toilet_w1() -> void:
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet.fbx", Vector3(-14.2, FLOOR_Y, -9.2), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Sink.fbx", Vector3(-12.2, FLOOR_Y, -9.4), 180, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_Mirror1.fbx", Vector3(-12.2, FLOOR_Y + 1.5, -9.75), 180, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_ToiletPaper.fbx", Vector3(-14.5, FLOOR_Y + 0.9, -8.4), 90, HS)
	_lamp(Vector3(-13.2, 2.8, -8.5), Color(0.85, 0.9, 0.95), 5.0, 0.7)

func _corridor_w1() -> void:
	# x -15..-7, z -10..0 (минус туалет). Проёмы: x=-7 (z -6.8..-5), z=0 (x -13..-11.2), x=-15 (z -5.8..-4)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_1.fbx", Vector3(-7.7, FLOOR_Y, -2.2), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_5.fbx", Vector3(-7.7, FLOOR_Y, -8.6), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_1.fbx", Vector3(-10.0, FLOOR_Y + 0.02, -3.0), 90, HS)
	ModelLib.visual(self, ModelLib.KIT + "Lantern_Wall.gltf", Vector3(-9.6, 2.1, -0.2))
	_lamp(Vector3(-10.5, 2.8, -4.0), Color(0.9, 0.8, 0.65), 8.0, 0.75)

# ================================================================ восток, этаж 1

func _sabbath() -> void:
	# x 7..15, z 0..10; спуск в подвал x 8..10.5, z 1.5..5
	ModelLib.solid(self, ModelLib.HOUSE + "Table_RoundLarge.fbx", Vector3(12.4, FLOOR_Y, 7.4), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_Round.fbx", Vector3(12.4, FLOOR_Y + 0.02, 7.4), 0, HS * 1.8)
	var seats := [ModelLib.KIT + "Stool.gltf", ModelLib.HOUSE + "Stool.fbx", ModelLib.KIT + "Bench.gltf",
		ModelLib.HOUSE + "Chair_3.fbx", ModelLib.KIT + "Stool.gltf", ModelLib.HOUSE + "Chair_4.fbx"]
	for i in seats.size():
		var ang := i * TAU / seats.size()
		var sp := Vector3(12.4 + cos(ang) * 2.2, FLOOR_Y, 7.4 + sin(ang) * 2.2)
		var sc: float = 1.0 if (seats[i] as String).begins_with(ModelLib.KIT) else HS
		ModelLib.solid(self, seats[i], sp, rad_to_deg(-ang) + 90, sc)
	ModelLib.solid(self, ModelLib.KIT + "CandleStick_Triple.gltf", Vector3(12.4, FLOOR_Y + 0.85, 7.4))
	for tx: float in [7.4, 14.6]:
		ModelLib.visual(self, ModelLib.KIT + "Torch_Metal.gltf", Vector3(tx, 2.0, 8.6), 90 if tx < 10 else -90)
	ModelLib.visual(self, ModelLib.KIT + "Banner_2.gltf", Vector3(12.4, 2.9, 9.6))
	ModelLib.solid(self, ModelLib.KIT + "Chest_Wood.gltf", Vector3(14.2, FLOOR_Y, 1.0), -35)
	_lamp(Vector3(12.4, 3.0, 7.0), Color(1.0, 0.7, 0.45), 10.0, 1.0)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Ceiling3.fbx", Vector3(12.4, SLAB_BOT - 0.05, 7.4), 0, HS)

func _amulet() -> void:
	# x 15..22, z 0..10; проём в стене x=15 при z 4..5.8
	ModelLib.solid(self, ModelLib.KIT + "Workbench.gltf", Vector3(18.5, FLOOR_Y, 9.2), 0)
	ModelLib.visual(self, ModelLib.KIT + "Chalice.gltf", Vector3(18.1, FLOOR_Y + 0.9, 9.2))
	ModelLib.grab(self, ModelLib.KIT + "Key_Gold.gltf", Vector3(18.9, FLOOR_Y + 0.9, 9.1), 0.5)
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Arch.gltf", Vector3(21.0, FLOOR_Y, 7.6), -90)
	ModelLib.visual(self, ModelLib.KIT + "Scroll_1.gltf", Vector3(21.0, FLOOR_Y + 1.35, 7.6))
	ModelLib.visual(self, ModelLib.KIT + "Coin_Pile.gltf", Vector3(20.4, FLOOR_Y, 2.4))
	ModelLib.visual(self, ModelLib.KIT + "Coin_Pile_2.gltf", Vector3(20.9, FLOOR_Y, 2.9))
	ModelLib.grab(self, ModelLib.KIT + "Cage_Small.gltf", Vector3(16.4, FLOOR_Y, 1.4), 3.0)
	ModelLib.solid(self, ModelLib.KIT + "Anvil.gltf", Vector3(16.6, FLOOR_Y, 8.8), 20)
	ModelLib.visual(self, ModelLib.KIT + "Lantern_Wall.gltf", Vector3(18.5, 2.1, 9.7))
	ModelLib.solid(self, ModelLib.KIT + "CandleStick_Stand.gltf", Vector3(21.2, FLOOR_Y, 1.2))
	_lamp(Vector3(18.5, 2.9, 6.5), Color(1.0, 0.8, 0.55), 9.0, 0.9)

func _potion_room() -> void:
	# x 15..22, z -10..0 — ЗАПЕРТА. Дверь x=15 (z -5.8..-4), вентиляция (z -2.4..-1.6, h 0.55)
	pantry_door = DoorGate.make_model(self, Vector3(WING_X, FLOOR_Y, -5.8), -90.0, 1.8, 2.35,
		ModelLib.HOUSE + "Door_5.fbx")
	pantry_door.locked = true
	pantry_door.locked_hint = "Зельеварочная заперта изнутри. В стене у пола — вентиляция, рука пролезет."
	pantry_lever = Lever.new()
	pantry_lever.position = Vector3(WING_X + 0.45, FLOOR_Y + 0.35, -4.6)
	pantry_lever.rotation_degrees = Vector3(0, 90, 0)
	pantry_lever.prompt = "Рычаг зельеварочной"
	add_child(pantry_lever)
	vent_marker = Node3D.new()
	vent_marker.position = Vector3(WING_X - 0.55, FLOOR_Y + 0.25, -2.0)
	add_child(vent_marker)
	for i in 3:
		MeshLib.box(self, Vector3(0.05, 0.42, 0.05), Vector3(WING_X - 0.2, FLOOR_Y + 0.26, -2.3 + i * 0.22),
			MeshLib.METAL, Vector3(14, 0, 0))
	ModelLib.solid(self, ModelLib.KIT + "Cauldron.gltf", Vector3(18.6, FLOOR_Y, -5.0), 0)
	var brew := MeshLib.cylinder(self, 0.42, 0.06, Vector3(18.6, FLOOR_Y + 0.68, -5.0), MeshLib.ACCENT)
	brew.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Small_Bottles.gltf", Vector3(21.2, FLOOR_Y, -7.6), -90)
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Simple.gltf", Vector3(21.2, FLOOR_Y + 1.3, -3.0), -90)
	for pdata in [["Potion_1.gltf", Vector3(16.4, FLOOR_Y, -8.6)], ["Potion_2.gltf", Vector3(16.9, FLOOR_Y, -8.9)],
			["Potion_4.gltf", Vector3(21.0, FLOOR_Y + 1.45, -3.0)]]:
		ModelLib.grab(self, ModelLib.KIT + (pdata[0] as String), pdata[1] as Vector3, 1.0)
	ModelLib.solid(self, ModelLib.KIT + "Barrel.gltf", Vector3(16.2, FLOOR_Y, -1.4), 0)
	ModelLib.grab(self, ModelLib.KIT + "Bucket_Wooden_1.gltf", Vector3(20.4, FLOOR_Y, -9.2), 2.0)
	ModelLib.visual(self, ModelLib.KIT + "SmallBottles_1.gltf", Vector3(21.1, FLOOR_Y + 1.05, -7.2))
	# МУКА — цель рейда
	BreakableProp.make(self, "flour", Vector3(18.2, FLOOR_Y + 0.3, -2.6))
	BreakableProp.make(self, "flour", Vector3(19.6, FLOOR_Y + 0.3, -7.4))
	_lamp(Vector3(18.5, 2.6, -5.0), MeshLib.ACCENT, 8.0, 0.9)

func _toilet_e1() -> void:
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet2.fbx", Vector3(14.2, FLOOR_Y, -9.2), -90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_WashingMachine.fbx", Vector3(12.1, FLOOR_Y, -9.4), 180, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_Mirror2.fbx", Vector3(14.75, FLOOR_Y + 1.5, -8.4), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_ToiletPaperPile.fbx", Vector3(11.9, FLOOR_Y, -7.6), 0, HS)
	_lamp(Vector3(13.2, 2.8, -8.5), Color(0.85, 0.9, 0.95), 5.0, 0.7)

func _corridor_e1() -> void:
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_2.fbx", Vector3(7.7, FLOOR_Y, -2.2), 90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_7.fbx", Vector3(7.7, FLOOR_Y, -8.6), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_2.fbx", Vector3(10.0, FLOOR_Y + 0.02, -3.0), 90, HS)
	ModelLib.visual(self, ModelLib.KIT + "Lantern_Wall.gltf", Vector3(9.6, 2.1, -0.2))
	_lamp(Vector3(10.5, 2.8, -4.0), Color(0.9, 0.8, 0.65), 8.0, 0.75)

# ================================================================ запад, этаж 2

func _living_room() -> void:
	# x -15..-7, z 4..10. Вход с балкона (x=-7, z 6..7.8), в коридор (z=4, x -11..-9.2)
	# спинкой к северной стене, сиденьем в комнату
	ModelLib.solid(self, ModelLib.HOUSE + "Couch_Large1.fbx", Vector3(-12.6, F2, 9.1), 0, HS)
	# сидит на подушках лицом в комнату, а не за спинкой
	couch_marker = Node3D.new()
	couch_marker.position = Vector3(-12.6, F2 + 0.42, 8.55)
	couch_marker.rotation_degrees = Vector3(0, 0, 0)
	add_child(couch_marker)
	serve_zone = ServeZone.make(self, Vector3(-12.6, F2, 7.3))
	var fp := ModelLib.solid(self, ModelLib.HOUSE + "Fireplace.fbx", Vector3(-12.6, F2, 4.6), 0, HS)
	var fire := MeshLib.box(fp, Vector3(0.8, 0.4, 0.2), Vector3(0, 0.35, -0.1), Color(1.0, 0.45, 0.1))
	fire.material_override = MeshLib.mat(Color(1.0, 0.45, 0.1), 1.0, 0.0, Color(1.0, 0.5, 0.1))
	ModelLib.solid(self, ModelLib.FURN + "CoffeeTable.fbx", Vector3(-12.6, F2, 6.6), 0, FS)
	BreakableProp.make(self, "bottle", Vector3(-12.8, F2 + 0.62, 6.5))
	BreakableProp.make(self, "bottle", Vector3(-12.4, F2 + 0.62, 6.75))
	ModelLib.solid(self, ModelLib.FURN + "SofaDouble.fbx", Vector3(-8.4, F2, 8.4), -90, FS)
	ModelLib.solid(self, ModelLib.FURN + "SofaLong.fbx", Vector3(-14.2, F2, 7.0), 90, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Floor1.fbx", Vector3(-14.3, F2, 9.4), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_1.fbx", Vector3(-12.6, F2 + 0.02, 7.2), 0, HS * 1.3)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_8.fbx", Vector3(-7.8, F2, 9.5), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Ceiling5.fbx", Vector3(-12.6, CEIL - 0.05, 7.4), 0, HS)
	_lamp(Vector3(-12.6, F2 + 2.4, 7.4), Color(1.0, 0.75, 0.5), 9.0, 1.0)
	_lamp(Vector3(-12.6, F2 + 0.9, 5.2), Color(1.0, 0.5, 0.15), 4.5, 1.3)

func _bedrooms_west() -> void:
	# спальня 1: x -22..-15, z 4..10 (вход z 5.2..7)
	ModelLib.solid(self, ModelLib.HOUSE + "Bed_King.fbx", Vector3(-19.4, F2, 8.4), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "NightStand_1.fbx", Vector3(-21.0, F2, 9.3), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "NightStand_2.fbx", Vector3(-17.6, F2, 9.3), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Stand1.fbx", Vector3(-21.0, F2 + 0.55, 9.3), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_3.fbx", Vector3(-16.0, F2, 5.0), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_Round.fbx", Vector3(-19.4, F2 + 0.02, 5.8), 0, HS)
	_lamp(Vector3(-19.0, F2 + 2.4, 7.4), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# спальня 2: x -22..-15, z -2..4 (вход z 0..1.8)
	ModelLib.solid(self, ModelLib.FURN + "BedKing.fbx", Vector3(-19.6, F2, -0.4), 90, FS)
	ModelLib.solid(self, ModelLib.FURN + "Closet2.fbx", Vector3(-16.2, F2, 3.0), 180, FS)
	ModelLib.solid(self, ModelLib.FURN + "CoffeeTable2.fbx", Vector3(-16.4, F2, -1.2), 0, FS)
	ModelLib.visual(self, ModelLib.FURN + "Lamp2.fbx", Vector3(-21.2, F2, -1.4), 0, FS)
	ModelLib.solid(self, ModelLib.FURN + "Vase2.fbx", Vector3(-21.2, F2, 3.2), 0, FS)
	_lamp(Vector3(-19.0, F2 + 2.4, 1.0), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# спальня 3: x -22..-15, z -10..-2 (вход z -5..-3.2)
	ModelLib.solid(self, ModelLib.HOUSE + "Bed_Single.fbx", Vector3(-20.4, F2, -8.2), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bed_Bunk.fbx", Vector3(-16.4, F2, -8.4), -90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "NightStand_3.fbx", Vector3(-20.6, F2, -6.2), 90, HS)
	ModelLib.solid(self, ModelLib.FURN + "BookCase.fbx", Vector3(-18.4, F2, -9.5), 0, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Desk.fbx", Vector3(-20.6, F2 + 0.5, -6.2), 0, HS)
	_lamp(Vector3(-19.0, F2 + 2.4, -6.5), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# коридор
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_5.fbx", Vector3(-7.8, F2, -5.0), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_2.fbx", Vector3(-10.5, F2 + 0.02, -2.0), 90, HS * 1.2)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_2.fbx", Vector3(-7.8, F2, 2.6), 0, HS)
	_lamp(Vector3(-11.0, F2 + 2.4, -2.0), Color(0.9, 0.8, 0.65), 8.0, 0.7)

func _toilet_w2() -> void:
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet.fbx", Vector3(-14.3, F2, -9.2), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Shower1.fbx", Vector3(-12.2, F2, -9.3), 180, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_Towel.fbx", Vector3(-14.7, F2 + 1.2, -7.6), 90, HS)
	_lamp(Vector3(-13.2, F2 + 2.3, -8.4), Color(0.85, 0.9, 0.95), 5.0, 0.7)

# ================================================================ восток, этаж 2

func _library() -> void:
	# x 7..22, z 3..10; вход с балкона (x=7, z 6..7.8) и из коридора (z=3, x 8.5..10.3)
	ModelLib.solid(self, ModelLib.HOUSE + "Bookshelf.fbx", Vector3(9.0, F2, 9.4), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bookshelf.fbx", Vector3(11.6, F2, 9.4), 180, HS)
	ModelLib.solid(self, ModelLib.FURN + "BookCaseLargeBooks.fbx", Vector3(21.2, F2, 7.0), -90, FS)
	ModelLib.solid(self, ModelLib.FURN + "BookCaseBooks.fbx", Vector3(21.2, F2, 4.6), -90, FS)
	ModelLib.solid(self, ModelLib.HOUSE + "Shelf_Large.fbx", Vector3(17.0, F2 + 1.6, 9.7), 180, HS)
	ModelLib.solid(self, ModelLib.KIT + "BookStand.gltf", Vector3(15.6, F2, 4.4), 160)
	ModelLib.solid(self, ModelLib.FURN + "ChairHandle.fbx", Vector3(8.6, F2, 4.6), 45, FS)
	for bdata in [["Book_Stack_1.gltf", Vector3(13.4, F2, 9.2)], ["BookGroup_Medium_1.gltf", Vector3(19.6, F2, 9.3)],
			["Book_Stack_2.gltf", Vector3(8.2, F2, 6.4)], ["BookGroup_Small_1.gltf", Vector3(20.8, F2, 3.6)]]:
		ModelLib.grab(self, ModelLib.KIT + (bdata[0] as String), bdata[1] as Vector3, 1.0)
	_satanic_circle(Vector3(15.6, F2 + 0.02, 7.0), 2.4)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Ceiling2.fbx", Vector3(15.6, CEIL - 0.05, 7.0), 0, HS)
	_lamp(Vector3(12.0, F2 + 2.6, 7.0), Color(1.0, 0.8, 0.55), 10.0, 0.85)

## Сатанинский круг: багровое кольцо, пентаграмма, свечи по вершинам.
func _satanic_circle(center: Vector3, radius: float) -> void:
	var ring := MeshLib.cylinder(self, radius + 0.15, 0.02, center, Color(0.55, 0.06, 0.08))
	ring.material_override = MeshLib.mat(Color(0.55, 0.06, 0.08), 1.0, 0.0, Color(0.4, 0.02, 0.03))
	MeshLib.cylinder(self, radius - 0.06, 0.025, center + Vector3(0, 0.004, 0), Color(0.12, 0.08, 0.1))
	var pts: Array[Vector3] = []
	for i in 5:
		var ang := -PI / 2.0 + i * TAU / 5.0
		pts.append(center + Vector3(cos(ang) * (radius - 0.15), 0.012, sin(ang) * (radius - 0.15)))
	for i in 5:
		var a := pts[i]
		var b := pts[(i + 2) % 5]
		var mid := (a + b) / 2.0
		var dir := b - a
		var line := MeshLib.box(self, Vector3(dir.length(), 0.015, 0.09), mid, Color(0.75, 0.1, 0.12))
		line.rotation.y = -atan2(dir.z, dir.x)
		line.material_override = MeshLib.mat(Color(0.75, 0.1, 0.12), 1.0, 0.0, Color(0.5, 0.04, 0.05))
	for p in pts:
		ModelLib.solid(self, ModelLib.KIT + "CandleStick.gltf", Vector3(p.x, F2, p.z) + (p - center).normalized() * 0.4)
	BreakableProp.make(self, "skullpot", center + Vector3(0.4, 0.2, 0.3))
	ModelLib.grab(self, ModelLib.KIT + "Scroll_2.gltf", center + Vector3(-0.3, 0.1, -0.2), 0.5)
	var rl := OmniLight3D.new()
	rl.position = center + Vector3(0, 1.3, 0)
	rl.light_color = Color(0.9, 0.15, 0.1)
	rl.omni_range = 5.5
	rl.light_energy = 1.5
	add_child(rl)

func _bedrooms_east() -> void:
	# спальня 4: x 15..22, z -2..3 (вход z 0..1.8)
	ModelLib.solid(self, ModelLib.FURN + "Bed.fbx", Vector3(19.6, F2, -0.6), -90, FS)
	ModelLib.solid(self, ModelLib.KIT + "Nightstand_Shelf.gltf", Vector3(21.0, F2, 1.6), -90)
	ModelLib.solid(self, ModelLib.FURN + "Closet.fbx", Vector3(16.4, F2, 2.4), 180, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Cube.fbx", Vector3(21.0, F2 + 0.75, 1.6), 0, HS)
	_lamp(Vector3(19.0, F2 + 2.4, 0.5), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# спальня 5: x 15..22, z -10..-2 (вход z -5..-3.2)
	ModelLib.solid(self, ModelLib.FURN + "BedKing.fbx", Vector3(19.4, F2, -8.2), 180, FS)
	ModelLib.solid(self, ModelLib.KIT + "Nightstand_Shelf.gltf", Vector3(21.2, F2, -9.2), -90)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_4.fbx", Vector3(16.2, F2, -9.3), 90, HS)
	ModelLib.solid(self, ModelLib.FURN + "Plant.fbx", Vector3(16.4, F2, -2.8), 0, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Small.fbx", Vector3(21.2, F2 + 0.75, -9.2), 0, HS)
	_lamp(Vector3(19.0, F2 + 2.4, -6.5), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# коридор
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_2.fbx", Vector3(10.5, F2 + 0.02, -2.0), 90, HS * 1.2)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_1.fbx", Vector3(7.8, F2, -5.0), 90, HS)
	ModelLib.visual(self, ModelLib.KIT + "Lantern_Wall.gltf", Vector3(7.35, F2 + 2.0, -1.0), 90)
	_lamp(Vector3(10.5, F2 + 2.4, -2.5), Color(0.9, 0.8, 0.65), 8.0, 0.7)

func _broom_closet() -> void:
	# x 7..11.5, z -10..-7.5; дверь в стене z=-7.5 (x 8.4..9.6)
	ModelLib.visual(self, ModelLib.KIT + "Peg_Rack.gltf", Vector3(9.2, F2 + 1.7, -9.7))
	broom = Broom.new()
	broom.position = Vector3(8.4, F2 + 0.3, -8.6)
	broom.rotation_degrees = Vector3(0, 40, 0)
	add_child(broom)
	for bpos in [Vector3(10.4, F2 + 0.3, -8.4), Vector3(9.6, F2 + 0.3, -9.3)]:
		var extra := Broom.new()
		extra.position = bpos
		extra.rotation_degrees = Vector3(0, randf_range(0, 180), 0)
		add_child(extra)
	ModelLib.grab(self, ModelLib.KIT + "Bucket_Metal.gltf", Vector3(10.8, F2, -9.5), 2.0)
	ModelLib.solid(self, ModelLib.KIT + "Crate_Wooden.gltf", Vector3(7.6, F2, -9.4), 15)
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Simple.gltf", Vector3(11.15, F2 + 1.1, -8.8), -90)
	DustPatch.make(self, Vector3(9.8, F2, -8.0), 0.45)   # ирония: в кладовке мётел пыльно
	_lamp(Vector3(9.2, F2 + 2.2, -8.8), Color(0.9, 0.85, 0.7), 4.5, 0.6)

func _toilet_e2() -> void:
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet2.fbx", Vector3(14.3, F2, -9.2), -90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Sink.fbx", Vector3(12.3, F2, -9.4), 180, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_ToiletPaper.fbx", Vector3(14.7, F2 + 0.9, -8.4), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Trashcan_Small2.fbx", Vector3(11.9, F2, -7.8), 0, HS)
	_lamp(Vector3(13.2, F2 + 2.3, -8.4), Color(0.85, 0.9, 0.95), 5.0, 0.7)

# ================================================================ спуски в подвал

func _shafts() -> void:
	_shaft(SHAFT_W, "Спуститься в винный погреб", "from_kitchen")
	_shaft(SHAFT_E, "Спуститься в подземелье", "from_sabbath")

func _shaft(r: Rect2, prompt: String, spawn_id: String) -> void:
	var x0 := r.position.x
	var x1 := r.position.x + r.size.x
	var z0 := r.position.y
	var z1 := r.position.y + r.size.y
	var cx := (x0 + x1) / 2.0
	# стены шахты и площадка внизу
	MeshLib.solid_box(self, Vector3(0.25, 2.4, r.size.y + 0.5), Vector3(x0 - 0.1, SHAFT_BOTTOM + 1.2, (z0 + z1) / 2.0), MeshLib.STONE_DARK)
	MeshLib.solid_box(self, Vector3(0.25, 2.4, r.size.y + 0.5), Vector3(x1 + 0.1, SHAFT_BOTTOM + 1.2, (z0 + z1) / 2.0), MeshLib.STONE_DARK)
	MeshLib.solid_box(self, Vector3(r.size.x + 0.5, 2.4, 0.25), Vector3(cx, SHAFT_BOTTOM + 1.2, z1 + 0.1), MeshLib.STONE_DARK)
	MeshLib.solid_box(self, Vector3(r.size.x + 0.5, 0.3, 2.0), Vector3(cx, SHAFT_BOTTOM - 0.15, z1 + 1.0), MeshLib.STONE)
	# наклонная коллизия лестницы: толстая и утопленная, чтобы на входе не было
	# порога-торца, об который спуск застревает
	var run := r.size.y
	var rise := FLOOR_Y - SHAFT_BOTTOM
	var angle := rad_to_deg(atan2(rise, run))
	var thick := 0.8
	MeshLib.solid_invisible(self, Vector3(r.size.x, thick, sqrt(run * run + rise * rise) + 1.6),
		Vector3(cx, (FLOOR_Y + SHAFT_BOTTOM) / 2.0 - (thick / 2.0) / cos(deg_to_rad(angle)), (z0 + z1) / 2.0),
		Vector3(angle, 0, 0))
	# ступени (вниз по +z)
	for i in 10:
		var frac := i / 9.0
		ModelLib.tex_box(self, Vector3(r.size.x, 0.12, run / 10.0 + 0.04),
			Vector3(cx, FLOOR_Y - frac * rise, z0 + frac * run + run / 20.0),
			"stone_light.png", Color(0.62, 0.62, 0.68), 0.5)
	# перила по краю дыры сверху
	for rx in [x0 - 0.12, x1 + 0.12]:
		MeshLib.solid_box(self, Vector3(0.1, 0.95, r.size.y), Vector3(rx, FLOOR_Y + 0.48, (z0 + z1) / 2.0), MeshLib.WOOD_DARK)
	MeshLib.solid_box(self, Vector3(r.size.x + 0.5, 0.95, 0.1), Vector3(cx, FLOOR_Y + 0.48, z1 + 0.2), MeshLib.WOOD_DARK)
	# табличка и портал внизу
	MeshLib.label(self, "▼", Vector3(cx, FLOOR_Y + 1.3, z0 - 0.3), 64, MeshLib.ACCENT)
	var p := Portal.make(self, Vector3(cx, SHAFT_BOTTOM + 0.2, z1 - 0.5), prompt, "cellar", spawn_id)
	portals.append(p)
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx, SHAFT_BOTTOM + 1.0, z1 - 0.4)
	glow.light_color = Color(1.0, 0.62, 0.3)   # факельный отсвет снизу, не радуга на ступенях
	glow.omni_range = 3.5
	glow.light_energy = 1.0
	add_child(glow)

# ================================================================ окна и наружка

func _windows_inside() -> void:
	# витражи изнутри: задний и передний фасады + торцы, оба этажа
	for wx: float in [-18.5, -4.0, 4.0, 18.5]:
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, FLOOR_Y + 1.5, HZ - 0.22), 180)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, F2 + 1.5, HZ - 0.22), 180)
	for wx: float in [-18.5, -9.5, 9.5, 18.5]:
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, FLOOR_Y + 1.5, -HZ + 0.22), 0)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, F2 + 1.5, -HZ + 0.22), 0)
	for wz: float in [-6.0, 0.0, 6.0]:
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(-HX + 0.22, FLOOR_Y + 1.5, wz), 90)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(-HX + 0.22, F2 + 1.5, wz), 90)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(HX - 0.22, FLOOR_Y + 1.5, wz), -90)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(HX - 0.22, F2 + 1.5, wz), -90)
	# витраж-роза над парадным входом в атриуме
	ModelLib.gothic_window(self, 3.2, 4.2, Vector3(0, 4.6, -HZ + 0.24), 0, Color(1.0, 0.85, 0.85))

func _exterior() -> void:
	# крыша
	MeshLib.solid_box(self, Vector3(W + 2.0, 0.2, 12.6), Vector3(0, 9.0, 5.1), MeshLib.ROOF, Vector3(28, 0, 0))
	MeshLib.solid_box(self, Vector3(W + 2.0, 0.2, 12.6), Vector3(0, 9.0, -5.1), MeshLib.ROOF, Vector3(-28, 0, 0))
	MeshLib.box(self, Vector3(W + 2.1, 0.3, 0.6), Vector3(0, 11.8, 0), MeshLib.ROOF.darkened(0.2))
	for sx: float in [-HX - 0.05, HX + 0.05]:
		MeshLib.box(self, Vector3(0.3, 1.3, 18.0), Vector3(sx, 7.8, 0), MeshLib.HOUSE_WALL)
		MeshLib.box(self, Vector3(0.3, 1.3, 12.0), Vector3(sx, 9.1, 0), MeshLib.HOUSE_WALL)
		MeshLib.box(self, Vector3(0.3, 1.3, 6.0), Vector3(sx, 10.4, 0), MeshLib.HOUSE_WALL)
	# башни на задних углах
	for tx: float in [-HX - 0.7, HX + 0.7]:
		var tower := Node3D.new()
		tower.position = Vector3(tx, 0, HZ - 1.2)
		add_child(tower)
		ModelLib.tex_solid_box(tower, Vector3(2.4, 9.0, 2.4), Vector3(0, 4.5, 0), "wood_panel.png", Color(0.45, 0.38, 0.58), 0.45)
		MeshLib.cone(tower, 2.0, 3.4, Vector3(0, 10.7, 0), MeshLib.ROOF)
		ModelLib.gothic_window(tower, 1.1, 1.7, Vector3(0, 6.2, 1.25), 180)
		MeshLib.cylinder(tower, 0.05, 1.6, Vector3(0, 13.0, 0), MeshLib.METAL)
		MeshLib.box(tower, Vector3(0.5, 0.28, 0.04), Vector3(0.3, 13.4, 0), MeshLib.WINE)
	# трубы и дым
	for cx: float in [-12.6, 12.4]:
		MeshLib.box(self, Vector3(0.7, 3.6, 0.7), Vector3(cx, 9.4, 4.6), MeshLib.STONE_DARK)
		for p in [[Vector3(cx + 0.1, 11.6, 4.6), 0.22], [Vector3(cx + 0.3, 12.2, 4.65), 0.3], [Vector3(cx + 0.6, 12.9, 4.7), 0.4]]:
			MeshLib.sphere(self, p[1], p[0], MeshLib.STONE.lightened(0.3), 0.9)
	# витражи снаружи
	for wx: float in [-18.5, -4.0, 4.0, 18.5]:
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, FLOOR_Y + 1.5, HZ + 0.22), 0)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, F2 + 1.5, HZ + 0.22), 0)
	for wx: float in [-18.5, -9.5, 9.5, 18.5]:
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, FLOOR_Y + 1.5, -HZ - 0.22), 180)
		ModelLib.gothic_window(self, 1.6, 2.4, Vector3(wx, F2 + 1.5, -HZ - 0.22), 180)
	ModelLib.gothic_window(self, 3.2, 4.2, Vector3(0, 4.6, -HZ - 0.24), 180, Color(1.0, 0.85, 0.85))
	# заднее крыльцо у кухни (место встречи)
	MeshLib.solid_box(self, Vector3(4.4, 0.2, 2.6), Vector3(BACK_DOOR_X, 0.1, HZ + 1.3), MeshLib.STONE_DARK)
	MeshLib.box(self, Vector3(3.2, 0.12, 1.8), Vector3(BACK_DOOR_X, 3.1, HZ + 0.9), MeshLib.ROOF, Vector3(12, 0, 0))
	for px: float in [BACK_DOOR_X - 1.5, BACK_DOOR_X + 1.5]:
		MeshLib.box(self, Vector3(0.12, 2.9, 0.12), Vector3(px, 1.55, HZ + 1.6), MeshLib.WOOD_DARK)
		var lamp := MeshLib.box(self, Vector3(0.18, 0.24, 0.18), Vector3(px, 2.6, HZ + 0.4), MeshLib.HOUSE_TRIM)
		lamp.material_override = MeshLib.mat(MeshLib.HOUSE_TRIM, 0.6, 0.3, MeshLib.ACCENT)
	# парадное крыльцо
	MeshLib.solid_box(self, Vector3(6.4, 0.2, 3.0), Vector3(0, 0.1, -HZ - 1.5), MeshLib.STONE_DARK)
	for gx: float in [-2.6, 2.6]:
		ModelLib.tex_solid_box(self, Vector3(0.7, 3.6, 0.7), Vector3(gx, 1.8, -HZ - 0.6), "stone_light.png", Color(0.7, 0.72, 0.8), 0.4)
	MeshLib.box(self, Vector3(7.0, 0.4, 3.4), Vector3(0, 3.8, -HZ - 1.4), MeshLib.HOUSE_TRIM)
	front_door = DoorGate.make_model(self, Vector3(-1.8, FLOOR_Y, -HZ), 180.0, 3.6, 2.8,
		ModelLib.HOUSE + "Door_Double.fbx")
	front_door.locked = true
	front_door.locked_hint = "Парадные двери заколочены. Тебе — через чёрный ход, как и положено прислуге."
	_lamp(Vector3(BACK_DOOR_X, 2.8, HZ + 1.2), MeshLib.ACCENT, 7.0, 1.3)
	_lamp(Vector3(0, 3.4, -HZ - 1.6), MeshLib.ACCENT, 7.0, 1.1)

# ================================================================ ведьма и свет

func _witch_meet() -> void:
	meet_marker = Node3D.new()
	meet_marker.position = Vector3(BACK_DOOR_X + 1.0, FLOOR_Y + 0.02, HZ + 1.6)
	meet_marker.rotation_degrees = Vector3(0, 180, 0)   # лицом к кладбищу (+z)
	add_child(meet_marker)
	witch = WitchNPC.new()
	witch.position = meet_marker.position
	witch.rotation_degrees = meet_marker.rotation_degrees
	add_child(witch)

func _witch_on_couch() -> void:
	witch = WitchNPC.new()
	witch.position = couch_marker.position
	witch.rotation_degrees = couch_marker.rotation_degrees
	add_child(witch)
	witch.sit_now()

func _lights() -> void:
	# атриум и балкон
	_lamp(Vector3(0, 5.4, -2.0), Color(1.0, 0.78, 0.5), 16.0, 1.4)
	_lamp(Vector3(0, 2.6, -7.0), Color(1.0, 0.75, 0.5), 9.0, 0.8)
	_lamp(Vector3(0, F2 + 2.2, 7.0), Color(1.0, 0.8, 0.55), 10.0, 0.9)
