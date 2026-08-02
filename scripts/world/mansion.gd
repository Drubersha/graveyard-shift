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
# Спуски в подвал — вертикальные колодцы: просто дырка в полу со стремянкой
# на стенке (пандусы убраны по просьбе игрока). Падение с 2 м даёт ~6.3 м/с —
# ниже порога отрыва деталей 8.0, скелет спрыгивает целым.
const SHAFT_W := Rect2(-10.2, 2.2, 1.8, 1.8)   # дыра в полу кухни
const SHAFT_E := Rect2(8.4, 2.2, 1.8, 1.8)     # дыра в полу зала шабаша
const SHAFT_BOTTOM := -1.8

const HS := ModelLib.HOUSE_SCALE
const FS := ModelLib.FURN_SCALE

# Каталог и фабрика некро-мебели живут в NecroLib (SRP: особняк — планировка,
# каталог — отдельно). Здесь только тонкие обёртки под локальные FLOOR_Y/DOOR_H.

func necro_path(key: String) -> String:
	return NecroLib.path(key)

func necro_scale(key: String, target_h: float) -> float:
	return NecroLib.scale_for(key, target_h)

func _necro_solid(key: String, x: float, z: float, rot_y: float, target_h: float) -> StaticBody3D:
	return NecroLib.solid(self, FLOOR_Y, key, x, z, rot_y, target_h)

func _necro_at(key: String, pos: Vector3, rot_y: float, target_h: float, solid := true) -> Node3D:
	return NecroLib.at(self, key, pos, rot_y, target_h, solid)

func _necro_wall_cab(pos: Vector3, rot_y: float) -> void:
	NecroLib.wall_cab(self, pos, rot_y)

func _necro_sconce(pos: Vector3, rot_y: float) -> void:
	NecroLib.sconce(self, pos, rot_y)

## Межкомнатная дверь в проём 1.8 x DOOR_H; swing со знаком — куда распахивать.
func _inner_door(pos: Vector3, rot_y: float, swing_deg: float) -> DoorGate:
	return NecroLib.door(self, "door_in", pos, rot_y, 1.8, DOOR_H, swing_deg)

var mode := "interior"   # "exterior" — оболочка для улицы, "interior" — комнаты
var portals: Array[Portal] = []
var spawns := {}

var front_door: DoorGate
var pantry_door: DoorGate      # зельеварочная (миссия «мука»)
var pantry_lever: Lever
var vent_marker: Node3D
var witch: WitchNPC
var couch_marker: Node3D
var couch_body: StaticBody3D   # сам диван: по его геометрии считается посадка
var couch_seat: Dictionary     # ModelLib.seat_spot — точка подушки, поворот, зазор
var meet_marker: Node3D
var sink: SinkCounter
var stove: Stove
var fridge: Fridge
var kitchen_doors: Array[DoorGate] = []
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
		var enter := Portal.make(self, Vector3(BACK_DOOR_X, FLOOR_Y, HZ + 0.7),
			"Войти в особняк", "indoor", "kitchen_door")
		portals.append(enter)
		# створка в проёме: E по ней грузит интерьер, дырка не сквозит небом
		var leaf_out := NecroLib.door(self, "door_in", Vector3(BACK_DOOR_X - 0.9, FLOOR_Y, HZ), 0.0, 1.8, DOOR_H, 105.0, 1.12)
		leaf_out.portal_link = enter
		_witch_meet()
		return
	_floors()
	_stairs_main()
	_walls_f1()
	_walls_f2()
	_room_skins()
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
	var exit_p := Portal.make(self, Vector3(BACK_DOOR_X, FLOOR_Y, HZ - 0.55),
		"Выйти во двор", "outdoor", "back_porch")
	portals.append(exit_p)
	# чёрный ход закрыт дверью-порталом: E по створке сразу грузит двор
	var leaf_in := NecroLib.door(self, "door_in", Vector3(BACK_DOOR_X - 0.9, FLOOR_Y, HZ), 0.0, 1.8, DOOR_H, 105.0, 1.12)
	leaf_in.portal_link = exit_p

func _materials() -> void:
	_mat_floor1 = ModelLib.pbr_mat("Mahogany_Planks", Color(0.85, 0.8, 0.78), 0.35)
	_mat_floor2 = ModelLib.pbr_mat("Oak_Parquet_01", Color(0.82, 0.78, 0.72), 0.4)
	_mat_wall_out = ModelLib.tex_mat("wood_panel.png", Color(0.5, 0.42, 0.62), 0.4)
	_mat_wall_in = ModelLib.tex_mat("wood_panel.png", Color(0.78, 0.7, 0.78), 0.45)
	_mat_stone = ModelLib.tex_mat("stone_light.png", Color(0.75, 0.78, 0.85), 0.4)

# ================================================================ хелперы

# Пер-комнатные наборы Meshy «текстуры дома» (assets/textures/house/<room>_<part>.png).
# Материалы трипланарные, поэтому сегментные стены и накладки тайлятся без швов.
var _skins := {}

func _skin(room: String, part: String) -> StandardMaterial3D:
	var key := room + "/" + part
	if not _skins.has(key):
		var uv := 0.35 if part == "wall" else (0.4 if part == "floor" else 0.3)
		_skins[key] = ModelLib.tex_mat("house/%s_%s.png" % [room, part], Color.WHITE, uv)
	return _skins[key]

## Стена. Если заданы материалы сторон — строится ДВУМЯ половинками по толщине,
## чтобы каждая комната получила свои обои (axis: ось толщины, "z" у рядов вдоль X).
## mat_neg — сторона с меньшей координатой по оси, mat_pos — с большей.
func _wall(size: Vector3, pos: Vector3, outer := false, axis := "z",
		mat_neg: Material = null, mat_pos: Material = null) -> StaticBody3D:
	var fallback := _mat_wall_out if outer else _mat_wall_in
	if mat_neg == null and mat_pos == null:
		return _wall_box(size, pos, fallback)
	if mat_neg == mat_pos:
		return _wall_box(size, pos, mat_neg)
	var half := size
	var off := Vector3.ZERO
	if axis == "x":
		half = Vector3(size.x / 2.0, size.y, size.z)
		off = Vector3(size.x / 4.0, 0, 0)
	else:
		half = Vector3(size.x, size.y, size.z / 2.0)
		off = Vector3(0, 0, size.z / 4.0)
	_wall_box(half, pos - off, mat_neg if mat_neg else fallback)
	return _wall_box(half, pos + off, mat_pos if mat_pos else fallback)

func _wall_box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := MeshLib.solid_box(self, size, pos, Color.WHITE)
	ModelLib.override_all(body, mat)
	return body

## Стена вдоль X с проёмами. openings: [[x_from, x_to], ...] или [[x0, x1, высота]].
## Проёмы обязаны идти по возрастанию. mat_neg/mat_pos — комнаты со стороны z-/z+.
func _wall_row_x(z: float, x0: float, x1: float, y0: float, h: float, openings := [],
		outer := false, mat_neg: Material = null, mat_pos: Material = null, thick_override := 0.0) -> void:
	var thick := thick_override if thick_override > 0.0 else (T if outer else WT)
	var cursor := x0
	for op: Array in openings:
		if op[0] > cursor:
			_wall(Vector3(op[0] - cursor, h, thick), Vector3((cursor + op[0]) / 2.0, y0 + h / 2.0, z), outer, "z", mat_neg, mat_pos)
		var top: float = op[2] if op.size() > 2 else DOOR_H
		if h > top:
			_wall(Vector3(op[1] - op[0], h - top, thick), Vector3((op[0] + op[1]) / 2.0, y0 + top + (h - top) / 2.0, z), outer, "z", mat_neg, mat_pos)
		cursor = op[1]
	if cursor < x1:
		_wall(Vector3(x1 - cursor, h, thick), Vector3((cursor + x1) / 2.0, y0 + h / 2.0, z), outer, "z", mat_neg, mat_pos)

## Стена вдоль Z с проёмами. mat_neg/mat_pos — комнаты со стороны x-/x+.
func _wall_row_z(x: float, z0: float, z1: float, y0: float, h: float, openings := [],
		outer := false, mat_neg: Material = null, mat_pos: Material = null, thick_override := 0.0) -> void:
	var thick := thick_override if thick_override > 0.0 else (T if outer else WT)
	var cursor := z0
	for op: Array in openings:
		if op[0] > cursor:
			_wall(Vector3(thick, h, op[0] - cursor), Vector3(x, y0 + h / 2.0, (cursor + op[0]) / 2.0), outer, "x", mat_neg, mat_pos)
		var top: float = op[2] if op.size() > 2 else DOOR_H
		if h > top:
			_wall(Vector3(thick, h - top, op[1] - op[0]), Vector3(x, y0 + top + (h - top) / 2.0, (op[0] + op[1]) / 2.0), outer, "x", mat_neg, mat_pos)
		cursor = op[1]
	if cursor < z1:
		_wall(Vector3(thick, h, z1 - cursor), Vector3(x, y0 + h / 2.0, (cursor + z1) / 2.0), outer, "x", mat_neg, mat_pos)

## Полы и потолки комнат — тонкие накладки поверх общих плит. Границы — грани
## стен (внутренние ±0.15, внешние ±0.2 от осей). У кухни пол объезжает шахту
## SHAFT_W; шабаш пола в паке не имеет и остаётся на общем; гостиная и кладовка
## мётел без наборов. Полоса старого пола в дверных проёмах читается как порожек.
func _room_skins() -> void:
	# --- этаж 1: полы
	_skin_floor("kitchen", -14.85, 0.15, -7.15, 2.2, FLOOR_Y)
	_skin_floor("kitchen", -14.85, 2.2, -10.2, 4.0, FLOOR_Y)
	_skin_floor("kitchen", -8.4, 2.2, -7.15, 4.0, FLOOR_Y)
	_skin_floor("kitchen", -14.85, 4.0, -7.15, 9.8, FLOOR_Y)
	_skin_floor("dining", -21.8, 0.15, -15.15, 9.8, FLOOR_Y)
	_skin_floor("sewing", -21.8, -9.8, -15.15, -0.15, FLOOR_Y)
	_skin_floor("bathroom", -14.85, -9.8, -11.65, -7.15, FLOOR_Y)
	_skin_floor("occult", -14.85, -7.15, -7.15, -0.15, FLOOR_Y)
	_skin_floor("occult", -11.35, -9.8, -7.15, -7.15, FLOOR_Y)
	_skin_floor("entrance", -6.85, -9.8, 6.85, 9.8, FLOOR_Y)
	_skin_floor("workshop", 15.15, 0.15, 21.8, 9.8, FLOOR_Y)
	_skin_floor("potion", 15.15, -9.8, 21.8, -0.15, FLOOR_Y)
	_skin_floor("occult", 7.15, -7.15, 14.85, -0.15, FLOOR_Y)
	_skin_floor("occult", 7.15, -9.8, 11.35, -7.15, FLOOR_Y)
	_skin_floor("bathroom", 11.65, -9.8, 14.85, -7.15, FLOOR_Y)
	# --- этаж 1: потолки (низ плиты второго этажа)
	_skin_ceil("kitchen", -14.85, 0.15, -7.15, 9.8, SLAB_BOT)
	_skin_ceil("dining", -21.8, 0.15, -15.15, 9.8, SLAB_BOT)
	_skin_ceil("sewing", -21.8, -9.8, -15.15, -0.15, SLAB_BOT)
	_skin_ceil("bathroom", -14.85, -9.8, -11.65, -7.15, SLAB_BOT)
	_skin_ceil("occult", -14.85, -7.15, -7.15, -0.15, SLAB_BOT)
	_skin_ceil("occult", -11.35, -9.8, -7.15, -7.15, SLAB_BOT)
	_skin_ceil("coven", 7.15, 0.15, 14.85, 9.8, SLAB_BOT)
	_skin_ceil("workshop", 15.15, 0.15, 21.8, 9.8, SLAB_BOT)
	_skin_ceil("potion", 15.15, -9.8, 21.8, -0.15, SLAB_BOT)
	_skin_ceil("occult", 7.15, -7.15, 14.85, -0.15, SLAB_BOT)
	_skin_ceil("occult", 7.15, -9.8, 11.35, -7.15, SLAB_BOT)
	_skin_ceil("bathroom", 11.65, -9.8, 14.85, -7.15, SLAB_BOT)
	# зал: потолок — крыша атриума целиком + низ балконной плиты
	_skin_ceil("entrance", -6.85, -9.8, 6.85, 9.8, CEIL)
	_skin_ceil("entrance", -6.85, 4.15, 6.85, 9.8, SLAB_BOT)
	# --- этаж 2: полы
	_skin_floor("entrance", -6.85, 4.15, 6.85, 9.8, F2)
	_skin_floor("master_bedroom", -21.8, -9.8, -15.15, 9.8, F2)
	_skin_floor("bathroom", -14.85, -9.8, -11.65, -6.65, F2)
	_skin_floor("occult", -14.85, -6.35, -7.15, 3.85, F2)
	_skin_floor("occult", -11.35, -9.8, -7.15, -6.35, F2)
	_skin_floor("library", 7.15, 3.15, 21.8, 9.8, F2)
	_skin_floor("guest_bedroom", 15.15, -9.8, 21.8, 2.85, F2)
	_skin_floor("occult", 7.15, -6.35, 14.85, 2.85, F2)
	_skin_floor("occult", 7.15, -7.35, 11.35, -6.35, F2)
	_skin_floor("bathroom", 11.65, -9.8, 14.85, -6.65, F2)
	# --- этаж 2: потолки
	_skin_ceil("master_bedroom", -21.8, -9.8, -15.15, 9.8, CEIL)
	_skin_ceil("bathroom", -14.85, -9.8, -11.65, -6.65, CEIL)
	_skin_ceil("occult", -14.85, -6.35, -7.15, 3.85, CEIL)
	_skin_ceil("occult", -11.35, -9.8, -7.15, -6.35, CEIL)
	_skin_ceil("library", 7.15, 3.15, 21.8, 9.8, CEIL)
	_skin_ceil("guest_bedroom", 15.15, -9.8, 21.8, 2.85, CEIL)
	_skin_ceil("occult", 7.15, -6.35, 14.85, 2.85, CEIL)
	_skin_ceil("occult", 7.15, -7.35, 11.35, -6.35, CEIL)
	_skin_ceil("bathroom", 11.65, -9.8, 14.85, -6.65, CEIL)

## Тонкая накладка пола комнаты поверх общего пола (лёгкий подъём против z-fight).
func _skin_floor(room: String, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	ModelLib.tex_box(self, Vector3(x1 - x0, 0.012, z1 - z0),
		Vector3((x0 + x1) / 2.0, y + 0.006, (z0 + z1) / 2.0), "house/%s_floor.png" % room, Color.WHITE, 0.4)

## Накладка потолка комнаты: под низом плиты, смотрит вниз.
func _skin_ceil(room: String, x0: float, z0: float, x1: float, z1: float, y_bottom: float) -> void:
	ModelLib.tex_box(self, Vector3(x1 - x0, 0.012, z1 - z0),
		Vector3((x0 + x1) / 2.0, y_bottom - 0.006, (z0 + z1) / 2.0), "house/%s_ceil.png" % room, Color.WHITE, 0.3)

func _floor_rect(x0: float, z0: float, x1: float, z1: float, y_top: float, mat: Material) -> void:
	var s := MeshLib.solid_box(self, Vector3(x1 - x0, 0.2, z1 - z0),
		Vector3((x0 + x1) / 2.0, y_top - 0.1, (z0 + z1) / 2.0), Color.WHITE)
	ModelLib.override_all(s, mat)

func _tile(x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var mi := MeshLib.box(self, Vector3(x1 - x0, 0.03, z1 - z0),
		Vector3((x0 + x1) / 2.0, y + 0.015, (z0 + z1) / 2.0), Color.WHITE)
	mi.material_override = _mat_stone

func _candle(parent: Node, pos: Vector3, size := 0.16) -> void:
	MeshLib.cylinder(parent, 0.035, size, pos + Vector3(0, size / 2.0, 0), MeshLib.BONE)
	var flame := MeshLib.sphere(parent, 0.028, pos + Vector3(0, size + 0.04, 0), Color(1.0, 0.8, 0.4), 1.4)
	flame.material_override = MeshLib.mat(Color(1.0, 0.8, 0.4), 1.0, 0.0, Color(1.0, 0.7, 0.3))

## Настенные часы: тёмный круглый корпус, светлый циферблат, часовая и минутная
## стрелки. Собираются лицом в +Z и разворачиваются rot_y; pos — точка на стене,
## корпус растёт от неё наружу. Чистый визуал без коллизии: болванка на высоте
## двух метров ничего не должна ловить (веник, брошенный череп, летящую тарелку).
func _wall_clock(pos: Vector3, rot_y := 0.0, radius := 0.26) -> Node3D:
	var clock := Node3D.new()
	clock.name = "WallClock"
	clock.position = pos
	clock.rotation_degrees = Vector3(0, rot_y, 0)
	add_child(clock)
	var dark := MeshLib.HOUSE_TRIM
	var gold := Color(0.82, 0.68, 0.34)
	# корпус-обод: задняя грань в точке pos, вперёд на 0.09
	MeshLib.cylinder(clock, radius, 0.09, Vector3(0, 0, 0.045), MeshLib.WOOD_DARK, Vector3(90, 0, 0))
	# циферблат — чуть выступает из обода, со слабым свечением: кухня ночная,
	# без него с восьми метров это серое пятно
	var face := MeshLib.cylinder(clock, radius - 0.035, 0.02, Vector3(0, 0, 0.085),
		MeshLib.BONE, Vector3(90, 0, 0))
	face.material_override = MeshLib.mat(MeshLib.BONE, 0.75, 0.0, Color(0.30, 0.28, 0.22))
	# часовые деления: 12, 3, 6, 9 — крупные золотые, остальные мелкие тёмные
	var tick_r := radius - 0.06
	for i in 12:
		var ang := i * TAU / 12.0
		var big: bool = i % 3 == 0
		var tw: float = 0.022 if big else 0.014
		var th: float = 0.05 if big else 0.028
		var tick := MeshLib.box(clock, Vector3(tw, th, 0.012),
			Vector3(sin(ang) * tick_r, cos(ang) * tick_r, 0.098),
			dark, Vector3(0, 0, -rad_to_deg(ang)))
		if big:
			tick.material_override = MeshLib.mat(gold, 0.4, 0.6)
	# стрелки на 10:10 — разведены в стороны, читаются с одного взгляда.
	# Минутная не достаёт до делений (0.17 < 0.175), чтобы не втыкаться в них.
	_clock_hand(clock, 305.0, 0.115, 0.030, 0.100, dark)   # часовая
	_clock_hand(clock, 60.0, 0.170, 0.020, 0.108, dark)    # минутная
	MeshLib.sphere(clock, 0.024, Vector3(0, 0, 0.118), gold)
	return clock

## Одна стрелка: пивот в центре циферблата, брусок растёт от него «вверх» на 12 часов.
func _clock_hand(clock: Node3D, deg_from_12: float, length: float, width: float,
		z: float, c: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, z)
	pivot.rotation_degrees = Vector3(0, 0, -deg_from_12)
	clock.add_child(pivot)
	MeshLib.box(pivot, Vector3(width, length, 0.014), Vector3(0, length / 2.0, 0), c)

func _lamp(pos: Vector3, color: Color, range_: float, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_
	l.light_energy = energy
	add_child(l)

# ================================================================ каркас

func _ext_walls() -> void:
	# Внешние стены двухслойные: наружная половина (T/2) — единый фасад на всю
	# высоту, внутренняя — по этажам и комнатам со своими обоями. Стык этажей
	# закрыт торцом плиты 2-го этажа. Зал двухсветный — его кусок кладётся
	# одной панелью на всю высоту.
	var q := T / 4.0
	var ht := T / 2.0
	var full := CEIL - FLOOR_Y
	var out := _mat_wall_out
	var kw := _skin("kitchen", "wall")
	var dw := _skin("dining", "wall")
	var sw := _skin("sewing", "wall")
	var ew := _skin("entrance", "wall")
	var cw := _skin("occult", "wall")
	var vw := _skin("coven", "wall")
	var aw := _skin("workshop", "wall")
	var pw := _skin("potion", "wall")
	var bw := _skin("bathroom", "wall")
	var mw := _skin("master_bedroom", "wall")
	var gw := _skin("guest_bedroom", "wall")
	var lw := _skin("library", "wall")
	# --- запад x=-22: наружный слой + столовая/швейная (1 эт), спальное крыло (2 эт)
	_wall_row_z(-HX - q, -HZ, HZ, FLOOR_Y, full, [], true, out, out, ht)
	_wall_row_z(-HX + q, -HZ, 0.0, FLOOR_Y, H1, [], true, sw, sw, ht)
	_wall_row_z(-HX + q, 0.0, HZ, FLOOR_Y, H1, [], true, dw, dw, ht)
	_wall_row_z(-HX + q, -HZ, HZ, F2, H2, [], true, mw, mw, ht)
	# --- восток x=22: зельеварочная/амулетная (1 эт), спальни/библиотека (2 эт)
	_wall_row_z(HX + q, -HZ, HZ, FLOOR_Y, full, [], true, out, out, ht)
	_wall_row_z(HX - q, -HZ, 0.0, FLOOR_Y, H1, [], true, pw, pw, ht)
	_wall_row_z(HX - q, 0.0, HZ, FLOOR_Y, H1, [], true, aw, aw, ht)
	_wall_row_z(HX - q, -HZ, 3.0, F2, H2, [], true, gw, gw, ht)
	_wall_row_z(HX - q, 3.0, HZ, F2, H2, [], true, lw, lw, ht)
	# --- задний фасад z=10: чёрный вход в кухню (проём сквозь оба слоя)
	var back_op := [[BACK_DOOR_X - 0.9, BACK_DOOR_X + 0.9]]
	_wall_row_x(HZ + q, -HX, HX, FLOOR_Y, full, back_op, true, out, out, ht)
	_wall_row_x(HZ - q, -HX, -WING_X, FLOOR_Y, H1, [], true, dw, dw, ht)
	_wall_row_x(HZ - q, -WING_X, -HALL_HX, FLOOR_Y, H1, back_op, true, kw, kw, ht)
	_wall_row_x(HZ - q, -HALL_HX, HALL_HX, FLOOR_Y, full, [], true, ew, ew, ht)
	_wall_row_x(HZ - q, HALL_HX, WING_X, FLOOR_Y, H1, [], true, vw, vw, ht)
	_wall_row_x(HZ - q, WING_X, HX, FLOOR_Y, H1, [], true, aw, aw, ht)
	_wall_row_x(HZ - q, -HX, -WING_X, F2, H2, [], true, mw, mw, ht)
	_wall_row_x(HZ - q, -WING_X, -HALL_HX, F2, H2, [], true, null, null, ht)
	_wall_row_x(HZ - q, HALL_HX, HX, F2, H2, [], true, lw, lw, ht)
	# --- передний фасад z=-10: парадные двери (перекрыты невидимой стеной — город в M2)
	var front_op := [[-1.8, 1.8, 2.8]]
	_wall_row_x(-HZ - q, -HX, HX, FLOOR_Y, full, front_op, true, out, out, ht)
	_wall_row_x(-HZ + q, -HX, -WING_X, FLOOR_Y, H1, [], true, sw, sw, ht)
	_wall_row_x(-HZ + q, -WING_X, -HALL_HX, FLOOR_Y, H1, [], true, cw, cw, ht)
	_wall_row_x(-HZ + q, -HALL_HX, HALL_HX, FLOOR_Y, full, front_op, true, ew, ew, ht)
	_wall_row_x(-HZ + q, HALL_HX, WING_X, FLOOR_Y, H1, [], true, cw, cw, ht)
	_wall_row_x(-HZ + q, WING_X, HX, FLOOR_Y, H1, [], true, pw, pw, ht)
	_wall_row_x(-HZ + q, -HX, -WING_X, F2, H2, [], true, mw, mw, ht)
	_wall_row_x(-HZ + q, -WING_X, -11.5, F2, H2, [], true, bw, bw, ht)
	_wall_row_x(-HZ + q, -11.5, -HALL_HX, F2, H2, [], true, cw, cw, ht)
	_wall_row_x(-HZ + q, HALL_HX, 11.5, F2, H2, [], true, null, null, ht)
	_wall_row_x(-HZ + q, 11.5, WING_X, F2, H2, [], true, bw, bw, ht)
	_wall_row_x(-HZ + q, WING_X, HX, F2, H2, [], true, gw, gw, ht)
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
	var kw := _skin("kitchen", "wall")
	var dw := _skin("dining", "wall")
	var sw := _skin("sewing", "wall")
	var ew := _skin("entrance", "wall")
	var cw := _skin("occult", "wall")
	var vw := _skin("coven", "wall")
	var aw := _skin("workshop", "wall")
	var pw := _skin("potion", "wall")
	var bw := _skin("bathroom", "wall")
	# зал ↔ крылья; ряды разрезаны на z=0 — по сторонам разные комнаты
	_wall_row_z(-HALL_HX, -HZ, 0.0, FLOOR_Y, H1, [[-6.8, -5.0]], false, cw, ew)
	_wall_row_z(-HALL_HX, 0.0, HZ, FLOOR_Y, H1, [[5.0, 6.8]], false, kw, ew)
	_wall_row_z(HALL_HX, -HZ, 0.0, FLOOR_Y, H1, [[-6.8, -5.0]], false, ew, cw)
	_wall_row_z(HALL_HX, 0.0, HZ, FLOOR_Y, H1, [[5.0, 6.8]], false, ew, vw)
	# запад: север/юг (кухня+столовая | коридор+швейная)
	_wall_row_x(0.0, -HX, -WING_X, FLOOR_Y, H1, [], false, sw, dw)
	_wall_row_x(0.0, -WING_X, -HALL_HX, FLOOR_Y, H1, [[-13.0, -11.2]], false, cw, kw)
	_wall_row_z(-WING_X, 0.0, HZ, FLOOR_Y, H1, [[4.0, 5.8]], false, dw, kw)         # кухня ↔ столовая
	_wall_row_z(-WING_X, -HZ, 0.0, FLOOR_Y, H1, [[-5.8, -4.0]], false, sw, cw)      # коридор ↔ швейная
	# туалет W1 (угол коридора)
	_wall_row_z(-11.5, -HZ, -7.0, FLOOR_Y, H1, [], false, bw, cw)
	_wall_row_x(-7.0, -WING_X, -11.5, FLOOR_Y, H1, [[-13.6, -12.4]], false, bw, cw)
	# восток: север/юг
	_wall_row_x(0.0, HALL_HX, WING_X, FLOOR_Y, H1, [[11.2, 13.0]], false, cw, vw)
	_wall_row_x(0.0, WING_X, HX, FLOOR_Y, H1, [], false, pw, aw)
	_wall_row_z(WING_X, 0.0, HZ, FLOOR_Y, H1, [[4.0, 5.8]], false, vw, aw)          # шабаш ↔ амулетная
	# зельеварочная: дверь + вентиляция у пола (проём высотой 0.55)
	_wall_row_z(WING_X, -HZ, 0.0, FLOOR_Y, H1, [[-5.8, -4.0], [-2.4, -1.6, 0.55]], false, cw, pw)
	# туалет E1
	_wall_row_z(11.5, -HZ, -7.0, FLOOR_Y, H1, [], false, cw, bw)
	_wall_row_x(-7.0, 11.5, WING_X, FLOOR_Y, H1, [[12.4, 13.6]], false, bw, cw)

func _walls_f2() -> void:
	var ew := _skin("entrance", "wall")
	var cw := _skin("occult", "wall")
	var bw := _skin("bathroom", "wall")
	var mw := _skin("master_bedroom", "wall")
	var gw := _skin("guest_bedroom", "wall")
	var lw := _skin("library", "wall")
	# зал ↔ крылья: глухо над пустотой, проёмы с балкона; запад — гостиная без набора
	_wall_row_z(-HALL_HX, -HZ, 4.0, F2, H2, [], false, cw, ew)
	_wall_row_z(-HALL_HX, 4.0, HZ, F2, H2, [[6.0, 7.8]], false, null, ew)
	_wall_row_z(HALL_HX, -HZ, -7.5, F2, H2, [], false, ew, null)
	_wall_row_z(HALL_HX, -7.5, 3.0, F2, H2, [], false, ew, cw)
	_wall_row_z(HALL_HX, 3.0, HZ, F2, H2, [[6.0, 7.8]], false, ew, lw)
	# --- запад: всё спальное крыло x -22..-15 — хозяйская анфилада (master)
	_wall_row_x(4.0, -WING_X, -HALL_HX, F2, H2, [[-11.0, -9.2]], false, cw, null)   # гостиная ↔ коридор
	_wall_row_z(-WING_X, 4.0, HZ, F2, H2, [[5.2, 7.0]], false, mw, null)            # гостиная ↔ спальня 1
	_wall_row_z(-WING_X, -2.0, 4.0, F2, H2, [[0.0, 1.8]], false, mw, cw)            # коридор ↔ спальня 2
	_wall_row_z(-WING_X, -HZ, -2.0, F2, H2, [[-5.0, -3.2]], false, mw, cw)          # коридор ↔ спальня 3
	_wall_row_x(-6.5, -WING_X, -11.5, F2, H2, [[-13.6, -12.4]], false, bw, cw)      # туалет W2
	_wall_row_z(-11.5, -HZ, -6.5, F2, H2, [], false, bw, cw)
	# --- восток: спальни 4-5 — гостевые
	_wall_row_x(3.0, HALL_HX, WING_X, F2, H2, [[8.5, 10.3]], false, cw, lw)         # библиотека ↔ коридор
	_wall_row_x(3.0, WING_X, HX, F2, H2, [], false, gw, lw)
	_wall_row_z(WING_X, -2.0, 3.0, F2, H2, [[0.0, 1.8]], false, cw, gw)             # коридор ↔ спальня 4
	_wall_row_z(WING_X, -HZ, -2.0, F2, H2, [[-5.0, -3.2]], false, cw, gw)           # коридор ↔ спальня 5
	_wall_row_x(-6.5, 11.5, WING_X, F2, H2, [[12.4, 13.6]], false, bw, cw)          # туалет E2
	_wall_row_z(11.5, -HZ, -7.5, F2, H2, [], false, null, bw)
	_wall_row_x(-7.5, HALL_HX, 11.5, F2, H2, [[8.4, 9.6]], false, null, cw)         # кладовка мётел

# ================================================================ парадный зал

func _grand_hall() -> void:
	# парадные ворота — две некро-створки на весь проём 3.6, обе заперты до M2
	front_door = NecroLib.door(self, "front_door", Vector3(-1.8, FLOOR_Y, -HZ), 0.0, 1.8, 2.8, 105.0, 1.1)
	front_door.locked = true
	front_door.locked_hint = "Парадные двери заколочены. За ними город, а город — это уже другая история. (M2)"
	var front_r := NecroLib.door(self, "front_door", Vector3(1.8, FLOOR_Y, -HZ), 180.0, 1.8, 2.8, -105.0, 1.1)
	front_r.locked = true
	front_r.locked_hint = front_door.locked_hint
	# ковровая дорожка от дверей к лестницам
	ModelLib.tex_box(self, Vector3(3.0, 0.03, 11.0), Vector3(0, FLOOR_Y + 0.015, -4.0),
		"wood_panel.png", Color(0.55, 0.13, 0.18), 0.5)
	# ОСНОВНАЯ люстра атриума — grand chandelier из некро-пака на цепи под сводом
	var gc_h := 2.2
	var gc := _necro_at("grand_chand", Vector3(0, CEIL - 0.35 - gc_h * 0.5, -2.0), 0, gc_h, false)
	MeshLib.cylinder(self, 0.03, 0.4, Vector3(0, CEIL - 0.2, -2.0), MeshLib.METAL)
	var gc_light := OmniLight3D.new()
	gc_light.position = gc.position + Vector3(0, -0.3, 0)
	gc_light.light_color = Color(1.0, 0.75, 0.45)
	gc_light.omni_range = 13.0
	gc_light.light_energy = 1.2
	add_child(gc_light)
	# колонны вдоль зала — строго между проёмами крыльев (z 5..6.8 и -6.8..-5)
	for cz: float in [-8.6, -2.0, 2.0, 8.6]:
		for cx: float in [-6.4, 6.4]:
			ModelLib.tex_solid_box(self, Vector3(0.55, H1, 0.55), Vector3(cx, FLOOR_Y + H1 / 2.0, cz),
				"stone_light.png", Color(0.7, 0.72, 0.8), 0.4)
	# баннеры и знамёна на торцевой стене
	ModelLib.visual(self, "Banner_1", Vector3(-3.6, 4.6, -HZ + 0.35))
	ModelLib.visual(self, "Banner_2", Vector3(3.6, 4.6, -HZ + 0.35))
	ModelLib.gothic_ornament(self, 1.6, Vector3(0, 5.2, -HZ + 0.3), 0, 2)
	# мебель — вплотную к задней стене зала, вне створов проёмов и лестниц
	_necro_solid("bench", -4.6, 9.35, 180, 0.85)
	_necro_solid("bench", 4.6, 9.35, 180, 0.85)
	ModelLib.visual(self, "Carpet_Round", Vector3(0, FLOOR_Y + 0.02, 8.0), 0, HS * 1.4)
	_necro_solid("candelabra", -6.4, -0.6, 0, 1.7)
	_necro_solid("candelabra", 6.4, -0.6, 0, 1.7)

func _candle_stand_pair(a: Vector3, b: Vector3) -> void:
	ModelLib.solid(self, "CandleStick_Stand", a)
	ModelLib.solid(self, "CandleStick_Stand", b)

# ================================================================ запад, этаж 1

func _kitchen() -> void:
	# кухня x -15..-7, z 0..10. Проёмы: x=-7 (z 5..6.8), z=0 (x -13..-11.2),
	# x=-15 (z 4..5.8), задняя дверь (x -11.9..-10.1), спуск в подвал x -10.6..-8, z 1.2..5.8.
	# Вся мебель — Meshy «некро-мебель» (NECRO). Рабочая линия стоит у ГЛУХОГО куска
	# западной стены (z 5.8..9.8, грань x=-14.85), фронтом на восток: yaw узла -90,
	# внутри пропса модель повёрнута на 180 (фронт Meshy +Z → фронт узла -Z).
	fridge = Fridge.new()
	fridge.model_path = necro_path("icebox")
	fridge.model_scale = necro_scale("icebox", 2.0)
	fridge.position = Vector3(-14.56, FLOOR_Y + 1.0, 9.4)
	fridge.rotation_degrees = Vector3(0, -90, 0)
	add_child(fridge)
	stove = Stove.new()
	stove.model_path = necro_path("stove")
	stove.model_scale = necro_scale("stove", 1.6)
	stove.position = Vector3(-14.41, FLOOR_Y + 0.8, 8.1)
	stove.rotation_degrees = Vector3(0, -90, 0)
	stove.top_y_override = 0.05   # варочная ~1.05 над полом (центр узла на 1.0); AABB выше — трубы
	add_child(stove)
	sink = SinkCounter.new()
	sink.model_path = necro_path("sink")
	sink.model_scale = necro_scale("sink", 1.25)
	sink.position = Vector3(-14.40, FLOOR_Y + 0.625, 6.6)
	sink.rotation_degrees = Vector3(0, -90, 0)
	sink.zone_y_override = 0.03   # чаша ~0.85 над полом, кран в AABB выше
	add_child(sink)
	# 4 напольных шкафа: два у северной стены восточнее чёрного хода и два на
	# западной стене южнее проёма столовой. Северо-западный угол пуст целиком —
	# подход к дверце ледника ничем не перекрыт (тумба там резала зону дверцы).
	_necro_solid("cabinet", -9.5, 9.573, 180, 1.0)
	_necro_solid("cabinet", -8.35, 9.573, 180, 1.0)
	_necro_solid("cabinet", -14.62, 1.5, 90, 1.0)
	_necro_solid("cabinet", -14.62, 2.7, 90, 1.0)
	# 6 навесных, пропорцией под тумбы: ширина 1.10 (≈ширина тумбы), высота 1.30 —
	# модель вертикальная, поэтому масштаб неравномерный (solid_xyz). Соседние на
	# одной стене висят ВПЛОТНУЮ: пара над северо-восточными тумбами (центр пары
	# -8.925) и пара над западными (центр 2.1). Одиночные — над мойкой (поднят:
	# низ выше крана) и на глухом куске южной стены.
	_necro_wall_cab(Vector3(-9.475, 2.05, 9.62), 180)
	_necro_wall_cab(Vector3(-8.375, 2.05, 9.62), 180)
	_necro_wall_cab(Vector3(-14.67, 2.05, 1.55), 90)
	_necro_wall_cab(Vector3(-14.67, 2.05, 2.65), 90)
	_necro_wall_cab(Vector3(-14.67, 2.2, 6.6), 90)
	_necro_wall_cab(Vector3(-9.0, 2.05, 0.33), 0)
	# межкомнатные двери в трёх проёмах; распахиваются туда, где нет мебели:
	# коридорная — в кухню (свободный угол у часов), столовая — в столовую,
	# зальная — в зал (в кухне рядом ограждение подвальной шахты)
	kitchen_doors.append(_inner_door(Vector3(-13.0, FLOOR_Y, 0.0), 0.0, -105.0))
	kitchen_doors.append(_inner_door(Vector3(-15.0, FLOOR_Y, 5.8), 90.0, 105.0))
	kitchen_doors.append(_inner_door(Vector3(-7.0, FLOOR_Y, 5.0), -90.0, 105.0))
	# пыль по всей кухне, обходя лестничный проём, мебель и створы дверей;
	# уже убранная (Game.world_state) не возвращается после похода в подвал
	var dust_spots := [Vector3(-13.2, FLOOR_Y, 2.2), Vector3(-12.6, FLOOR_Y, 7.9), Vector3(-8.6, FLOOR_Y, 6.6),
		Vector3(-13.0, FLOOR_Y, 0.9), Vector3(-13.5, FLOOR_Y, 5.0), Vector3(-11.6, FLOOR_Y, 8.4)]
	for i in dust_spots.size():
		if Game.has_mark("dust_cleaned", i):
			continue
		var d := DustPatch.make(self, dust_spots[i], 0.55)
		d.id = i
		dust_list.append(d)
	# Настенные часы (некро-модель) на глухом простенке z=0 западнее прохода
	# в коридор: панель сплошная при x -14.85..-13, часы 0.72 шириной по центру.
	# Створ коридорной двери (петля x=-13, свинг -105) до них не достаёт.
	_necro_at("wall_clock", Vector3(-13.9, 2.2, 0.2), 0, 0.85, false)
	# люстра в центре комнаты + два бра на глухих простенках юга и востока
	_necro_at("chandelier", Vector3(-11.0, SLAB_BOT - 0.475, 5.0), 0, 0.85, false)
	_lamp(Vector3(-11.0, 2.65, 5.0), Color(1.0, 0.8, 0.55), 10.0, 1.1)
	_necro_sconce(Vector3(-10.3, 2.1, 0.33), 0)
	_necro_sconce(Vector3(-7.33, 2.1, 8.3), -90)

func _dining() -> void:
	# x -22..-15, z 0..10; проём в стене x=-15 при z 4..5.8. Вся мебель — некро-пак.
	var tbl := _necro_solid("table", -18.5, 7.4, 0, 1.5)
	ModelLib.cap_collision(tbl, 0.07)   # столешница ~0.82 над полом, выше — декор
	for i in 3:
		_necro_solid("chair", -19.7 + i * 1.2, 8.6, 180, 1.35)
		_necro_solid("chair", -19.7 + i * 1.2, 6.2, 0, 1.35)
	# грязная посуда после вчерашнего — ровно две, их и моем: падают на столешницу
	var plate_spots := [Vector3(-19.3, FLOOR_Y + 1.1, 7.8), Vector3(-17.7, FLOOR_Y + 1.1, 7.1)]
	for i in plate_spots.size():
		if Game.has_mark("plates_done", i):
			continue
		var p := BreakableProp.make(self, "plate_dirty", plate_spots[i])
		p.id = i
		dirty_plates.append(p)
	# место, куда чистые тарелки просятся обратно
	ModelLib.visual(self, "Plate_1", Vector3(-20.2, FLOOR_Y + 0.93, 7.2), 0, HS)
	ModelLib.visual(self, "Plate_2", Vector3(-16.9, FLOOR_Y + 0.93, 7.9), 0, HS)
	# напольные часы, винная стойка и буфет — у глухих стен
	_necro_solid("gf_clock", -21.5, 4.6, 90, 2.2)
	_necro_solid("wine_rack", -19.6, 0.5, 0, 1.6)
	_necro_solid("cabinet", -16.8, 0.55, 0, 1.0)
	ModelLib.visual(self, "Curtains_Double", Vector3(-18.5, FLOOR_Y, 9.5), 0, HS)
	ModelLib.visual(self, "Carpet_2", Vector3(-18.5, FLOOR_Y + 0.02, 7.4), 0, HS * 1.3)
	_necro_at("chandelier", Vector3(-18.5, SLAB_BOT - 0.475, 7.4), 0, 0.85, false)
	_lamp(Vector3(-18.5, 2.9, 6.0), Color(1.0, 0.75, 0.5), 9.0, 0.9)

func _sewing() -> void:
	# x -22..-15, z -10..0; проём в стене x=-15 при z -5.8..-4. Мебель — некро-пак.
	_necro_solid("mannequin", -17.4, -2.6, 30, 1.7)
	_necro_solid("workbench", -19.6, -8.75, 0, 0.95)
	_necro_solid("workbench", -16.8, -8.75, 0, 0.95)
	_necro_solid("wardrobe", -21.55, -5.0, 90, 2.1)
	_necro_solid("stool", -19.2, -7.0, 0, 0.55)
	_necro_solid("candelabra", -16.3, -1.2, 0, 1.7)
	for i in 3:
		ModelLib.tex_box(self, Vector3(0.28, 1.5, 0.28), Vector3(-21.0 + i * 0.4, FLOOR_Y + 0.75, -1.4),
			"wood_panel.png", [Color(0.6, 0.2, 0.3), Color(0.3, 0.2, 0.5), Color(0.2, 0.4, 0.3)][i], 0.9,
			Vector3(0, 0, randf_range(-7, 7)))
	_necro_at("tool_rack", Vector3(-18.5, 1.9, -9.68), 0, 1.2)
	ModelLib.grab(self, "Pouch_Large", Vector3(-16.8, FLOOR_Y + 1.0, -8.4), 1.0)
	_lamp(Vector3(-18.5, 2.9, -5.0), Color(0.95, 0.8, 0.6), 9.0, 0.85)

func _toilet_w1() -> void:
	# трон-унитаз у западной стены лицом на восток, умывальник у южной лицом на север
	_necro_solid("toilet", -14.2, -8.4, 90, 1.15)
	_necro_solid("bath_b", -12.4, -9.25, 0, 1.7)
	ModelLib.visual(self, "Bathroom_ToiletPaper", Vector3(-14.5, FLOOR_Y + 0.9, -7.6), 90, HS)
	_lamp(Vector3(-13.2, 2.8, -8.5), Color(0.85, 0.9, 0.95), 5.0, 0.7)

func _corridor_w1() -> void:
	# x -15..-7, z -10..0 (минус туалет). Проёмы: x=-7 (z -6.8..-5), z=0 (x -13..-11.2), x=-15 (z -5.8..-4)
	_necro_solid("chest", -7.75, -2.2, -90, 0.75)
	_necro_solid("candelabra", -7.7, -8.6, 0, 1.7)
	ModelLib.visual(self, "Carpet_1", Vector3(-10.0, FLOOR_Y + 0.02, -3.0), 90, HS)
	# бра вместо фонаря хауспака (тот прошивал стену кронштейном насквозь)
	_necro_sconce(Vector3(-10.5, 2.1, -9.62), 0)
	_lamp(Vector3(-10.5, 2.8, -4.0), Color(0.9, 0.8, 0.65), 8.0, 0.75)

# ================================================================ восток, этаж 1

func _sabbath() -> void:
	# x 7..15, z 0..10; колодец в подвал x 8.4..10.2, z 2.2..4
	ModelLib.solid(self, "Table_RoundLarge", Vector3(12.4, FLOOR_Y, 7.4), 0, HS)
	ModelLib.visual(self, "Carpet_Round", Vector3(12.4, FLOOR_Y + 0.02, 7.4), 0, HS * 1.8)
	# круг некро-стульев вокруг стола шабаша
	for i in 6:
		var ang := i * TAU / 6.0
		var sp := Vector3(12.4 + cos(ang) * 2.2, 0, 7.4 + sin(ang) * 2.2)
		_necro_solid("chair", sp.x, sp.z, rad_to_deg(-ang) + 90, 1.35)
	ModelLib.solid(self, "CandleStick_Triple", Vector3(12.4, FLOOR_Y + 0.85, 7.4))
	for tx: float in [7.4, 14.6]:
		ModelLib.visual(self, "Torch_Metal", Vector3(tx, 2.0, 8.6), 90 if tx < 10 else -90)
	ModelLib.visual(self, "Banner_2", Vector3(12.4, 2.9, 9.6))
	# котёл у северной стены, сундук и клетка по углам
	_necro_solid("cauldron", 8.2, 8.9, 0, 1.1)
	_necro_solid("chest", 14.2, 1.0, -35, 0.75)
	_necro_solid("cage", 7.7, 0.9, 15, 1.8)
	_lamp(Vector3(12.4, 3.0, 7.0), Color(1.0, 0.7, 0.45), 10.0, 1.0)
	_necro_at("chandelier", Vector3(12.4, SLAB_BOT - 0.475, 7.4), 0, 0.85, false)

func _amulet() -> void:
	# x 15..22, z 0..10; проём в стене x=15 при z 4..5.8. Мебель — некро-пак.
	var wb := _necro_solid("workbench", 18.5, 9.2, 0, 0.95)
	ModelLib.cap_collision(wb, 0.44)   # столешница ~0.9 над полом
	ModelLib.visual(self, "Chalice", Vector3(18.1, FLOOR_Y + 0.95, 9.2))
	ModelLib.grab(self, "Key_Gold", Vector3(18.9, FLOOR_Y + 0.95, 9.1), 0.5)
	_necro_solid("bookcase", 21.5, 7.6, -90, 2.1)
	ModelLib.visual(self, "Coin_Pile", Vector3(20.4, FLOOR_Y, 2.4))
	ModelLib.visual(self, "Coin_Pile_2", Vector3(20.9, FLOOR_Y, 2.9))
	ModelLib.grab(self, "Cage_Small", Vector3(16.4, FLOOR_Y, 1.4), 3.0)
	_necro_solid("anvil", 16.6, 8.8, 20, 0.75)
	_necro_sconce(Vector3(18.5, 2.2, 9.66), 180)
	_necro_solid("candelabra", 21.2, 1.2, 0, 1.7)
	_necro_at("tool_rack", Vector3(21.7, 1.9, 4.8), -90, 1.2)
	_lamp(Vector3(18.5, 2.9, 6.5), Color(1.0, 0.8, 0.55), 9.0, 0.9)

func _potion_room() -> void:
	# x 15..22, z -10..0 — ЗАПЕРТА. Дверь x=15 (z -5.8..-4), вентиляция (z -2.4..-1.6, h 0.55)
	pantry_door = NecroLib.door(self, "door_in", Vector3(WING_X, FLOOR_Y, -5.8), -90.0, 1.8, DOOR_H)
	pantry_door.locked = true
	pantry_door.locked_hint = "Зельеварочная заперта изнутри. В стене у пола — вентиляция, рука пролезет."
	if Game.world_state["pantry_open"]:
		pantry_door.unlock()
		pantry_door.call_deferred("open")   # рычаг уже дёрнут — дверь так и осталась открытой
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
	# котёл с кислотным варевом (уровень отвара — под кромкой некро-котла)
	_necro_solid("cauldron", 18.6, -5.0, 0, 1.1)
	var brew := MeshLib.cylinder(self, 0.40, 0.06, Vector3(18.6, FLOOR_Y + 0.82, -5.0), MeshLib.ACCENT)
	brew.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	_necro_solid("ingredient", 21.6, -7.6, -90, 1.8)
	_necro_solid("bookcase", 21.5, -3.0, -90, 2.1)
	for pdata in [["Potion_1", Vector3(16.4, FLOOR_Y, -8.6)], ["Potion_2", Vector3(16.9, FLOOR_Y, -8.9)],
			["Potion_4", Vector3(20.6, FLOOR_Y, -3.2)]]:
		ModelLib.grab(self, pdata[0] as String, pdata[1] as Vector3, 1.0)
	_necro_solid("barrel", 16.2, -1.4, 0, 1.0)
	ModelLib.grab(self, "Bucket_Wooden_1", Vector3(20.4, FLOOR_Y, -9.2), 2.0)
	# МУКА — цель рейда
	BreakableProp.make(self, "flour", Vector3(18.2, FLOOR_Y + 0.3, -2.6))
	BreakableProp.make(self, "flour", Vector3(19.6, FLOOR_Y + 0.3, -7.4))
	_lamp(Vector3(18.5, 2.6, -5.0), MeshLib.ACCENT, 8.0, 0.9)

func _toilet_e1() -> void:
	# трон у восточной стены лицом на запад, умывальный стол у южной лицом на север
	_necro_solid("toilet", 14.2, -8.4, -90, 1.15)
	_necro_solid("bath_a", 12.0, -9.1, 0, 1.8)
	ModelLib.visual(self, "Bathroom_ToiletPaperPile", Vector3(11.9, FLOOR_Y, -7.4), 0, HS)
	_lamp(Vector3(13.2, 2.8, -8.5), Color(0.85, 0.9, 0.95), 5.0, 0.7)

func _corridor_e1() -> void:
	_necro_solid("chest", 7.75, -2.2, 90, 0.75)
	_necro_solid("candelabra", 7.7, -8.6, 0, 1.7)
	ModelLib.visual(self, "Carpet_2", Vector3(10.0, FLOOR_Y + 0.02, -3.0), 90, HS)
	# бра вместо фонаря хауспака: тот кронштейном прошивал стену в зал шабаша
	_necro_sconce(Vector3(10.5, 2.1, -9.62), 0)
	_lamp(Vector3(10.5, 2.8, -4.0), Color(0.9, 0.8, 0.65), 8.0, 0.75)

# ================================================================ запад, этаж 2

func _living_room() -> void:
	# x -15..-7, z 4..10. Вход с балкона (x=-7, z 6..7.8), в коридор (z=4, x -11..-9.2)
	# спинкой к северной стене, сиденьем в комнату
	# ДИВАН РАЗВЁРНУТ НА 180, И ЭТО НЕ КОСМЕТИКА. Промер треугольников (probe_seat)
	# показал, что у Couch_Large1 спинка стоит на МИНИМУМЕ локального Z, а подушка
	# открыта в +Z. При прежнем rot_y=0 диван стоял спинкой в комнату, сиденьем в
	# стену — комментарий обещал обратное. Ведьма сидела с той стороны, где спинка,
	# и поэтому висела над паркетом: садиться там было не на что.
	# Положение доводится по AABB — спинка встаёт к северной стене сама, без
	# подобранного z: поставили в ноль, промерили, сдвинули на разницу.
	couch_body = ModelLib.solid(self, "Couch_Large1", Vector3(-12.6, F2, 0.0), 180, HS)
	couch_body.position.z += (HZ - 0.11) - ModelLib.merged_aabb(couch_body).end.z
	# Посадка считается ОТ ФАКТИЧЕСКОЙ ГЕОМЕТРИИ ДИВАНА, а не от подобранного числа.
	# Тут стояло couch_marker.position = (-12.6, F2 + 0.42 - 0.444, 8.55), и оба
	# числа были угаданы: solid() ставит модель по origin и AABB не центрирует, из-за
	# чего диван при HS=0.6 занимает z 8.695..9.890, а маркер на 8.55 оказался на
	# 14 см ВПЕРЕДИ переднего среза — ведьма висела над паркетом.
	# Теперь ModelLib.seat_spot находит подушку по треугольникам меша (высота и
	# глубина площадки, открытая сторона, поворот), а WitchNPC.sit_root_for переводит
	# точку подушки в положение корня по промеренному смещению таза. Ни одного
	# числа про диван в этом файле не осталось — переставь диван, и посадка поедет
	# за ним сама.
	couch_seat = ModelLib.seat_spot(couch_body, WitchNPC.PELVIS_HALF_Z, WitchNPC.THIGH_LEN)
	couch_marker = Node3D.new()
	couch_marker.position = WitchNPC.sit_root_for(couch_seat["point"], couch_seat["yaw"])
	couch_marker.rotation_degrees = Vector3(0, couch_seat["yaw"], 0)
	add_child(couch_marker)
	serve_zone = ServeZone.make(self, Vector3(-12.6, F2, 7.3))
	var fp := ModelLib.solid(self, "Fireplace", Vector3(-12.6, F2, 4.6), 0, HS)
	var fire := MeshLib.box(fp, Vector3(0.8, 0.4, 0.2), Vector3(0, 0.35, -0.1), Color(1.0, 0.45, 0.1))
	fire.material_override = MeshLib.mat(Color(1.0, 0.45, 0.1), 1.0, 0.0, Color(1.0, 0.5, 0.1))
	ModelLib.solid(self, "CoffeeTable", Vector3(-12.6, F2, 6.6), 0, FS)
	BreakableProp.make(self, "bottle", Vector3(-12.8, F2 + 0.62, 6.5))
	BreakableProp.make(self, "bottle", Vector3(-12.4, F2 + 0.62, 6.75))
	ModelLib.solid(self, "SofaDouble", Vector3(-8.4, F2, 8.4), -90, FS)
	ModelLib.solid(self, "SofaLong", Vector3(-14.2, F2, 7.0), 90, FS)
	ModelLib.visual(self, "Light_Floor1", Vector3(-14.3, F2, 9.4), 0, HS)
	ModelLib.visual(self, "Carpet_1", Vector3(-12.6, F2 + 0.02, 7.2), 0, HS * 1.3)
	ModelLib.visual(self, "Houseplant_8", Vector3(-7.8, F2, 9.5), 0, HS)
	ModelLib.visual(self, "Light_Ceiling5", Vector3(-12.6, CEIL - 0.05, 7.4), 0, HS)
	_lamp(Vector3(-12.6, F2 + 2.4, 7.4), Color(1.0, 0.75, 0.5), 9.0, 1.0)
	_lamp(Vector3(-12.6, F2 + 0.9, 5.2), Color(1.0, 0.5, 0.15), 4.5, 1.3)

func _bedrooms_west() -> void:
	# спальня 1: x -22..-15, z 4..10 (вход z 5.2..7)
	ModelLib.solid(self, "Bed_King", Vector3(-19.4, F2, 8.4), 180, HS)
	ModelLib.solid(self, "NightStand_1", Vector3(-21.0, F2, 9.3), 0, HS)
	ModelLib.solid(self, "NightStand_2", Vector3(-17.6, F2, 9.3), 0, HS)
	ModelLib.visual(self, "Light_Stand1", Vector3(-21.0, F2 + 0.55, 9.3), 0, HS)
	ModelLib.solid(self, "Drawer_3", Vector3(-16.0, F2, 5.0), -90, HS)
	ModelLib.visual(self, "Carpet_Round", Vector3(-19.4, F2 + 0.02, 5.8), 0, HS)
	_lamp(Vector3(-19.0, F2 + 2.4, 7.4), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# спальня 2: x -22..-15, z -2..4 (вход z 0..1.8)
	ModelLib.solid(self, "BedKing", Vector3(-19.6, F2, -0.4), 90, FS)
	ModelLib.solid(self, "Closet2", Vector3(-16.2, F2, 3.0), 180, FS)
	ModelLib.solid(self, "CoffeeTable2", Vector3(-16.4, F2, -1.2), 0, FS)
	ModelLib.visual(self, "Lamp2", Vector3(-21.2, F2, -1.4), 0, FS)
	ModelLib.solid(self, "Vase2", Vector3(-21.2, F2, 3.2), 0, FS)
	_lamp(Vector3(-19.0, F2 + 2.4, 1.0), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# спальня 3: x -22..-15, z -10..-2 (вход z -5..-3.2)
	ModelLib.solid(self, "Bed_Single", Vector3(-20.4, F2, -8.2), 90, HS)
	ModelLib.solid(self, "Bed_Bunk", Vector3(-16.4, F2, -8.4), -90, HS)
	ModelLib.solid(self, "NightStand_3", Vector3(-20.6, F2, -6.2), 90, HS)
	ModelLib.solid(self, "BookCase", Vector3(-18.4, F2, -9.5), 0, FS)
	ModelLib.visual(self, "Light_Desk", Vector3(-20.6, F2 + 0.5, -6.2), 0, HS)
	_lamp(Vector3(-19.0, F2 + 2.4, -6.5), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# коридор
	ModelLib.solid(self, "Drawer_5", Vector3(-7.8, F2, -5.0), -90, HS)
	ModelLib.visual(self, "Carpet_2", Vector3(-10.5, F2 + 0.02, -2.0), 90, HS * 1.2)
	ModelLib.visual(self, "Houseplant_2", Vector3(-7.8, F2, 2.6), 0, HS)
	_lamp(Vector3(-11.0, F2 + 2.4, -2.0), Color(0.9, 0.8, 0.65), 8.0, 0.7)

func _toilet_w2() -> void:
	ModelLib.solid(self, "Bathroom_Toilet", Vector3(-14.3, F2, -9.2), 90, HS)
	ModelLib.solid(self, "Bathroom_Shower1", Vector3(-12.2, F2, -9.3), 180, HS)
	ModelLib.visual(self, "Bathroom_Towel", Vector3(-14.7, F2 + 1.2, -7.6), 90, HS)
	_lamp(Vector3(-13.2, F2 + 2.3, -8.4), Color(0.85, 0.9, 0.95), 5.0, 0.7)

# ================================================================ восток, этаж 2

func _library() -> void:
	# x 7..22, z 3..10; вход с балкона (x=7, z 6..7.8) и из коридора (z=3, x 8.5..10.3)
	ModelLib.solid(self, "Bookshelf", Vector3(9.0, F2, 9.4), 180, HS)
	ModelLib.solid(self, "Bookshelf", Vector3(11.6, F2, 9.4), 180, HS)
	ModelLib.solid(self, "BookCaseLargeBooks", Vector3(21.2, F2, 7.0), -90, FS)
	ModelLib.solid(self, "BookCaseBooks", Vector3(21.2, F2, 4.6), -90, FS)
	ModelLib.solid(self, "Shelf_Large", Vector3(17.0, F2 + 1.6, 9.7), 180, HS)
	ModelLib.solid(self, "BookStand", Vector3(15.6, F2, 4.4), 160)
	ModelLib.solid(self, "ChairHandle", Vector3(8.6, F2, 4.6), 45, FS)
	for bdata in [["Book_Stack_1", Vector3(13.4, F2, 9.2)], ["BookGroup_Medium_1", Vector3(19.6, F2, 9.3)],
			["Book_Stack_2", Vector3(8.2, F2, 6.4)], ["BookGroup_Small_1", Vector3(20.8, F2, 3.6)]]:
		ModelLib.grab(self, bdata[0] as String, bdata[1] as Vector3, 1.0)
	_satanic_circle(Vector3(15.6, F2 + 0.02, 7.0), 2.4)
	ModelLib.visual(self, "Light_Ceiling2", Vector3(15.6, CEIL - 0.05, 7.0), 0, HS)
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
		ModelLib.solid(self, "CandleStick", Vector3(p.x, F2, p.z) + (p - center).normalized() * 0.4)
	BreakableProp.make(self, "skullpot", center + Vector3(0.4, 0.2, 0.3))
	ModelLib.grab(self, "Scroll_2", center + Vector3(-0.3, 0.1, -0.2), 0.5)
	var rl := OmniLight3D.new()
	rl.position = center + Vector3(0, 1.3, 0)
	rl.light_color = Color(0.9, 0.15, 0.1)
	rl.omni_range = 5.5
	rl.light_energy = 1.5
	add_child(rl)

func _bedrooms_east() -> void:
	# спальня 4: x 15..22, z -2..3 (вход z 0..1.8)
	ModelLib.solid(self, "Bed", Vector3(19.6, F2, -0.6), -90, FS)
	ModelLib.solid(self, "Nightstand_Shelf", Vector3(21.0, F2, 1.6), -90)
	ModelLib.solid(self, "Closet", Vector3(16.4, F2, 2.4), 180, FS)
	ModelLib.visual(self, "Light_Cube", Vector3(21.0, F2 + 0.75, 1.6), 0, HS)
	_lamp(Vector3(19.0, F2 + 2.4, 0.5), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# спальня 5: x 15..22, z -10..-2 (вход z -5..-3.2)
	ModelLib.solid(self, "BedKing", Vector3(19.4, F2, -8.2), 180, FS)
	ModelLib.solid(self, "Nightstand_Shelf", Vector3(21.2, F2, -9.2), -90)
	ModelLib.solid(self, "Drawer_4", Vector3(16.2, F2, -9.3), 90, HS)
	ModelLib.solid(self, "Plant", Vector3(16.4, F2, -2.8), 0, FS)
	ModelLib.visual(self, "Light_Small", Vector3(21.2, F2 + 0.75, -9.2), 0, HS)
	_lamp(Vector3(19.0, F2 + 2.4, -6.5), Color(0.95, 0.75, 0.55), 8.0, 0.75)
	# коридор
	ModelLib.visual(self, "Carpet_2", Vector3(10.5, F2 + 0.02, -2.0), 90, HS * 1.2)
	ModelLib.solid(self, "Drawer_1", Vector3(7.8, F2, -5.0), 90, HS)
	ModelLib.visual(self, "Lantern_Wall", Vector3(7.35, F2 + 2.0, -1.0), 90)
	_lamp(Vector3(10.5, F2 + 2.4, -2.5), Color(0.9, 0.8, 0.65), 8.0, 0.7)

func _broom_closet() -> void:
	# x 7..11.5, z -10..-7.5; дверь в стене z=-7.5 (x 8.4..9.6)
	ModelLib.visual(self, "Peg_Rack", Vector3(9.2, F2 + 1.7, -9.7))
	broom = Broom.new()
	broom.position = Vector3(8.4, F2 + 0.3, -8.6)
	broom.rotation_degrees = Vector3(0, 40, 0)
	add_child(broom)
	for bpos in [Vector3(10.4, F2 + 0.3, -8.4), Vector3(9.6, F2 + 0.3, -9.3)]:
		var extra := Broom.new()
		extra.position = bpos
		extra.rotation_degrees = Vector3(0, randf_range(0, 180), 0)
		add_child(extra)
	ModelLib.grab(self, "Bucket_Metal", Vector3(10.8, F2, -9.5), 2.0)
	ModelLib.solid(self, "Crate_Wooden", Vector3(7.6, F2, -9.4), 15)
	ModelLib.solid(self, "Shelf_Simple", Vector3(11.15, F2 + 1.1, -8.8), -90)
	DustPatch.make(self, Vector3(9.8, F2, -8.0), 0.45)   # ирония: в кладовке мётел пыльно
	_lamp(Vector3(9.2, F2 + 2.2, -8.8), Color(0.9, 0.85, 0.7), 4.5, 0.6)

func _toilet_e2() -> void:
	ModelLib.solid(self, "Bathroom_Toilet2", Vector3(14.3, F2, -9.2), -90, HS)
	ModelLib.solid(self, "Bathroom_Sink", Vector3(12.3, F2, -9.4), 180, HS)
	ModelLib.visual(self, "Bathroom_ToiletPaper", Vector3(14.7, F2 + 0.9, -8.4), -90, HS)
	ModelLib.visual(self, "Trashcan_Small2", Vector3(11.9, F2, -7.8), 0, HS)
	_lamp(Vector3(13.2, F2 + 2.3, -8.4), Color(0.85, 0.9, 0.95), 5.0, 0.7)

# ================================================================ спуски в подвал

func _shafts() -> void:
	_shaft(SHAFT_W, "Спуститься в винный погреб", "from_kitchen")
	_shaft(SHAFT_E, "Спуститься в подземелье", "from_sabbath")

## Вертикальный колодец: дырка в полу, четыре каменные стенки вниз, дно,
## стремянка на северной стенке. Спуск — спрыгнуть (2 м не ломают скелета),
## наверх возвращает портал подвала, как и раньше.
func _shaft(r: Rect2, prompt: String, spawn_id: String) -> void:
	var x0 := r.position.x
	var x1 := r.position.x + r.size.x
	var z0 := r.position.y
	var z1 := r.position.y + r.size.y
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var depth := FLOOR_Y - SHAFT_BOTTOM
	var wall_cy := SHAFT_BOTTOM + depth / 2.0
	MeshLib.solid_box(self, Vector3(0.25, depth, r.size.y + 0.5), Vector3(x0 - 0.1, wall_cy, cz), MeshLib.STONE_DARK)
	MeshLib.solid_box(self, Vector3(0.25, depth, r.size.y + 0.5), Vector3(x1 + 0.1, wall_cy, cz), MeshLib.STONE_DARK)
	MeshLib.solid_box(self, Vector3(r.size.x + 0.5, depth, 0.25), Vector3(cx, wall_cy, z1 + 0.1), MeshLib.STONE_DARK)
	MeshLib.solid_box(self, Vector3(r.size.x + 0.5, depth, 0.25), Vector3(cx, wall_cy, z0 - 0.1), MeshLib.STONE_DARK)
	# дно колодца
	MeshLib.solid_box(self, Vector3(r.size.x + 0.5, 0.3, r.size.y + 0.5), Vector3(cx, SHAFT_BOTTOM - 0.15, cz), MeshLib.STONE)
	# стремянка на северной стенке: две стойки и перекладины от дна до кромки
	for sx: float in [cx - 0.35, cx + 0.35]:
		MeshLib.box(self, Vector3(0.06, depth + 0.25, 0.06), Vector3(sx, wall_cy + 0.12, z1 - 0.09), MeshLib.WOOD_DARK)
	var rungs := int(depth / 0.3)
	for i in rungs:
		MeshLib.box(self, Vector3(0.76, 0.05, 0.07), Vector3(cx, SHAFT_BOTTOM + 0.25 + i * 0.3, z1 - 0.1), MeshLib.WOOD_DARK)
	var p := Portal.make(self, Vector3(cx, SHAFT_BOTTOM + 0.2, cz), prompt, "cellar", spawn_id)
	portals.append(p)
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx, SHAFT_BOTTOM + 1.2, cz)
	glow.light_color = Color(1.0, 0.62, 0.3)   # факельный отсвет из колодца
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
	# парадные ворота снаружи — те же две некро-створки, что и в интерьере
	front_door = NecroLib.door(self, "front_door", Vector3(-1.8, FLOOR_Y, -HZ), 0.0, 1.8, 2.8, 105.0, 1.1)
	front_door.locked = true
	front_door.locked_hint = "Парадные двери заколочены. Тебе — через чёрный ход, как и положено прислуге."
	var front_r := NecroLib.door(self, "front_door", Vector3(1.8, FLOOR_Y, -HZ), 180.0, 1.8, 2.8, -105.0, 1.1)
	front_r.locked = true
	front_r.locked_hint = front_door.locked_hint
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
