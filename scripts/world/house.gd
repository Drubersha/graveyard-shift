class_name WitchHouse extends Node3D
## Готический дом некромантки. Ставится фасадом на +Z (к кладбищу).
## Наружу торчат: front_door (заперта), вентиляция (лаз для руки) и door_lever внутри.
## Внутри — ломаемая мебель на ~475 очков срача и диван с ведьмой.

const W := 8.0   # ширина (x)
const D := 7.0   # глубина (z)
const H := 3.0   # высота стен
const T := 0.3   # толщина стен

var front_door: DoorGate
var door_lever: Lever
var witch: WitchNPC
var vent_marker: Node3D

func _ready() -> void:
	_floor_and_ceiling()
	_walls()
	_roof_and_tower()
	_door_and_vent()
	_porch()
	_gothic_details()
	_furniture()
	_cauldron()
	_clutter_decor()
	_witch_couch()
	_lights()

func _floor_and_ceiling() -> void:
	MeshLib.solid_box(self, Vector3(W, 0.12, D), Vector3(0, 0.06, 0), MeshLib.WOOD_DARK)
	MeshLib.solid_box(self, Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), MeshLib.HOUSE_TRIM)
	# ковёр
	MeshLib.box(self, Vector3(2.6, 0.03, 1.8), Vector3(0, 0.14, 0.2), Color(0.35, 0.12, 0.2))

func _walls() -> void:
	var wc := MeshLib.HOUSE_WALL
	var hz := D / 2.0
	var hx := W / 2.0
	# задняя и боковые стены — сплошные
	MeshLib.solid_box(self, Vector3(W, H, T), Vector3(0, H / 2.0, -hz), wc)
	MeshLib.solid_box(self, Vector3(T, H, D), Vector3(-hx, H / 2.0, 0), wc)
	MeshLib.solid_box(self, Vector3(T, H, D), Vector3(hx, H / 2.0, 0), wc)
	# фасад (z = +hz) с проёмом двери (x −0.5..0.5, h 2.1) и вентиляции (x 2.6..3.1, h 0.45)
	MeshLib.solid_box(self, Vector3(3.5, H, T), Vector3(-2.25, H / 2.0, hz), wc)        # слева от двери
	MeshLib.solid_box(self, Vector3(1.0, H - 2.1, T), Vector3(0, 2.1 + (H - 2.1) / 2.0, hz), wc)  # над дверью
	MeshLib.solid_box(self, Vector3(2.1, H, T), Vector3(1.55, H / 2.0, hz), wc)         # между дверью и вентиляцией
	MeshLib.solid_box(self, Vector3(0.5, H - 0.45, T), Vector3(2.85, 0.45 + (H - 0.45) / 2.0, hz), wc)  # над вентиляцией
	MeshLib.solid_box(self, Vector3(0.9, H, T), Vector3(3.55, H / 2.0, hz), wc)         # справа от вентиляции
	# светящиеся окна (декор, снаружи)
	for wdata in [Vector3(-2.3, 1.7, hz + 0.17), Vector3(1.6, 1.9, hz + 0.17)]:
		MeshLib.box(self, Vector3(0.7, 0.9, 0.04), wdata, Color(0.3, 0.5, 0.25)) \
			.material_override = MeshLib.mat(Color(0.4, 0.6, 0.3), 1.0, 0.0, MeshLib.ACCENT)
	for sx in [-hx, hx]:
		MeshLib.box(self, Vector3(0.04, 0.9, 0.7), Vector3(sx + (0.17 if sx > 0 else -0.17), 1.8, -1.0), Color(0.3, 0.5, 0.25)) \
			.material_override = MeshLib.mat(Color(0.4, 0.6, 0.3), 1.0, 0.0, MeshLib.ACCENT)
	# рамы-наличники
	MeshLib.box(self, Vector3(1.2, 0.12, 0.1), Vector3(0, 2.2, hz + 0.16), MeshLib.HOUSE_TRIM)

func _roof_and_tower() -> void:
	# двускатная крыша из двух наклонённых панелей
	MeshLib.solid_box(self, Vector3(W + 1.2, 0.16, 5.2), Vector3(0, H + 1.55, -1.85), MeshLib.ROOF, Vector3(-38, 0, 0))
	MeshLib.solid_box(self, Vector3(W + 1.2, 0.16, 5.2), Vector3(0, H + 1.55, 1.85), MeshLib.ROOF, Vector3(38, 0, 0))
	# фронтоны
	MeshLib.box(self, Vector3(W, 2.4, 0.14), Vector3(0, H + 1.0, -D / 2.0 + 0.1), MeshLib.HOUSE_WALL)
	MeshLib.box(self, Vector3(W, 2.4, 0.14), Vector3(0, H + 1.0, D / 2.0 - 0.1), MeshLib.HOUSE_WALL)
	# башня с конусом — визитка готики
	var tower := Node3D.new()
	tower.position = Vector3(-W / 2.0 - 0.6, 0, D / 2.0 - 0.6)
	add_child(tower)
	MeshLib.solid_box(tower, Vector3(1.6, 5.4, 1.6), Vector3(0, 2.7, 0), MeshLib.HOUSE_WALL.darkened(0.1))
	MeshLib.cone(tower, 1.35, 2.4, Vector3(0, 6.6, 0), MeshLib.ROOF)
	var tw := MeshLib.box(tower, Vector3(0.5, 0.7, 0.06), Vector3(0, 4.4, 0.82), Color(0.4, 0.6, 0.3))
	tw.material_override = MeshLib.mat(Color(0.4, 0.6, 0.3), 1.0, 0.0, MeshLib.ACCENT)
	# труба
	MeshLib.box(self, Vector3(0.5, 1.6, 0.5), Vector3(2.6, H + 1.8, -2.0), MeshLib.STONE_DARK)

func _door_and_vent() -> void:
	front_door = DoorGate.make(self, Vector3(-0.5, 0.12, D / 2.0), 0.0, 1.0, 2.05)
	front_door.locked = true
	front_door.locked_hint = "Заперто. Хозяйка не встаёт. Вентиляция справа выглядит подозрительно доступной…"
	# рамка вентиляции + решётка на полу перед ней
	vent_marker = Node3D.new()
	vent_marker.position = Vector3(2.85, 0.25, D / 2.0 + 0.2)
	add_child(vent_marker)
	MeshLib.box(self, Vector3(0.6, 0.08, 0.12), Vector3(2.85, 0.5, D / 2.0 + 0.12), MeshLib.METAL)
	for i in 3:
		MeshLib.box(self, Vector3(0.05, 0.4, 0.04), Vector3(2.68 + i * 0.17, 0.24, D / 2.0 + 0.14), MeshLib.METAL, Vector3(0, 0, 12))
	# рычаг внутри, у двери — рука дотянется с пола
	door_lever = Lever.new()
	door_lever.position = Vector3(1.2, 0.35, D / 2.0 - 0.45)
	door_lever.rotation_degrees = Vector3(0, 180, 0)
	door_lever.prompt = "Дёрнуть рычаг двери"
	add_child(door_lever)

func _porch() -> void:
	var hz := D / 2.0
	# плита крыльца — низкая (0.12), скелет заходит без прыжка
	MeshLib.solid_box(self, Vector3(2.4, 0.12, 1.6), Vector3(0, 0.06, hz + 0.95), MeshLib.STONE_DARK)
	# перила по бокам: дверной проём (x -0.5..0.5) и вентиляция (x 2.6..3.1) свободны
	for rx in [-1.08, 1.08]:
		MeshLib.solid_box(self, Vector3(0.07, 0.07, 1.44), Vector3(rx, 0.72, hz + 0.95), MeshLib.WOOD_DARK)
		for pz in [hz + 0.35, hz + 1.55]:
			MeshLib.box(self, Vector3(0.08, 0.55, 0.08), Vector3(rx, 0.4, pz), MeshLib.WOOD_DARK)
			MeshLib.cone(self, 0.07, 0.14, Vector3(rx, 0.83, pz), MeshLib.HOUSE_TRIM)

func _gothic_details() -> void:
	var hz := D / 2.0
	# остроконечные наличники-щипцы над окнами фасада и над дверью
	for peak in [Vector3(-2.3, 2.22, 0), Vector3(1.6, 2.42, 0), Vector3(0, 2.3, 0)]:
		MeshLib.box(self, Vector3(0.9, 0.08, 0.08), Vector3(peak.x, peak.y, hz + 0.16), MeshLib.HOUSE_TRIM)
		MeshLib.box(self, Vector3(0.52, 0.07, 0.07), Vector3(peak.x - 0.21, peak.y + 0.19, hz + 0.16), MeshLib.HOUSE_TRIM, Vector3(0, 0, 38))
		MeshLib.box(self, Vector3(0.52, 0.07, 0.07), Vector3(peak.x + 0.21, peak.y + 0.19, hz + 0.16), MeshLib.HOUSE_TRIM, Vector3(0, 0, -38))
	# шпиль с флюгером-флажком на башне
	var spire := Node3D.new()
	spire.position = Vector3(-W / 2.0 - 0.6, 0, D / 2.0 - 0.6)
	add_child(spire)
	MeshLib.cylinder(spire, 0.035, 1.2, Vector3(0, 8.35, 0), MeshLib.METAL)
	MeshLib.box(spire, Vector3(0.44, 0.24, 0.03), Vector3(0.25, 8.62, 0), MeshLib.WINE)
	MeshLib.sphere(spire, 0.07, Vector3(0, 8.95, 0), MeshLib.METAL)
	# фонари на цепях по бокам двери (зелёное ведьминское свечение)
	for lx in [-0.85, 0.85]:
		MeshLib.cylinder(self, 0.016, 0.5, Vector3(lx, 2.6, hz + 0.28), MeshLib.METAL)
		var lamp_body := MeshLib.box(self, Vector3(0.16, 0.22, 0.16), Vector3(lx, 2.24, hz + 0.28), MeshLib.HOUSE_TRIM)
		lamp_body.material_override = MeshLib.mat(MeshLib.HOUSE_TRIM, 0.6, 0.3, MeshLib.ACCENT)
		MeshLib.cone(self, 0.12, 0.12, Vector3(lx, 2.41, hz + 0.28), MeshLib.ROOF)
	# статичный «мультяшный» дым из трубы — сферы по возрастающей
	var puffs := [
		[Vector3(2.6, 5.85, -2.0), 0.16],
		[Vector3(2.75, 6.25, -2.05), 0.22],
		[Vector3(2.95, 6.72, -2.1), 0.3],
		[Vector3(3.2, 7.3, -2.15), 0.4],
	]
	for p in puffs:
		MeshLib.sphere(self, p[1], p[0], MeshLib.STONE.lightened(0.3), 0.9)

func _furniture() -> void:
	# стол с посудой по центру
	var table := BreakableProp.make(self, "table", Vector3(0, 0.5, 0.2))
	_candle(table, Vector3(-0.55, 0.44, -0.3), 0.14)
	for pdata in [Vector3(-0.4, 0.95, 0.1), Vector3(0.1, 0.95, 0.4), Vector3(0.45, 0.95, -0.1)]:
		BreakableProp.make(self, "plate", pdata)
	for bdata in [Vector3(-0.1, 1.0, -0.2), Vector3(0.35, 1.0, 0.25), Vector3(-0.5, 1.0, 0.4)]:
		BreakableProp.make(self, "bottle", bdata)
	# стулья
	BreakableProp.make(self, "chair", Vector3(-1.1, 0.45, 0.2), Vector3(0, 90, 0))
	BreakableProp.make(self, "chair", Vector3(1.0, 0.45, 0.6), Vector3(0, -70, 0))
	BreakableProp.make(self, "chair", Vector3(0.3, 0.45, -1.0), Vector3(0, 15, 0))
	# стеллажи у задней стены; свечи — дети стеллажей, при ударе улетят вместе с ними
	var shelf_a := BreakableProp.make(self, "shelf", Vector3(-2.4, 0.9, -3.0))
	var shelf_b := BreakableProp.make(self, "shelf", Vector3(2.4, 0.9, -3.0))
	_candle(shelf_a, Vector3(0.25, 0.93, 0))
	_candle(shelf_b, Vector3(-0.22, 0.915, 0.02), 0.13)
	# телек на ящике
	BreakableProp.make(self, "crate", Vector3(-3.2, 0.3, 0.6))
	BreakableProp.make(self, "tv", Vector3(-3.2, 0.85, 0.6), Vector3(0, 90, 0))
	# лампы, вазы, зелья
	BreakableProp.make(self, "lamp", Vector3(-3.4, 0.75, 2.6))
	BreakableProp.make(self, "lamp", Vector3(3.4, 0.75, -2.6))
	BreakableProp.make(self, "vase", Vector3(3.3, 0.25, 2.4))
	BreakableProp.make(self, "vase", Vector3(-3.5, 0.25, -2.8))
	BreakableProp.make(self, "vase", Vector3(1.8, 0.25, -3.1))
	BreakableProp.make(self, "pot", Vector3(0.9, 0.2, 2.9))
	BreakableProp.make(self, "pot", Vector3(-1.4, 0.2, 3.0))
	BreakableProp.make(self, "skullpot", Vector3(2.9, 0.2, -0.8))
	BreakableProp.make(self, "bottle", Vector3(2.6, 0.2, 1.2))
	BreakableProp.make(self, "bottle", Vector3(2.75, 0.2, 1.5))
	BreakableProp.make(self, "bottle", Vector3(-2.9, 0.2, 1.9))
	BreakableProp.make(self, "crate", Vector3(3.3, 0.3, -1.9))
	# камин у задней стены (декор + свет)
	MeshLib.solid_box(self, Vector3(1.6, 1.4, 0.5), Vector3(0, 0.7, -3.2), MeshLib.STONE_DARK)
	MeshLib.box(self, Vector3(0.9, 0.9, 0.1), Vector3(0, 0.55, -2.93), Color(0.06, 0.04, 0.04))
	var fire := MeshLib.box(self, Vector3(0.6, 0.35, 0.15), Vector3(0, 0.3, -2.9), Color(1.0, 0.45, 0.1))
	fire.material_override = MeshLib.mat(Color(1.0, 0.45, 0.1), 1.0, 0.0, Color(1.0, 0.5, 0.1))

func _cauldron() -> void:
	# казан у камина: чёрный цилиндр на ножках со светящейся зелёной жижей (декор)
	var cx := -1.35
	var cz := -2.95
	MeshLib.solid_box(self, Vector3(0.4, 0.12, 0.4), Vector3(cx, 0.18, cz), MeshLib.STONE_DARK)
	for i in 3:
		var ang := deg_to_rad(i * 120.0 + 30.0)
		MeshLib.box(self, Vector3(0.06, 0.2, 0.06), Vector3(cx + cos(ang) * 0.2, 0.32, cz + sin(ang) * 0.2), MeshLib.ROOF.darkened(0.3))
	MeshLib.cylinder(self, 0.3, 0.38, Vector3(cx, 0.55, cz), MeshLib.ROOF.darkened(0.4))
	MeshLib.cylinder(self, 0.33, 0.06, Vector3(cx, 0.72, cz), MeshLib.ROOF.darkened(0.3))
	var goo := MeshLib.cylinder(self, 0.27, 0.05, Vector3(cx, 0.75, cz), MeshLib.ACCENT)
	goo.material_override = MeshLib.mat(MeshLib.ACCENT, 0.4, 0.0, MeshLib.ACCENT)
	for b in [Vector3(cx - 0.08, 0.85, cz + 0.05), Vector3(cx + 0.1, 0.92, cz - 0.06)]:
		MeshLib.sphere(self, 0.035, b, MeshLib.ACCENT).material_override = MeshLib.mat(MeshLib.ACCENT, 0.5, 0.0, MeshLib.ACCENT)
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx, 1.0, cz)
	glow.light_color = MeshLib.ACCENT
	glow.omni_range = 2.4
	glow.light_energy = 0.8
	add_child(glow)

## Маленькая свеча с огоньком: тёплая эмиссия, чисто визуал.
func _candle(parent: Node, pos: Vector3, h := 0.16) -> void:
	var body := MeshLib.cylinder(parent, 0.035, h, pos, MeshLib.BONE)
	body.material_override = MeshLib.mat(MeshLib.BONE, 0.9, 0.0, MeshLib.BONE.darkened(0.45))
	var flame := MeshLib.sphere(parent, 0.024, pos + Vector3(0, h * 0.5 + 0.03, 0), MeshLib.BONE)
	flame.material_override = MeshLib.mat(MeshLib.BONE.lightened(0.06), 1.0, 0.0, MeshLib.BONE)

func _clutter_decor() -> void:
	# свечи на каминной полке
	_candle(self, Vector3(-0.55, 1.48, -3.18))
	_candle(self, Vector3(0.05, 1.465, -3.22), 0.13)
	_candle(self, Vector3(0.5, 1.49, -3.15), 0.18)
	# стопки книг на полу (визуал)
	var books_a := [MeshLib.WINE, MeshLib.ACCENT.darkened(0.3), MeshLib.WITCH_HAIR]
	for i in books_a.size():
		MeshLib.box(self, Vector3(0.28, 0.06, 0.2), Vector3(-1.75, 0.16 + i * 0.062, -2.4), books_a[i], Vector3(0, i * 22.0 - 15.0, 0))
	var books_b := [MeshLib.WOOD, MeshLib.WITCH_DRESS.lightened(0.25), MeshLib.STONE, MeshLib.WINE.darkened(0.2)]
	for i in books_b.size():
		MeshLib.box(self, Vector3(0.24, 0.055, 0.18), Vector3(3.35, 0.155 + i * 0.057, 0.3), books_b[i], Vector3(0, i * 28.0 + 10.0, 0))
	# ломаемый ящик-«библиотека»: книги сверху улетят вместе с ним
	var book_crate := BreakableProp.make(self, "crate", Vector3(-3.2, 0.3, -1.6))
	MeshLib.box(book_crate, Vector3(0.3, 0.07, 0.22), Vector3(0.02, 0.29, 0), MeshLib.WINE, Vector3(0, 14, 0))
	MeshLib.box(book_crate, Vector3(0.26, 0.06, 0.2), Vector3(-0.03, 0.35, 0.02), MeshLib.ACCENT.darkened(0.35), Vector3(0, -20, 0))
	# паутина в верхних углах — тонкие серые пластины под углом
	var hx := W / 2.0
	var hz := D / 2.0
	var webs := [
		[Vector3(-hx + 0.35, 2.72, -hz + 0.35), 45.0],
		[Vector3(hx - 0.35, 2.72, -hz + 0.35), -45.0],
		[Vector3(-hx + 0.35, 2.72, hz - 0.35), -45.0],
		[Vector3(hx - 0.35, 2.72, hz - 0.35), 45.0],
	]
	for wdata in webs:
		MeshLib.box(self, Vector3(0.6, 0.6, 0.015), wdata[0], MeshLib.STONE.lightened(0.35), Vector3(32, wdata[1], 0))
	# ещё ломаемого срача (+50 очков)
	BreakableProp.make(self, "skullpot", Vector3(0.95, 0.2, -2.55))
	BreakableProp.make(self, "vase", Vector3(-2.6, 0.25, -0.9))
	BreakableProp.make(self, "bottle", Vector3(1.45, 0.2, -2.7))
	BreakableProp.make(self, "bottle", Vector3(-0.6, 0.2, 1.2))

func _witch_couch() -> void:
	witch = WitchNPC.new()
	witch.position = Vector3(2.6, 0.12, -1.8)
	witch.rotation_degrees = Vector3(0, -35, 0)
	add_child(witch)

func _lights() -> void:
	var main_light := OmniLight3D.new()
	main_light.position = Vector3(0, 2.4, 0)
	main_light.light_color = Color(1.0, 0.75, 0.5)
	main_light.omni_range = 10.0
	main_light.light_energy = 1.1
	add_child(main_light)
	var fire_light := OmniLight3D.new()
	fire_light.position = Vector3(0, 0.8, -2.6)
	fire_light.light_color = Color(1.0, 0.5, 0.15)
	fire_light.omni_range = 5.0
	fire_light.light_energy = 1.6
	add_child(fire_light)
	# фонарь над крыльцом
	var porch := OmniLight3D.new()
	porch.position = Vector3(0, 2.6, D / 2.0 + 1.0)
	porch.light_color = MeshLib.ACCENT
	porch.omni_range = 6.0
	porch.light_energy = 1.2
	add_child(porch)
