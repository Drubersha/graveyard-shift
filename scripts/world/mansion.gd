class_name Mansion extends Node3D
## Особняк некромантки 3.0: два крыла, парадный зал с двумя лестницами,
## смыкающимися на балконе второго этажа, 19 комнат, мебель Quaternius,
## текстуры-тримы MegaKit. Задний фасад (+z) выходит на кладбище-задний двор,
## чёрный вход ведёт прямо на кухню западного крыла.
##
## Этаж 1: парадный зал (2 массивные двери), кухня, обеденный зал, швейная,
## туалет W, прихожая W — запад; шабаш-зал, амулетная, зельеварочная (заперта,
## рычаг+вентиляция), туалет E, прихожая E — восток.
## Этаж 2: гостиная (диван хозяйки), спальни 1-3, туалет W — запад;
## библиотека с сатанинским кругом, спальни 4-5, кладовка мётел, туалет E — восток.

const W := 30.0      # ширина (x)
const D := 12.0      # глубина (z)
const FH := 3.0      # высота этажа
const T := 0.35      # толщина внешних стен
const F2 := 3.16     # верх плиты 2-го этажа
const CEIL := 6.2    # низ потолка

const HS := ModelLib.HOUSE_SCALE
const FS := ModelLib.FURN_SCALE

## Портал перехода между локациями (улица ↔ дом).
class Portal extends Node3D:
	signal used
	var prompt := "Войти"
	func _ready() -> void:
		add_to_group("interactable")
	func get_prompt() -> String:
		return prompt
	func interact(_by: Node) -> void:
		used.emit()

var mode := "interior"   # "exterior" — оболочка для улицы, "interior" — комнаты
var back_portal: Portal
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

# материалы
var _mat_floor1: StandardMaterial3D
var _mat_floor2: StandardMaterial3D
var _mat_wall_out: StandardMaterial3D
var _mat_wall_in: StandardMaterial3D
var _mat_stone: StandardMaterial3D

func _ready() -> void:
	add_to_group("mansion")
	# полы — бесшовное дерево (Mahogany/Oak), стены — панельный трим, камень для санузлов
	_mat_floor1 = ModelLib.pbr_mat("Mahogany_Planks", Color(0.85, 0.8, 0.78), 0.45)
	_mat_floor2 = ModelLib.pbr_mat("Oak_Parquet_01", Color(0.82, 0.78, 0.72), 0.5)
	_mat_wall_out = ModelLib.tex_mat("wood_panel.png", Color(0.5, 0.42, 0.62), 0.55)
	_mat_wall_in = ModelLib.tex_mat("wood_panel.png", Color(0.78, 0.7, 0.78), 0.6)
	_mat_stone = ModelLib.tex_mat("stone_light.png", Color(0.75, 0.78, 0.85), 0.5)
	if mode == "exterior":
		_ext_walls()
		_exterior()
		_portal_back_outside()
		_witch_meet()
		return
	_ext_walls()
	_shell_interior()
	_grand_hall()
	_west_f1()
	_east_f1()
	_west_f2()
	_east_f2()
	_gothic_windows_inside()
	_portal_back_inside()
	_witch_on_couch()
	_lights()

# ---------------------------------------------------------------- хелперы

func _wall(size: Vector3, pos: Vector3, outer := false) -> StaticBody3D:
	var body := MeshLib.solid_box(self, size, pos, Color.WHITE)
	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _mat_wall_out if outer else _mat_wall_in
	return body

## Внутренняя стена вдоль x с проёмами: spans — [[x_from, x_to], ...] СТЕН (не проёмов).
func _wall_x(z: float, y0: float, h: float, spans: Array, lintels: Array = []) -> void:
	for s in spans:
		var w: float = s[1] - s[0]
		_wall(Vector3(w, h, 0.25), Vector3((s[0] + s[1]) / 2.0, y0 + h / 2.0, z))
	for l in lintels:  # [[x_from, x_to, y_from]]
		var w: float = l[1] - l[0]
		_wall(Vector3(w, y0 + h - l[2], 0.25), Vector3((l[0] + l[1]) / 2.0, (l[2] + y0 + h) / 2.0, z))

## Внутренняя стена вдоль z.
func _wall_z(x: float, y0: float, h: float, spans: Array, lintels: Array = []) -> void:
	for s in spans:
		var d: float = s[1] - s[0]
		_wall(Vector3(0.25, h, d), Vector3(x, y0 + h / 2.0, (s[0] + s[1]) / 2.0))
	for l in lintels:
		var d: float = l[1] - l[0]
		_wall(Vector3(0.25, y0 + h - l[2], d), Vector3(x, (l[2] + y0 + h) / 2.0, (l[0] + l[1]) / 2.0))

func _stone_floor(rect: Rect2) -> void:
	var mi := MeshLib.box(self, Vector3(rect.size.x, 0.04, rect.size.y),
		Vector3(rect.position.x + rect.size.x / 2.0, 0.15, rect.position.y + rect.size.y / 2.0), Color.WHITE)
	mi.material_override = _mat_stone

func _candle_stand(pos: Vector3) -> void:
	ModelLib.solid(self, ModelLib.KIT + "CandleStick_Stand.gltf", pos)

func _ceiling_light(path: String, pos: Vector3, ceil_y: float) -> void:
	ModelLib.visual(self, ModelLib.HOUSE + path, Vector3(pos.x, ceil_y - 0.05, pos.z), 0.0, HS)

# ---------------------------------------------------------------- каркас

## Внешние стены — нужны в обоих режимах (границы и снаружи, и изнутри).
func _ext_walls() -> void:
	var hz := D / 2.0
	var hx := W / 2.0
	_wall(Vector3(T, CEIL + 0.3, D), Vector3(-hx, (CEIL + 0.3) / 2.0, 0), true)
	_wall(Vector3(T, CEIL + 0.3, D), Vector3(hx, (CEIL + 0.3) / 2.0, 0), true)
	# задний фасад: чёрный вход в кухню x -7.5..-6.5
	for s in [[-15.0, -7.5], [-6.5, 15.0]]:
		_wall(Vector3(s[1] - s[0], CEIL + 0.3, T), Vector3((s[0] + s[1]) / 2.0, (CEIL + 0.3) / 2.0, hz), true)
	_wall(Vector3(1.0, CEIL + 0.3 - 2.24, T), Vector3(-7.0, (2.24 + CEIL + 0.3) / 2.0, hz), true)
	# передний фасад: парадные двери x -1.2..1.2
	for s in [[-15.0, -1.2], [1.2, 15.0]]:
		_wall(Vector3(s[1] - s[0], CEIL + 0.3, T), Vector3((s[0] + s[1]) / 2.0, (CEIL + 0.3) / 2.0, -hz), true)
	_wall(Vector3(2.4, CEIL + 0.3 - 2.64, T), Vector3(0, (2.64 + CEIL + 0.3) / 2.0, -hz), true)

func _shell_interior() -> void:
	# полы
	var f1 := MeshLib.solid_box(self, Vector3(W, 0.14, D), Vector3(0, 0.07, 0), Color.WHITE)
	(f1.get_child(1) as MeshInstance3D).material_override = _mat_floor1
	# плита 2-го этажа с атриумом над залом (дыра x -3.6..3.6, z -6..2.3)
	for slab in [
		[Vector3(11.4, 0.16, D), Vector3(-9.3, 3.08, 0)],          # запад x -15..-3.6
		[Vector3(11.4, 0.16, D), Vector3(9.3, 3.08, 0)],           # восток x 3.6..15
		[Vector3(7.2, 0.16, 3.7), Vector3(0, 3.08, 4.15)],         # задняя площадка x -3.6..3.6 z 2.3..6
	]:
		var s := MeshLib.solid_box(self, slab[0], slab[1], Color.WHITE)
		(s.get_child(1) as MeshInstance3D).material_override = _mat_floor2
	# потолок
	MeshLib.solid_box(self, Vector3(W, 0.16, D), Vector3(0, CEIL + 0.08, 0), MeshLib.HOUSE_TRIM)
	# ограждение атриума на 2 этаже
	for rail in [
		[Vector3(0.08, 1.0, 8.3), Vector3(-3.64, F2 + 0.5, -1.85)],
		[Vector3(0.08, 1.0, 8.3), Vector3(3.64, F2 + 0.5, -1.85)],
		[Vector3(7.4, 1.0, 0.08), Vector3(0, F2 + 0.5, 2.26)],
	]:
		MeshLib.solid_box(self, rail[0], rail[1], MeshLib.WOOD_DARK)
	# золотой поручень
	for rail_top in [
		[Vector3(0.12, 0.06, 8.3), Vector3(-3.64, F2 + 1.02, -1.85)],
		[Vector3(0.12, 0.06, 8.3), Vector3(3.64, F2 + 1.02, -1.85)],
		[Vector3(7.4, 0.06, 0.12), Vector3(0, F2 + 1.02, 2.26)],
	]:
		ModelLib.tex_box(self, rail_top[0], rail_top[1], "gold_band.png", Color(1, 0.95, 0.8), 0.8)

# ---------------------------------------------------------------- парадный зал

func _grand_hall() -> void:
	# стены зал ↔ крылья, этаж 1 (проёмы: север z 2..3, юг z -3..-2)
	for x in [-5.0, 5.0]:
		_wall_z(x, 0.14, FH - 0.14, [[-6, -3], [-2, 2], [3, 6]], [[-3, -2, 2.34], [2, 3, 2.34]])
	# стены крылья ↔ центр, этаж 2 (проёмы: север z 3.4..4.4 с площадки, юг z -2..-1 с балконов)
	for x in [-5.0, 5.0]:
		_wall_z(x, F2, CEIL - F2, [[-6, -2], [-1, 3.4], [4.4, 6]], [[-2, -1, F2 + 2.2], [3.4, 4.4, F2 + 2.2]])
	# парадная дверь — двойная, массивная, заперта до M2
	front_door = DoorGate.make_model(self, Vector3(-1.2, 0.14, -D / 2.0), 180.0, 2.4, 2.5,
		ModelLib.HOUSE + "Door_Double.fbx")
	front_door.locked = true
	front_door.locked_hint = "Парадные двери. За ними — город. Город спит. Не сегодня. (M2)"
	# две лестницы вдоль стен зала, смыкаются на задней площадке 2-го этажа
	for sx: float in [-1.0, 1.0]:
		var cx: float = sx * 4.45
		ModelLib.tex_solid_box(self, Vector3(1.1, 0.15, 6.45), Vector3(cx, 1.58, -0.5),
			"wood_planks.png", Color(0.6, 0.53, 0.5), 0.4, Vector3(-29.5, 0, 0))
		# ступени-визуал
		for i in 12:
			var frac := i / 11.0
			ModelLib.tex_box(self, Vector3(1.1, 0.1, 0.5), Vector3(cx, 0.2 + frac * 2.86, -3.3 + frac * 5.6),
				"wood_planks.png", Color(0.66, 0.6, 0.55), 0.4)
		# перила с золотым поручнем
		var rail_x: float = cx - sx * 0.6
		MeshLib.solid_box(self, Vector3(0.07, 0.85, 6.4), Vector3(rail_x, 1.95, -0.5), MeshLib.WOOD_DARK, Vector3(-29.5, 0, 0))
		ModelLib.tex_box(self, Vector3(0.11, 0.07, 6.4), Vector3(rail_x, 2.42, -0.5), "gold_band.png", Color(1, 0.95, 0.8), 0.8, Vector3(-29.5, 0, 0))
	# ковровая дорожка от входа к лестницам
	ModelLib.tex_box(self, Vector3(2.2, 0.03, 9.0), Vector3(0, 0.16, -1.2), "wood_panel.png", Color(0.6, 0.15, 0.2), 0.7)
	# люстра MegaKit в атриуме
	var chandelier := ModelLib.visual(self, ModelLib.KIT + "Chandelier.gltf", Vector3(0, CEIL - 1.3, -1.5), 0.0, 1.4)
	MeshLib.cylinder(chandelier, 0.02, 1.3, Vector3(0, 1.15, 0), MeshLib.METAL)
	# баннеры по бокам от входа и колонны
	ModelLib.visual(self, ModelLib.KIT + "Banner_1.gltf", Vector3(-2.4, 3.4, -5.7))
	ModelLib.visual(self, ModelLib.KIT + "Banner_2.gltf", Vector3(2.4, 3.4, -5.7))
	for cx in [-2.8, 2.8]:
		ModelLib.tex_solid_box(self, Vector3(0.5, CEIL, 0.5), Vector3(cx, CEIL / 2.0, 1.2), "stone_light.png", Color(0.7, 0.72, 0.8), 0.5)
	ModelLib.solid(self, ModelLib.KIT + "Bench.gltf", Vector3(-3.6, 0.14, -4.8), 90)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_1.fbx", Vector3(3.8, 0.14, -5.2), 0, HS)

# ---------------------------------------------------------------- запад, этаж 1

func _west_f1() -> void:
	# стены: кухня|обеденный (x=-10, проём z 2.5..3.5); юг: швейная|прихожая (x=-10, проём z -3..-2)
	_wall_z(-10.0, 0.14, FH - 0.14, [[0.5, 2.5], [3.5, 6]], [[2.5, 3.5, 2.34]])
	_wall_z(-10.0, 0.14, FH - 0.14, [[-6, -3], [-2, -0.5]], [[-3, -2, 2.34]])
	# стена север|юг запада (z=0.5): проёмы кухня→прихожую x -7.5..-6.5, обеденный x -13..-12
	_wall_x(0.5, 0.14, FH - 0.14, [[-15, -13], [-12, -7.5], [-6.5, -5]], [[-13, -12, 2.34], [-7.5, -6.5, 2.34]])
	# туалет W1 (угол прихожей): стены x=-8 и z=-3.6, дверь в z=-3.6
	_wall_z(-8.0, 0.14, FH - 0.14, [[-6, -3.6]])
	_wall_x(-3.6, 0.14, FH - 0.14, [[-8, -7.2], [-6.4, -5]], [[-7.2, -6.4, 2.2]])
	_stone_floor(Rect2(-8, -6, 2.4, 2.4))

	# --- кухня (x -10..-5, z 0.5..6), функциональные модели
	stove = Stove.new()
	stove.model_path = ModelLib.HOUSE + "Kitchen_Oven_Large.fbx"
	stove.position = Vector3(-5.55, 0.14, 4.8)
	stove.rotation_degrees = Vector3(0, -90, 0)
	add_child(stove)
	fridge = Fridge.new()
	fridge.model_path = ModelLib.HOUSE + "Kitchen_Fridge.fbx"
	fridge.position = Vector3(-5.6, 0.14, 2.1)
	fridge.rotation_degrees = Vector3(0, -90, 0)
	add_child(fridge)
	sink = SinkCounter.new()
	sink.model_path = ModelLib.HOUSE + "Kitchen_Sink.fbx"
	sink.position = Vector3(-9.0, 0.14, 5.35)
	add_child(sink)
	# кухонные тумбы и шкафчики
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_2Drawers.fbx", Vector3(-9.6, 0.14, 4.3), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_Cabinet1.fbx", Vector3(-8.0, 2.0, 5.6), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_1Drawers.fbx", Vector3(-6.6, 0.14, 5.5), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_CabinetSmall.fbx", Vector3(-5.5, 2.0, 3.6), -90, HS)
	# стол с табуретками
	ModelLib.solid(self, ModelLib.HOUSE + "Table_RoundSmall.fbx", Vector3(-7.6, 0.14, 2.2), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Stool.fbx", Vector3(-8.4, 0.14, 1.8), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Stool.fbx", Vector3(-6.9, 0.14, 2.7), 40, HS)
	# яйца на тумбе, вино, грязные тарелки
	BreakableProp.make(self, "egg", Vector3(-6.5, 1.05, 5.45))
	BreakableProp.make(self, "egg", Vector3(-6.75, 1.05, 5.3))
	BreakableProp.make(self, "bottle", Vector3(-9.55, 1.0, 4.1))
	for ppos in [Vector3(-7.4, 0.95, 2.1), Vector3(-7.8, 0.95, 2.4), Vector3(-9.0, 1.15, 5.2),
			Vector3(-6.4, 1.05, 5.6), Vector3(-8.6, 0.21, 3.4)]:
		var plate := BreakableProp.make(self, "plate_dirty", ppos)
		dirty_plates.append(plate)
	# пыль — цель уборки
	for dpos in [Vector3(-8.6, 0.16, 1.2), Vector3(-6.4, 0.16, 1.6), Vector3(-9.2, 0.16, 2.8),
			Vector3(-7.2, 0.16, 3.6), Vector3(-5.9, 0.16, 4.4), Vector3(-8.2, 0.16, 4.6)]:
		dust_list.append(DustPatch.make(self, dpos, randf_range(0.4, 0.55)))

	# --- обеденный зал (x -15..-10, z 0.5..6)
	ModelLib.solid(self, ModelLib.KIT + "Table_Large.gltf", Vector3(-12.5, 0.14, 3.2), 0)
	for i in 3:
		ModelLib.solid(self, ModelLib.HOUSE + "Chair_1.fbx", Vector3(-13.6 + i * 1.1, 0.14, 4.1), 180, HS)
		ModelLib.solid(self, ModelLib.HOUSE + "Chair_1.fbx", Vector3(-13.6 + i * 1.1, 0.14, 2.3), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Plate_1.fbx", Vector3(-13.4, 0.95, 3.5), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Plate_2.fbx", Vector3(-12.4, 0.95, 2.9), 0, HS)
	BreakableProp.make(self, "bottle", Vector3(-12.0, 1.1, 3.3))
	ModelLib.solid(self, ModelLib.HOUSE + "Kitchen_CabinetSmall.fbx", Vector3(-14.5, 0.14, 1.2), 90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Curtains_Double.fbx", Vector3(-12.5, 0.14, 5.8), 0, HS)
	_ceiling_light("Light_Chandelier.fbx", Vector3(-12.5, 0, 3.2), FH)

	# --- швейная мастерская (x -15..-10, z -6..-0.5)
	ModelLib.solid(self, ModelLib.KIT + "Dummy.gltf", Vector3(-13.5, 0.14, -2.2), 30)
	ModelLib.solid(self, ModelLib.KIT + "Workbench_Drawers.gltf", Vector3(-14.0, 0.14, -4.6), 0)
	ModelLib.solid(self, ModelLib.FURN + "Closet.fbx", Vector3(-10.6, 0.14, -5.3), 180, FS)
	ModelLib.solid(self, ModelLib.FURN + "Stool.fbx", Vector3(-12.6, 0.14, -3.6), 0, FS)
	ModelLib.visual(self, ModelLib.FURN + "Lamp.fbx", Vector3(-11.0, 0.14, -1.2), 0, FS)
	# рулоны ткани
	for i in 3:
		ModelLib.tex_box(self, Vector3(0.25, 1.4, 0.25), Vector3(-14.6 + i * 0.3, 0.84, -1.0 - i * 0.1),
			"wood_panel.png", [Color(0.6, 0.2, 0.3), Color(0.3, 0.2, 0.5), Color(0.2, 0.4, 0.3)][i], 0.9, Vector3(0, 0, randf_range(-8, 8)))
	ModelLib.visual(self, ModelLib.KIT + "Peg_Rack.gltf", Vector3(-12.0, 1.6, -5.85))

	# --- туалет W1
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet.fbx", Vector3(-7.4, 0.14, -5.4), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Sink.fbx", Vector3(-5.9, 0.14, -4.4), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_Mirror1.fbx", Vector3(-5.65, 1.5, -4.4), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_ToiletPaper.fbx", Vector3(-7.9, 0.9, -4.6), 90, HS)

	# --- прихожая юга (x -10..-5 минус туалет)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_3.fbx", Vector3(-9.5, 0.14, -0.9), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_1.fbx", Vector3(-5.4, 0.14, -1.4), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_Round.fbx", Vector3(-7.5, 0.15, -1.8), 0, HS)

# ---------------------------------------------------------------- восток, этаж 1

func _east_f1() -> void:
	# стены: шабаш|амулетная (x=10, проём z 2.5..3.5); зельеварочная|прихожая (x=10, дверь z -3..-2 + вентиляция z -1.5..-1)
	_wall_z(10.0, 0.14, FH - 0.14, [[0.5, 2.5], [3.5, 6]], [[2.5, 3.5, 2.34]])
	_wall_z(10.0, 0.14, FH - 0.14, [[-6, -3], [-1, -0.5]], [[-3, -2, 2.19], [-2, -1.5, 0.14], [-1.5, -1.0, 0.62]])
	# стена z=0.5 востока: проём в шабаш x 6.5..7.5
	_wall_x(0.5, 0.14, FH - 0.14, [[5, 6.5], [7.5, 15]], [[6.5, 7.5, 2.34]])
	# туалет E1: стены x=8 и z=-3.6, дверь в z=-3.6
	_wall_z(8.0, 0.14, FH - 0.14, [[-6, -3.6]])
	_wall_x(-3.6, 0.14, FH - 0.14, [[5, 6.4], [7.2, 8]], [[6.4, 7.2, 2.2]])
	_stone_floor(Rect2(5.6, -6, 2.4, 2.4))
	_stone_floor(Rect2(10, -6, 5, 5.5))  # каменный пол зельеварочной

	# --- шабаш-зал (x 5..10, z 0.5..6): круг для посиделок
	ModelLib.solid(self, ModelLib.HOUSE + "Table_RoundLarge.fbx", Vector3(7.5, 0.14, 3.2), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_Round.fbx", Vector3(7.5, 0.15, 3.2), 0, HS * 1.6)
	var seat_paths := [ModelLib.KIT + "Stool.gltf", ModelLib.HOUSE + "Stool.fbx", ModelLib.KIT + "Bench.gltf",
		ModelLib.HOUSE + "Chair_3.fbx", ModelLib.KIT + "Stool.gltf", ModelLib.HOUSE + "Chair_4.fbx"]
	for i in seat_paths.size():
		var ang := i * TAU / seat_paths.size()
		var sp := Vector3(7.5 + cos(ang) * 1.9, 0.14, 3.2 + sin(ang) * 1.9)
		var s := 1.0 if seat_paths[i].begins_with(ModelLib.KIT) else HS
		ModelLib.solid(self, seat_paths[i], sp, rad_to_deg(-ang) + 90, s)
	ModelLib.solid(self, ModelLib.KIT + "CandleStick_Triple.gltf", Vector3(7.5, 1.0, 3.2))
	for tx in [5.3, 9.7]:
		ModelLib.visual(self, ModelLib.KIT + "Torch_Metal.gltf", Vector3(tx, 1.8, 1.0), 90 if tx < 6 else -90)
	ModelLib.visual(self, ModelLib.KIT + "Banner_2.gltf", Vector3(7.5, 2.9, 5.8))

	# --- амулетная (x 10..15, z 0.5..6)
	ModelLib.solid(self, ModelLib.KIT + "Workbench.gltf", Vector3(12.5, 0.14, 5.0), 0)
	ModelLib.visual(self, ModelLib.KIT + "Chalice.gltf", Vector3(12.2, 1.05, 5.0))
	ModelLib.grab(self, ModelLib.KIT + "Key_Gold.gltf", Vector3(12.8, 1.05, 4.9), 0.5)
	ModelLib.solid(self, ModelLib.KIT + "Chest_Wood.gltf", Vector3(14.3, 0.14, 1.3), -35)
	ModelLib.visual(self, ModelLib.KIT + "Coin_Pile.gltf", Vector3(13.9, 0.14, 2.3))
	ModelLib.visual(self, ModelLib.KIT + "Coin_Pile_2.gltf", Vector3(14.4, 0.14, 2.7))
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Arch.gltf", Vector3(10.4, 0.14, 5.5), 0)
	ModelLib.visual(self, ModelLib.KIT + "Scroll_1.gltf", Vector3(10.4, 1.5, 5.5))
	ModelLib.grab(self, ModelLib.KIT + "Cage_Small.gltf", Vector3(11.2, 0.14, 1.0), 3.0)
	ModelLib.visual(self, ModelLib.KIT + "Lantern_Wall.gltf", Vector3(12.5, 2.0, 5.85))
	_candle_stand(Vector3(14.6, 0.14, 4.4))

	# --- зельеварочная (x 10..15, z -6..-0.5) — ЗАПЕРТА (миссия «мука»)
	pantry_door = DoorGate.make_model(self, Vector3(10.0, 0.14, -3.0), -90.0, 1.0, 2.05, ModelLib.HOUSE + "Door_5.fbx")
	pantry_door.locked = true
	pantry_door.locked_hint = "Зельеварочная. Заперта изнутри. У пола — вентиляция, рука пролезет."
	pantry_lever = Lever.new()
	pantry_lever.position = Vector3(10.55, 0.5, -2.4)
	pantry_lever.rotation_degrees = Vector3(0, 90, 0)
	pantry_lever.prompt = "Рычаг зельеварочной"
	add_child(pantry_lever)
	vent_marker = Node3D.new()
	vent_marker.position = Vector3(9.7, 0.4, -1.25)
	add_child(vent_marker)
	# решётка вентиляции (декор со стороны прихожей)
	for i in 3:
		MeshLib.box(self, Vector3(0.04, 0.4, 0.05), Vector3(9.85, 0.42, -1.42 + i * 0.15), MeshLib.METAL, Vector3(14, 0, 0))
	ModelLib.solid(self, ModelLib.KIT + "Cauldron.gltf", Vector3(12.5, 0.14, -3.5), 0)
	var brew := MeshLib.cylinder(self, 0.42, 0.06, Vector3(12.5, 0.82, -3.5), MeshLib.ACCENT)
	brew.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Small_Bottles.gltf", Vector3(14.6, 0.14, -5.0), -90)
	for pdata in [["Potion_1.gltf", Vector3(11.2, 0.14, -5.3)], ["Potion_2.gltf", Vector3(11.7, 0.14, -5.4)],
			["Potion_4.gltf", Vector3(13.2, 0.9, -5.0)]]:
		ModelLib.grab(self, ModelLib.KIT + (pdata[0] as String), pdata[1] as Vector3, 1.0)
	ModelLib.solid(self, ModelLib.KIT + "Barrel.gltf", Vector3(10.8, 0.14, -5.2), 0)
	ModelLib.grab(self, ModelLib.KIT + "Bucket_Wooden_1.gltf", Vector3(13.8, 0.14, -1.3), 2.0)
	ModelLib.visual(self, ModelLib.KIT + "SmallBottles_1.gltf", Vector3(14.55, 1.0, -4.6))
	# МУКА — цель рейда
	BreakableProp.make(self, "flour", Vector3(12.0, 0.35, -1.8))
	BreakableProp.make(self, "flour", Vector3(14.2, 0.35, -2.6))
	_candle_stand(Vector3(10.6, 0.14, -5.5))

	# --- туалет E1
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet2.fbx", Vector3(6.6, 0.14, -5.4), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_WashingMachine.fbx", Vector3(5.6, 0.14, -4.3), 90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_Mirror2.fbx", Vector3(7.9, 1.5, -4.4), 90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_ToiletPaperPile.fbx", Vector3(7.6, 0.14, -4.5), 0, HS)

	# --- прихожая востока
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_5.fbx", Vector3(9.4, 0.14, -0.9), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Trashcan_Small1.fbx", Vector3(5.4, 0.14, -1.2), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_2.fbx", Vector3(7.2, 0.15, -2.2), 90, HS)

# ---------------------------------------------------------------- запад, этаж 2

func _west_f2() -> void:
	# стены: гостиная|спальня1 (x=-10, проём z 2.5..3.5); спальня3|спальня2 (x=-10, проём z -3..-2)
	_wall_z(-10.0, F2, CEIL - F2, [[0.5, 2.5], [3.5, 6]], [[2.5, 3.5, F2 + 2.2]])
	_wall_z(-10.0, F2, CEIL - F2, [[-6, -3], [-2, -0.5]], [[-3, -2, F2 + 2.2]])
	# стена z=0.5 запада, этаж 2 — сплошная
	_wall_x(0.5, F2, CEIL - F2, [[-15, -5]])
	# туалет W2 в углу спальни3: стены x=-7, z=-4; дверь в z=-4
	_wall_z(-7.0, F2, CEIL - F2, [[-6, -4]])
	_wall_x(-4.0, F2, CEIL - F2, [[-7, -6.6], [-5.9, -5]], [[-6.6, -5.9, F2 + 2.1]])
	_stone_floor2(Rect2(-7, -6, 2, 2))

	# --- гостиная хозяйки (x -10..-5, z 0.5..6): диван, камин, подача завтрака
	couch_marker = Node3D.new()
	couch_marker.position = Vector3(-7.5, F2, 4.6)
	couch_marker.rotation_degrees = Vector3(0, 180, 0)
	add_child(couch_marker)
	ModelLib.solid(self, ModelLib.HOUSE + "Couch_Large1.fbx", Vector3(-7.5, F2, 4.9), 180, HS)
	serve_zone = ServeZone.make(self, Vector3(-7.5, F2, 3.6))
	var fp := ModelLib.solid(self, ModelLib.HOUSE + "Fireplace.fbx", Vector3(-7.5, F2, 0.85), 180, HS)
	var fire := MeshLib.box(fp, Vector3(0.7, 0.35, 0.2), Vector3(0, 0.3, 0.1), Color(1.0, 0.45, 0.1))
	fire.material_override = MeshLib.mat(Color(1.0, 0.45, 0.1), 1.0, 0.0, Color(1.0, 0.5, 0.1))
	ModelLib.solid(self, ModelLib.FURN + "CoffeeTable.fbx", Vector3(-8.7, F2, 3.6), 0, FS)
	BreakableProp.make(self, "bottle", Vector3(-8.7, F2 + 0.62, 3.5))
	BreakableProp.make(self, "bottle", Vector3(-8.5, F2 + 0.62, 3.75))
	ModelLib.solid(self, ModelLib.FURN + "SofaDouble.fbx", Vector3(-5.7, F2, 3.0), -90, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Floor1.fbx", Vector3(-5.5, F2, 5.4), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_1.fbx", Vector3(-7.5, F2 + 0.01, 3.4), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_7.fbx", Vector3(-9.6, F2, 5.4), 0, HS)

	# --- спальня 1 (x -15..-10, z 0.5..6)
	ModelLib.solid(self, ModelLib.HOUSE + "Bed_King.fbx", Vector3(-13.2, F2, 4.3), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "NightStand_1.fbx", Vector3(-14.6, F2, 5.5), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "NightStand_2.fbx", Vector3(-11.6, F2, 5.5), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_2.fbx", Vector3(-10.6, F2, 1.0), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Stand1.fbx", Vector3(-14.6, F2 + 0.55, 5.5), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Carpet_Round.fbx", Vector3(-13, F2 + 0.01, 2.6), 0, HS)

	# --- спальня 2 (x -15..-10, z -6..-0.5)
	ModelLib.solid(self, ModelLib.FURN + "BedKing.fbx", Vector3(-13.0, F2, -4.4), 90, FS)
	ModelLib.solid(self, ModelLib.FURN + "Closet2.fbx", Vector3(-14.5, F2, -1.2), 90, FS)
	ModelLib.solid(self, ModelLib.FURN + "Vase2.fbx", Vector3(-10.7, F2, -5.5), 0, FS)
	ModelLib.visual(self, ModelLib.FURN + "Lamp2.fbx", Vector3(-10.8, F2, -1.0), 0, FS)

	# --- спальня 3 (x -10..-5, z -6..-0.5, минус туалет)
	ModelLib.solid(self, ModelLib.HOUSE + "Bed_Single.fbx", Vector3(-9.2, F2, -4.8), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "NightStand_3.fbx", Vector3(-9.7, F2, -3.2), 90, HS)
	ModelLib.solid(self, ModelLib.FURN + "BookCase.fbx", Vector3(-5.4, F2, -2.6), -90, FS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Desk.fbx", Vector3(-9.7, F2 + 0.5, -3.2), 0, HS)

	# --- туалет W2
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet.fbx", Vector3(-6.5, F2, -5.5), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Shower1.fbx", Vector3(-5.4, F2, -4.6), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_Towel.fbx", Vector3(-6.9, F2 + 1.2, -4.1), 180, HS)

# ---------------------------------------------------------------- восток, этаж 2

func _east_f2() -> void:
	# библиотека — вся северная половина (x 5..15, z 0.5..6)
	_wall_x(0.5, F2, CEIL - F2, [[5, 15]])
	# юг: спальня4|спальня5 (x=10, проём z -3..-2)
	_wall_z(10.0, F2, CEIL - F2, [[-6, -3], [-2, -0.5]], [[-3, -2, F2 + 2.2]])
	# кладовка мётел (x 13..15, z -3..-0.5): стены x=13 (дверь z -2..-1.2) и z=-3
	_wall_z(13.0, F2, CEIL - F2, [[-3, -2], [-1.2, -0.5]], [[-2, -1.2, F2 + 2.05]])
	_wall_x(-3.0, F2, CEIL - F2, [[13, 15]])
	# туалет E2 (x 13..15, z -6..-4): стены x=13 и z=-4 (дверь x 13.4..14.1)
	_wall_z(13.0, F2, CEIL - F2, [[-6, -4]])
	_wall_x(-4.0, F2, CEIL - F2, [[14.1, 15]], [[13.0, 14.1, F2 + 2.1]])
	_stone_floor2(Rect2(13, -6, 2, 2))

	# --- библиотека с сатанинским кругом
	ModelLib.solid(self, ModelLib.HOUSE + "Bookshelf.fbx", Vector3(6.2, F2, 5.5), 0, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bookshelf.fbx", Vector3(8.4, F2, 5.5), 0, HS)
	ModelLib.solid(self, ModelLib.FURN + "BookCaseLargeBooks.fbx", Vector3(14.4, F2, 3.5), -90, FS)
	ModelLib.solid(self, ModelLib.FURN + "BookCaseBooks.fbx", Vector3(14.4, F2, 1.6), -90, FS)
	ModelLib.solid(self, ModelLib.HOUSE + "Shelf_Large.fbx", Vector3(12.0, F2 + 1.6, 5.75), 0, HS)
	ModelLib.solid(self, ModelLib.KIT + "BookStand.gltf", Vector3(9.8, F2, 1.1), 160)
	for bdata in [["Book_Stack_1.gltf", Vector3(6.0, F2, 1.4)], ["BookGroup_Medium_1.gltf", Vector3(13.6, F2, 5.4)],
			["Book_Stack_2.gltf", Vector3(11.2, F2, 5.3)], ["BookGroup_Small_1.gltf", Vector3(5.6, F2, 3.2)]]:
		ModelLib.grab(self, ModelLib.KIT + (bdata[0] as String), bdata[1] as Vector3, 1.0)
	_satanic_circle(Vector3(10.5, F2 + 0.02, 3.3), 1.7)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Ceiling2.fbx", Vector3(10.5, CEIL - 0.05, 3.3), 0, HS)

	# --- спальня 4 (x 5..10, z -6..-0.5): двухъярусная
	ModelLib.solid(self, ModelLib.HOUSE + "Bed_Bunk.fbx", Vector3(6.4, F2, -4.7), 90, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_4.fbx", Vector3(9.5, F2, -5.3), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Stool.fbx", Vector3(8.2, F2, -3.2), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Cube.fbx", Vector3(9.5, F2 + 0.9, -5.3), 0, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Houseplant_8.fbx", Vector3(5.5, F2, -1.0), 0, HS)

	# --- спальня 5 (x 10..15, z -6..-0.5, минус кладовка и туалет)
	ModelLib.solid(self, ModelLib.FURN + "Bed.fbx", Vector3(11.6, F2, -5.2), 180, FS)
	ModelLib.solid(self, ModelLib.KIT + "Nightstand_Shelf.gltf", Vector3(12.7, F2, -5.5), 180)
	ModelLib.solid(self, ModelLib.HOUSE + "Drawer_5.fbx", Vector3(10.5, F2, -1.1), -180, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Light_Small.fbx", Vector3(12.7, F2 + 0.75, -5.5), 0, HS)

	# --- кладовка мётел (x 13..15, z -3..-0.5)
	var closet_door := DoorGate.make_model(self, Vector3(13.0, F2, -2.0), -90.0, 0.8, 2.0, ModelLib.HOUSE + "Door_9.fbx")
	closet_door.prompt = "Кладовка мётел"
	ModelLib.visual(self, ModelLib.KIT + "Peg_Rack.gltf", Vector3(14.0, 1.7 + F2, -0.65), 180)
	broom = Broom.new()
	broom.position = Vector3(13.6, F2 + 0.25, -1.1)
	broom.rotation_degrees = Vector3(0, 40, 0)
	add_child(broom)
	for bpos in [Vector3(14.3, F2 + 0.25, -1.0), Vector3(14.0, F2 + 0.25, -2.3)]:
		var extra := Broom.new()
		extra.position = bpos
		extra.rotation_degrees = Vector3(0, randf_range(0, 180), 0)
		add_child(extra)
	ModelLib.grab(self, ModelLib.KIT + "Bucket_Metal.gltf", Vector3(14.5, F2, -2.6), 2.0)
	ModelLib.solid(self, ModelLib.KIT + "Crate_Wooden.gltf", Vector3(13.4, F2, -2.7), 15)
	ModelLib.solid(self, ModelLib.KIT + "Shelf_Simple.gltf", Vector3(14.6, F2 + 1.1, -1.6), -90)
	dust_list_append_decor(Vector3(14.0, F2 + 0.02, -1.6))

	# --- туалет E2
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Toilet2.fbx", Vector3(14.2, F2, -5.4), 180, HS)
	ModelLib.solid(self, ModelLib.HOUSE + "Bathroom_Sink.fbx", Vector3(13.4, F2, -4.5), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Bathroom_ToiletPaper.fbx", Vector3(14.8, F2 + 0.9, -4.6), -90, HS)
	ModelLib.visual(self, ModelLib.HOUSE + "Trashcan_Small2.fbx", Vector3(13.3, F2, -5.6), 0, HS)

## Декоративная пыль (не в счёте миссии) — в кладовке мётел, ирония обязательна.
func dust_list_append_decor(pos: Vector3) -> void:
	DustPatch.make(self, pos, 0.4)

## Сатанинский круг: багровое кольцо, пентаграмма, свечи по вершинам.
func _satanic_circle(center: Vector3, radius: float) -> void:
	var ring := MeshLib.cylinder(self, radius + 0.12, 0.02, center, Color(0.55, 0.06, 0.08))
	ring.material_override = MeshLib.mat(Color(0.55, 0.06, 0.08), 1.0, 0.0, Color(0.4, 0.02, 0.03))
	MeshLib.cylinder(self, radius - 0.05, 0.025, center + Vector3(0, 0.004, 0), Color(0.12, 0.08, 0.1))
	# пять вершин звезды, линии через одну (пентаграмма)
	var pts: Array[Vector3] = []
	for i in 5:
		var ang := -PI / 2.0 + i * TAU / 5.0
		pts.append(center + Vector3(cos(ang) * (radius - 0.12), 0.012, sin(ang) * (radius - 0.12)))
	for i in 5:
		var a := pts[i]
		var b := pts[(i + 2) % 5]
		var mid := (a + b) / 2.0
		var dir := b - a
		var line := MeshLib.box(self, Vector3(dir.length(), 0.015, 0.07), mid, Color(0.75, 0.1, 0.12))
		line.rotation.y = -atan2(dir.z, dir.x)
		line.material_override = MeshLib.mat(Color(0.75, 0.1, 0.12), 1.0, 0.0, Color(0.5, 0.04, 0.05))
	for p in pts:
		ModelLib.solid(self, ModelLib.KIT + "CandleStick.gltf", Vector3(p.x, F2, p.z) + (p - center).normalized() * 0.35)
	BreakableProp.make(self, "skullpot", center + Vector3(0.3, 0.15, 0.2))
	ModelLib.grab(self, ModelLib.KIT + "Scroll_2.gltf", center + Vector3(-0.2, 0.1, -0.15), 0.5)
	var rl := OmniLight3D.new()
	rl.position = center + Vector3(0, 1.2, 0)
	rl.light_color = Color(0.9, 0.15, 0.1)
	rl.omni_range = 4.5
	rl.light_energy = 1.4
	add_child(rl)

# ---------------------------------------------------------------- наружка

func _exterior() -> void:
	var hz := D / 2.0
	# крыша
	MeshLib.solid_box(self, Vector3(W + 1.6, 0.16, 7.1), Vector3(0, 7.85, 2.75), MeshLib.ROOF, Vector3(30, 0, 0))
	MeshLib.solid_box(self, Vector3(W + 1.6, 0.16, 7.1), Vector3(0, 7.85, -2.75), MeshLib.ROOF, Vector3(-30, 0, 0))
	MeshLib.box(self, Vector3(W + 1.7, 0.25, 0.5), Vector3(0, 9.6, 0), MeshLib.ROOF.darkened(0.2))
	for sx in [-(W / 2.0) - 0.05, W / 2.0 + 0.05]:
		MeshLib.box(self, Vector3(0.25, 1.1, 10.6), Vector3(sx, 6.75, 0), MeshLib.HOUSE_WALL)
		MeshLib.box(self, Vector3(0.25, 1.1, 6.6), Vector3(sx, 7.85, 0), MeshLib.HOUSE_WALL)
		MeshLib.box(self, Vector3(0.25, 1.1, 2.6), Vector3(sx, 8.95, 0), MeshLib.HOUSE_WALL)
	# башня на юго-восточном углу
	var tower := Node3D.new()
	tower.position = Vector3(W / 2.0 + 0.5, 0, -hz + 0.6)
	add_child(tower)
	ModelLib.tex_solid_box(tower, Vector3(2.0, 8.6, 2.0), Vector3(0, 4.3, 0), "wood_panel.png", Color(0.45, 0.38, 0.58), 0.55)
	MeshLib.cone(tower, 1.7, 3.0, Vector3(0, 10.1, 0), MeshLib.ROOF)
	var tw := MeshLib.box(tower, Vector3(0.5, 0.7, 0.06), Vector3(0, 6.4, 1.03), Color(0.4, 0.6, 0.3))
	tw.material_override = MeshLib.mat(Color(0.4, 0.6, 0.3), 1.0, 0.0, MeshLib.ACCENT)
	MeshLib.cylinder(tower, 0.04, 1.6, Vector3(0, 12.2, 0), MeshLib.METAL)
	MeshLib.box(tower, Vector3(0.5, 0.26, 0.03), Vector3(0.28, 12.6, 0), MeshLib.WINE)
	# труба гостиной + дым
	MeshLib.box(self, Vector3(0.55, 3.2, 0.55), Vector3(-7.5, 7.6, 6.3), MeshLib.STONE_DARK)
	for p in [[Vector3(-7.45, 9.4, 6.3), 0.18], [Vector3(-7.3, 9.85, 6.35), 0.26], [Vector3(-7.05, 10.45, 6.4), 0.36]]:
		MeshLib.sphere(self, p[1], p[0], MeshLib.STONE.lightened(0.3), 0.9)
	# светящиеся окна: этаж 1 и этаж 2, зад и перед
	for wx in [-12.5, -3.0, 3.0, 7.5, 12.5]:
		_glow(Vector3(wx, 1.9, hz + 0.19))
		_glow(Vector3(wx, 4.6, hz + 0.19))
	for wx in [-12.0, -7.0, 7.0, 12.0]:
		_glow(Vector3(wx, 1.9, -hz - 0.19))
		_glow(Vector3(wx, 4.6, -hz - 0.19))
	for sx in [-(W / 2.0) - 0.19, W / 2.0 + 0.19]:
		_glow(Vector3(sx, 4.6, 2.0), true)
		_glow(Vector3(sx, 1.9, -2.0), true)
	# заднее крыльцо у кухни (встреча с ведьмой)
	MeshLib.solid_box(self, Vector3(3.6, 0.14, 2.0), Vector3(-7.0, 0.07, hz + 1.0), MeshLib.STONE_DARK)
	MeshLib.box(self, Vector3(2.4, 0.1, 1.4), Vector3(-7.0, 2.75, hz + 0.6), MeshLib.ROOF, Vector3(12, 0, 0))
	for px in [-8.0, -6.0]:
		MeshLib.box(self, Vector3(0.09, 2.6, 0.09), Vector3(px, 1.35, hz + 1.1), MeshLib.WOOD_DARK)
	var lamp := MeshLib.box(self, Vector3(0.16, 0.2, 0.16), Vector3(-6.3, 2.3, hz + 0.32), MeshLib.HOUSE_TRIM)
	lamp.material_override = MeshLib.mat(MeshLib.HOUSE_TRIM, 0.6, 0.3, MeshLib.ACCENT)
	# свет крылец (экстерьер живёт без _lights)
	for lspec in [[Vector3(-7.0, 2.6, hz + 0.8), MeshLib.ACCENT], [Vector3(0, 3.2, -hz - 1.2), MeshLib.ACCENT]]:
		var pl := OmniLight3D.new()
		pl.position = lspec[0]
		pl.light_color = lspec[1]
		pl.omni_range = 6.5
		pl.light_energy = 1.2
		add_child(pl)
	# парадное крыльцо со ступенями
	MeshLib.solid_box(self, Vector3(5.2, 0.14, 2.2), Vector3(0, 0.07, -hz - 1.1), MeshLib.STONE_DARK)
	for gx in [-2.0, 2.0]:
		ModelLib.tex_solid_box(self, Vector3(0.55, 3.1, 0.55), Vector3(gx, 1.55, -hz - 0.4), "stone_light.png", Color(0.7, 0.72, 0.8), 0.5)
	MeshLib.box(self, Vector3(5.6, 0.35, 2.6), Vector3(0, 3.25, -hz - 1.0), MeshLib.HOUSE_TRIM)

func _glow(pos: Vector3, side := false) -> void:
	var size := Vector3(0.05, 1.0, 0.8) if side else Vector3(0.8, 1.0, 0.05)
	var p := MeshLib.box(self, size, pos, Color(0.4, 0.6, 0.3))
	p.material_override = MeshLib.mat(Color(0.4, 0.6, 0.3), 1.0, 0.0, MeshLib.ACCENT)

func _stone_floor2(rect: Rect2) -> void:
	var mi := MeshLib.box(self, Vector3(rect.size.x, 0.03, rect.size.y),
		Vector3(rect.position.x + rect.size.x / 2.0, F2 + 0.015, rect.position.y + rect.size.y / 2.0), Color.WHITE)
	mi.material_override = _mat_stone

# ---------------------------------------------------------------- порталы и окна

func _portal_back_outside() -> void:
	# закрытая дверь-заглушка в проёме + портал входа
	var stub := StaticBody3D.new()
	stub.position = Vector3(-7.0, 0.14, D / 2.0)
	add_child(stub)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 2.1, 0.15)
	col.shape = shape
	col.position = Vector3(0, 1.05, 0)
	stub.add_child(col)
	var vis := ModelLib.visual(stub, ModelLib.HOUSE + "Door_1.fbx", Vector3(0.5, 0, 0), 180.0)
	vis.scale = Vector3(1.0 / 1.74, 2.1 / 4.19, 0.7)
	back_portal = Portal.new()
	back_portal.prompt = "Войти в особняк"
	back_portal.position = Vector3(-7.0, 0.14, D / 2.0 + 0.6)
	add_child(back_portal)
	# парадные двери снаружи — заперты до M2
	front_door = DoorGate.make_model(self, Vector3(-1.2, 0.14, -D / 2.0), 180.0, 2.4, 2.5,
		ModelLib.HOUSE + "Door_Double.fbx")
	front_door.locked = true
	front_door.locked_hint = "Парадные двери. За ними — город. Город спит. Не сегодня. (M2)"

func _portal_back_inside() -> void:
	var stub := StaticBody3D.new()
	stub.position = Vector3(-7.0, 0.14, D / 2.0)
	add_child(stub)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 2.1, 0.15)
	col.shape = shape
	col.position = Vector3(0, 1.05, 0)
	stub.add_child(col)
	var vis := ModelLib.visual(stub, ModelLib.HOUSE + "Door_1.fbx", Vector3(-0.5, 0, 0), 0.0)
	vis.scale = Vector3(1.0 / 1.74, 2.1 / 4.19, 0.7)
	back_portal = Portal.new()
	back_portal.prompt = "Выйти на кладбище"
	back_portal.position = Vector3(-7.0, 0.14, D / 2.0 - 0.6)
	add_child(back_portal)

## Готические окна изнутри — на внутренней стороне внешних стен.
func _gothic_windows_inside() -> void:
	var gw: Texture2D = load("res://assets/textures/gothic/Gothic_Window_001.png")
	var m := StandardMaterial3D.new()
	m.albedo_texture = gw
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.emission_enabled = true
	m.emission = MeshLib.ACCENT.darkened(0.3)
	m.emission_energy_multiplier = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hz := D / 2.0
	var spots := []
	for wx in [-12.5, -3.0, 3.0, 12.5]:
		spots.append([Vector3(wx, 1.9, hz - 0.19), 0.0])
		spots.append([Vector3(wx, F2 + 1.7, hz - 0.19), 0.0])
		spots.append([Vector3(wx, 1.9, -hz + 0.19), 0.0])
		spots.append([Vector3(wx, F2 + 1.7, -hz + 0.19), 0.0])
	for sx in [-(W / 2.0) + 0.19, W / 2.0 - 0.19]:
		spots.append([Vector3(sx, F2 + 1.7, 2.0), 90.0])
		spots.append([Vector3(sx, 1.9, -2.0), 90.0])
	for spot in spots:
		var quad := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.1, 1.5)
		pm.orientation = PlaneMesh.FACE_Z
		quad.mesh = pm
		quad.material_override = m
		quad.position = spot[0]
		quad.rotation_degrees = Vector3(0, spot[1], 0)
		add_child(quad)

func _witch_on_couch() -> void:
	witch = WitchNPC.new()
	witch.position = couch_marker.position
	witch.rotation_degrees = couch_marker.rotation_degrees
	add_child(witch)
	witch.sit_now()

# ---------------------------------------------------------------- ведьма и свет

func _witch_meet() -> void:
	meet_marker = Node3D.new()
	meet_marker.position = Vector3(-5.4, 0.14, D / 2.0 + 1.1)
	meet_marker.rotation_degrees = Vector3(0, 180, 0)
	add_child(meet_marker)
	witch = WitchNPC.new()
	witch.position = meet_marker.position
	witch.rotation_degrees = meet_marker.rotation_degrees
	add_child(witch)

func _lights() -> void:
	var specs := [
		[Vector3(0, 4.6, -1.5), Color(1.0, 0.78, 0.5), 12.0, 1.3],     # атриум/люстра
		[Vector3(0, 2.3, 4.2), Color(1.0, 0.8, 0.55), 6.0, 0.8],       # под площадкой
		[Vector3(-7.5, 2.4, 3.2), Color(1.0, 0.8, 0.55), 7.0, 1.0],    # кухня
		[Vector3(-12.5, 2.4, 3.2), Color(1.0, 0.75, 0.5), 7.0, 0.9],   # обеденный
		[Vector3(-12.5, 2.4, -3.2), Color(0.95, 0.8, 0.6), 6.5, 0.8],  # швейная
		[Vector3(-7.2, 2.4, -2.0), Color(0.9, 0.8, 0.65), 5.5, 0.7],   # прихожая W
		[Vector3(7.5, 2.4, 3.2), Color(1.0, 0.7, 0.45), 7.0, 0.9],     # шабаш
		[Vector3(12.5, 2.4, 3.2), Color(1.0, 0.8, 0.55), 6.5, 0.8],    # амулетная
		[Vector3(12.5, 2.2, -3.2), MeshLib.ACCENT, 6.5, 0.9],          # зельеварочная (зелёная)
		[Vector3(7.2, 2.4, -2.0), Color(0.9, 0.8, 0.65), 5.5, 0.7],    # прихожая E
		[Vector3(-7.5, F2 + 2.3, 3.2), Color(1.0, 0.75, 0.5), 7.0, 1.0],   # гостиная
		[Vector3(-7.5, F2 + 1.0, 1.2), Color(1.0, 0.5, 0.15), 4.0, 1.3],   # камин
		[Vector3(-12.5, F2 + 2.3, 3.2), Color(0.95, 0.75, 0.55), 6.0, 0.7],# спальня 1
		[Vector3(-12.5, F2 + 2.3, -3.2), Color(0.95, 0.75, 0.55), 6.0, 0.7],# спальня 2
		[Vector3(-8, F2 + 2.3, -3.5), Color(0.95, 0.75, 0.55), 5.5, 0.7],  # спальня 3
		[Vector3(10, F2 + 2.3, 3.2), Color(1.0, 0.8, 0.55), 8.0, 0.9],     # библиотека
		[Vector3(7.5, F2 + 2.3, -3.2), Color(0.95, 0.75, 0.55), 6.0, 0.7], # спальня 4
		[Vector3(11.8, F2 + 2.3, -3.5), Color(0.95, 0.75, 0.55), 5.5, 0.7],# спальня 5
		[Vector3(14, F2 + 2.0, -1.7), Color(0.9, 0.85, 0.7), 3.5, 0.6],    # кладовка
		[Vector3(-7.0, 2.6, D / 2.0 + 0.8), MeshLib.ACCENT, 6.0, 1.2],     # заднее крыльцо
		[Vector3(0, 3.2, -D / 2.0 - 1.2), MeshLib.ACCENT, 7.0, 1.1],       # парадное крыльцо
	]
	for s in specs:
		var light := OmniLight3D.new()
		light.position = s[0]
		light.light_color = s[1]
		light.omni_range = s[2]
		light.light_energy = s[3]
		add_child(light)
	# люстры-модели в комнатах (визуал)
	_ceiling_light("Light_Ceiling1.fbx", Vector3(-7.5, 0, 3.2), FH)
	_ceiling_light("Light_Ceiling3.fbx", Vector3(7.5, 0, 3.2), FH)
	_ceiling_light("Light_Ceiling4.fbx", Vector3(12.5, 0, 3.2), FH)
	_ceiling_light("Light_Ceiling5.fbx", Vector3(-7.5, 0, 3.2 - 0.0), CEIL)
	_ceiling_light("Light_Ceiling6.fbx", Vector3(-12.5, 0, 3.2), CEIL)
	_ceiling_light("Light_CeilingSingle.fbx", Vector3(7.5, 0, -3.2), CEIL)
