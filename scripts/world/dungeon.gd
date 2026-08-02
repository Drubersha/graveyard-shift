class_name Dungeon extends Node3D
## Подвал особняка — отдельная локация. Два зала:
## винный погреб (под кухней, здесь берут вино для завтрака) и ритуальное
## подземелье (под залом шабаша). Соединены сырым коридором.
## Наверх ведут две лестницы — каждая своим порталом в свою комнату.

const H := 3.8          # высота помещений
const T := 0.4          # стены
const FLOOR_Y := 0.0

const CELLAR := Rect2(-17.0, -4.0, 11.0, 12.0)   # x -17..-6, z -4..8
const RITUAL := Rect2(6.0, -4.0, 11.0, 12.0)     # x 6..17,  z -4..8
const CORR_Z0 := 1.5
const CORR_Z1 := 5.5

var portals: Array[Portal] = []
var spawns := {}

var _mat_wall: StandardMaterial3D
var _mat_floor: StandardMaterial3D
var _mat_ceil: StandardMaterial3D
var _wine_wall: StandardMaterial3D
var _wine_floor: StandardMaterial3D
var _wine_ceil: StandardMaterial3D

func _ready() -> void:
	add_to_group("dungeon")
	# наборы Meshy «текстуры дома»: погреб — свой, ритуальная и коридор — dungeon
	_mat_wall = ModelLib.tex_mat("house/dungeon_wall.png", Color.WHITE, 0.35)
	_mat_floor = ModelLib.tex_mat("house/dungeon_floor.png", Color.WHITE, 0.4)
	_mat_ceil = ModelLib.tex_mat("house/dungeon_ceil.png", Color.WHITE, 0.3)
	_wine_wall = ModelLib.tex_mat("house/wine_cellar_wall.png", Color.WHITE, 0.35)
	_wine_floor = ModelLib.tex_mat("house/wine_cellar_floor.png", Color.WHITE, 0.4)
	_wine_ceil = ModelLib.tex_mat("house/wine_cellar_ceil.png", Color.WHITE, 0.3)
	_shell()
	_cellar_room()
	_ritual_room()
	_corridor()
	_stairs_up(Vector3(-9.25, 0, 4.5), "Подняться на кухню", "kitchen_stairs", "from_kitchen")
	_stairs_up(Vector3(9.25, 0, 4.5), "Подняться в зал шабаша", "sabbath_stairs", "from_sabbath")

# ---------------------------------------------------------------- каркас

func _floor_rect(r: Rect2, mat: Material = null) -> void:
	var s := MeshLib.solid_box(self, Vector3(r.size.x, 0.3, r.size.y),
		Vector3(r.position.x + r.size.x / 2.0, FLOOR_Y - 0.15, r.position.y + r.size.y / 2.0), Color.WHITE)
	ModelLib.override_all(s, mat if mat else _mat_floor)

func _wall(size: Vector3, pos: Vector3, mat: Material = null) -> void:
	var b := MeshLib.solid_box(self, size, pos, Color.WHITE)
	ModelLib.override_all(b, mat if mat else _mat_wall)

## Потолок с коллизией: иначе камера-пружина протыкает свод и смотрит из-за него.
## Плита шире комнаты на толщину стен — иначе над верхом стены остаётся щель в небо.
func _ceiling(r: Rect2, mat: Material = null) -> void:
	var g := r.grow(T)
	var b := MeshLib.solid_box(self, Vector3(g.size.x, 0.3, g.size.y),
		Vector3(g.position.x + g.size.x / 2.0, H + 0.15, g.position.y + g.size.y / 2.0), Color.WHITE)
	ModelLib.override_all(b, mat if mat else _mat_ceil)

func _shell() -> void:
	_floor_rect(CELLAR, _wine_floor)
	_floor_rect(RITUAL)
	_floor_rect(Rect2(-6.0, CORR_Z0, 12.0, CORR_Z1 - CORR_Z0))
	_ceiling(CELLAR, _wine_ceil)
	_ceiling(RITUAL)
	_ceiling(Rect2(-6.0, CORR_Z0, 12.0, CORR_Z1 - CORR_Z0))
	# стены погреба (проём в коридор в стене x=-6)
	_wall(Vector3(T, H, CELLAR.size.y), Vector3(CELLAR.position.x, H / 2.0, 2.0), _wine_wall)
	_wall(Vector3(CELLAR.size.x, H, T), Vector3(-11.5, H / 2.0, CELLAR.position.y), _wine_wall)
	_wall(Vector3(CELLAR.size.x, H, T), Vector3(-11.5, H / 2.0, CELLAR.position.y + CELLAR.size.y), _wine_wall)
	_wall(Vector3(T, H, CORR_Z0 - CELLAR.position.y), Vector3(-6.0, H / 2.0, (CELLAR.position.y + CORR_Z0) / 2.0), _wine_wall)
	_wall(Vector3(T, H, CELLAR.position.y + CELLAR.size.y - CORR_Z1), Vector3(-6.0, H / 2.0, (CORR_Z1 + CELLAR.position.y + CELLAR.size.y) / 2.0), _wine_wall)
	# стены подземелья (зеркально)
	_wall(Vector3(T, H, RITUAL.size.y), Vector3(RITUAL.position.x + RITUAL.size.x, H / 2.0, 2.0))
	_wall(Vector3(RITUAL.size.x, H, T), Vector3(11.5, H / 2.0, RITUAL.position.y))
	_wall(Vector3(RITUAL.size.x, H, T), Vector3(11.5, H / 2.0, RITUAL.position.y + RITUAL.size.y))
	_wall(Vector3(T, H, CORR_Z0 - RITUAL.position.y), Vector3(6.0, H / 2.0, (RITUAL.position.y + CORR_Z0) / 2.0))
	_wall(Vector3(T, H, RITUAL.position.y + RITUAL.size.y - CORR_Z1), Vector3(6.0, H / 2.0, (CORR_Z1 + RITUAL.position.y + RITUAL.size.y) / 2.0))
	# стены коридора
	_wall(Vector3(12.0, H, T), Vector3(0, H / 2.0, CORR_Z0))
	_wall(Vector3(12.0, H, T), Vector3(0, H / 2.0, CORR_Z1))

## Лестница наверх: ступени уходят в тёмный проём потолка, внизу — портал.
func _stairs_up(base: Vector3, prompt: String, spawn_id_up: String, spawn_id_here: String) -> void:
	for i in 10:
		var frac := i / 9.0
		ModelLib.tex_box(self, Vector3(2.4, 0.14, 0.42),
			Vector3(base.x, FLOOR_Y + 0.1 + frac * (H - 0.6), base.z + 0.6 + frac * 2.6),
			"stone_light.png", Color(0.6, 0.6, 0.66), 0.5)
	MeshLib.box(self, Vector3(2.6, 0.1, 2.6), Vector3(base.x, H - 0.05, base.z + 2.4), Color(0.04, 0.03, 0.05))
	var p := Portal.make(self, Vector3(base.x, FLOOR_Y + 0.2, base.z), prompt, "indoor", spawn_id_up)
	portals.append(p)
	spawns[spawn_id_here] = Vector3(base.x, FLOOR_Y + 0.3, base.z - 1.2)
	var glow := OmniLight3D.new()
	glow.position = Vector3(base.x, 1.6, base.z + 1.0)
	glow.light_color = MeshLib.ACCENT
	glow.omni_range = 5.0
	glow.light_energy = 1.0
	add_child(glow)

func _torch(pos: Vector3, rot_y := 0.0) -> void:
	ModelLib.visual(self, "Torch_Metal", pos, rot_y)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 0.35, 0)
	l.light_color = Color(1.0, 0.55, 0.2)
	l.omni_range = 7.0
	l.light_energy = 1.5
	add_child(l)

# ---------------------------------------------------------------- винный погреб

func _cellar_room() -> void:
	# стеллажи с вином вдоль стен
	for i in 3:
		ModelLib.solid(self, "Shelf_Small_Bottles", Vector3(-16.2, FLOOR_Y, -2.0 + i * 3.0), -90)
	ModelLib.solid(self, "Shelf_Arch", Vector3(-13.0, FLOOR_Y, -3.4), 0)
	ModelLib.solid(self, "Shelf_Simple", Vector3(-8.4, FLOOR_Y + 1.2, -3.4), 0)
	# бочки
	for bpos in [Vector3(-15.4, FLOOR_Y, 6.4), Vector3(-14.2, FLOOR_Y, 7.0), Vector3(-12.9, FLOOR_Y, 6.6),
			Vector3(-7.4, FLOOR_Y, -2.6), Vector3(-7.2, FLOOR_Y, 6.8)]:
		ModelLib.solid(self, "Barrel", bpos, randf_range(0, 90))
	ModelLib.solid(self, "Barrel_Holder", Vector3(-11.4, FLOOR_Y, 7.2), 0)
	ModelLib.solid(self, "Crate_Wooden", Vector3(-16.0, FLOOR_Y, 3.6), 15)
	ModelLib.solid(self, "Crate_Metal", Vector3(-16.0, FLOOR_Y, 1.2), -20)
	# ВИНО для завтрака — целый ящик, бери сколько унесёшь (одну)
	for i in 5:
		BreakableProp.make(self, "bottle", Vector3(-12.6 + i * 0.42, FLOOR_Y + 0.25, -1.4))
	BreakableProp.make(self, "bottle", Vector3(-13.4, FLOOR_Y + 0.25, 0.4))
	BreakableProp.make(self, "bottle", Vector3(-9.8, FLOOR_Y + 0.25, -2.8))
	ModelLib.visual(self, "SmallBottles_1", Vector3(-8.4, FLOOR_Y + 1.35, -3.3))
	ModelLib.grab(self, "Mug", Vector3(-10.6, FLOOR_Y + 0.25, 6.2), 0.6)
	ModelLib.grab(self, "Chalice", Vector3(-11.2, FLOOR_Y + 0.25, 6.6), 0.8)
	# табличка
	MeshLib.label(self, "ВИННЫЙ ПОГРЕБ", Vector3(-11.5, 2.5, -3.5), 40, MeshLib.BONE)
	_torch(Vector3(-16.6, 2.0, 5.0), -90)
	_torch(Vector3(-16.6, 2.0, -1.0), -90)
	_torch(Vector3(-11.0, 2.0, -3.9))
	# паутина по углам
	for corner in [Vector3(-16.2, 2.9, -3.2), Vector3(-6.6, 2.9, 7.2)]:
		MeshLib.box(self, Vector3(1.1, 0.02, 1.1), corner, Color(0.7, 0.7, 0.72), Vector3(45, 0, 45))

# ---------------------------------------------------------------- подземелье

func _ritual_room() -> void:
	# ритуальный круг в центре
	_circle(Vector3(11.5, FLOOR_Y + 0.02, 2.0), 2.6)
	ModelLib.solid(self, "Cauldron", Vector3(11.5, FLOOR_Y, -2.2), 0)
	var brew := MeshLib.cylinder(self, 0.42, 0.06, Vector3(11.5, FLOOR_Y + 0.68, -2.2), MeshLib.ACCENT)
	brew.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	# клетки и цепи
	ModelLib.solid(self, "Cage_Small", Vector3(16.0, FLOOR_Y, 6.2), -25)
	ModelLib.solid(self, "Cage_Small", Vector3(15.4, FLOOR_Y, 7.2), 40)
	ModelLib.visual(self, "Chain_Coil", Vector3(14.6, FLOOR_Y, 5.0))
	ModelLib.visual(self, "Rope_2", Vector3(7.4, FLOOR_Y, 6.6))
	# верстак палача, наковальня, инструмент
	ModelLib.solid(self, "Workbench_Drawers", Vector3(9.0, FLOOR_Y, -3.2), 0)
	ModelLib.solid(self, "Anvil_Log", Vector3(14.4, FLOOR_Y, -3.0), -20)
	ModelLib.grab(self, "Pickaxe_Bronze", Vector3(8.4, FLOOR_Y + 0.95, -3.2), 1.5)
	ModelLib.solid(self, "WeaponStand", Vector3(16.2, FLOOR_Y, -1.0), -90)
	ModelLib.solid(self, "Chest_Wood", Vector3(6.9, FLOOR_Y, -2.4), 30)
	# останки предшественников — намёк, что скелетов тут делают серийно
	for i in 6:
		var ang := i * TAU / 6.0 + 0.4
		MeshLib.capsule(self, 0.05, randf_range(0.3, 0.5),
			Vector3(11.5 + cos(ang) * 3.6, FLOOR_Y + 0.06, 2.0 + sin(ang) * 3.6),
			MeshLib.BONE_PROP, Vector3(90, rad_to_deg(ang), 0))
	MeshLib.sphere(self, 0.17, Vector3(8.2, FLOOR_Y + 0.17, 5.4), MeshLib.BONE_PROP)
	MeshLib.sphere(self, 0.17, Vector3(15.8, FLOOR_Y + 0.17, 1.2), MeshLib.BONE_PROP)
	BreakableProp.make(self, "skullpot", Vector3(13.2, FLOOR_Y + 0.2, 6.0))
	MeshLib.label(self, "ПОДЗЕМЕЛЬЕ", Vector3(11.5, 2.5, -3.7), 40, Color(0.9, 0.4, 0.4))
	_torch(Vector3(16.6, 2.0, 5.0), 90)
	_torch(Vector3(16.6, 2.0, -1.0), 90)
	_torch(Vector3(11.5, 2.0, -3.9), 180)
	ModelLib.visual(self, "Banner_1", Vector3(9.6, 2.6, -3.85))

func _circle(center: Vector3, radius: float) -> void:
	var ring := MeshLib.cylinder(self, radius + 0.14, 0.02, center, Color(0.55, 0.06, 0.08))
	ring.material_override = MeshLib.mat(Color(0.55, 0.06, 0.08), 1.0, 0.0, Color(0.4, 0.02, 0.03))
	MeshLib.cylinder(self, radius - 0.06, 0.025, center + Vector3(0, 0.004, 0), Color(0.1, 0.07, 0.09))
	var pts: Array[Vector3] = []
	for i in 5:
		var ang := -PI / 2.0 + i * TAU / 5.0
		pts.append(center + Vector3(cos(ang) * (radius - 0.14), 0.012, sin(ang) * (radius - 0.14)))
	for i in 5:
		var a := pts[i]
		var b := pts[(i + 2) % 5]
		var dir := b - a
		var line := MeshLib.box(self, Vector3(dir.length(), 0.015, 0.09), (a + b) / 2.0, Color(0.75, 0.1, 0.12))
		line.rotation.y = -atan2(dir.z, dir.x)
		line.material_override = MeshLib.mat(Color(0.75, 0.1, 0.12), 1.0, 0.0, Color(0.5, 0.04, 0.05))
	for p in pts:
		ModelLib.solid(self, "CandleStick", Vector3(p.x, FLOOR_Y, p.z) + (p - center).normalized() * 0.4)
	var rl := OmniLight3D.new()
	rl.position = center + Vector3(0, 1.4, 0)
	rl.light_color = Color(0.9, 0.15, 0.1)
	rl.omni_range = 6.0
	rl.light_energy = 1.6
	add_child(rl)

func _corridor() -> void:
	ModelLib.solid(self, "Crate_Wooden", Vector3(-4.6, FLOOR_Y, 2.1), 10)
	ModelLib.solid(self, "Barrel", Vector3(4.6, FLOOR_Y, 4.9), -15)
	ModelLib.grab(self, "Bucket_Metal", Vector3(1.2, FLOOR_Y, 2.0), 2.0)
	ModelLib.visual(self, "Rope_1", Vector3(-2.0, FLOOR_Y, 4.8))
	_torch(Vector3(0, 2.0, 1.9), 180)
	_torch(Vector3(-3.4, 2.0, 5.1))
	_torch(Vector3(3.4, 2.0, 5.1))
	MeshLib.label(self, "◄ погреб      подземелье ►", Vector3(0, 2.6, 3.5), 32, MeshLib.BONE_DARK)
