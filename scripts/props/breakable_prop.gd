class_name BreakableProp extends RigidBody3D
## Ломаемый предмет. Создаётся кодом: BreakableProp.make(parent, kind, pos).
## От сильного удара разлетается на осколки и добавляет очки срача (Game.add_mess).

signal destroyed  # эмитится при разбитии (для счётчиков миссий)

## Подписи процедурных предметов для интерфейса: ID_Название.
const LABELS := {
	"vase": "201_Vase_Tall", "pot": "202_Clay_Pot", "bottle": "203_Wine_Bottle",
	"plate": "204_Plate_Clean", "chair": "205_Chair_Old", "table": "206_Table_Wooden",
	"shelf": "207_Shelf_Tall", "tv": "208_TV_Ancient", "lamp": "209_Lamp_Floor",
	"skullpot": "210_Skull_Pot", "crate": "211_Crate_Small",
	"plate_dirty": "212_Plate_Dirty", "egg": "213_Egg_Fresh", "flour": "214_Flour_Sack",
	"breakfast": "215_Breakfast_Plate",
}

const KINDS := {
	# kind: [размер визуала, цвет, масса, порог удара (м/с), очки срача]
	"vase":    [Vector3(0.26, 0.4, 0.26), Color(0.5, 0.65, 0.75), 2.0, 2.6, 15],
	"pot":     [Vector3(0.3, 0.26, 0.3), Color(0.55, 0.3, 0.2), 3.0, 2.8, 10],
	"bottle":  [Vector3(0.1, 0.3, 0.1), MeshLib.WINE, 1.0, 2.2, 5],
	"plate":   [Vector3(0.24, 0.04, 0.24), Color(0.85, 0.85, 0.9), 1.0, 2.0, 5],
	"chair":   [Vector3(0.45, 0.85, 0.45), MeshLib.WOOD, 7.0, 4.0, 20],
	"table":   [Vector3(1.3, 0.75, 0.8), MeshLib.WOOD_DARK, 16.0, 4.5, 35],
	"shelf":   [Vector3(0.9, 1.7, 0.3), MeshLib.WOOD_DARK, 20.0, 4.5, 40],
	"tv":      [Vector3(0.7, 0.5, 0.5), Color(0.15, 0.15, 0.17), 12.0, 3.5, 50],
	"lamp":    [Vector3(0.22, 1.4, 0.22), Color(0.6, 0.55, 0.4), 4.0, 3.0, 20],
	"skullpot":[Vector3(0.24, 0.24, 0.24), MeshLib.BONE_DARK, 2.0, 2.6, 15],
	"crate":   [Vector3(0.5, 0.5, 0.5), MeshLib.WOOD, 8.0, 4.2, 15],
	# бытовуха
	"plate_dirty": [Vector3(0.24, 0.05, 0.24), Color(0.62, 0.64, 0.5), 1.0, 2.0, 5],
	"egg":     [Vector3(0.13, 0.17, 0.13), Color(0.95, 0.93, 0.85), 0.4, 1.3, 2],
	"flour":   [Vector3(0.3, 0.42, 0.24), Color(0.85, 0.82, 0.72), 2.5, 3.2, 5],
	"breakfast": [Vector3(0.28, 0.1, 0.28), Color(0.88, 0.86, 0.9), 1.2, 2.4, 5],
}

var kind := "vase"
var mess_value := 10
var break_threshold := 3.0
var broken := false
var carried := false   # в руках — не бьётся, что бы ни задело
var id := -1           # индекс для сохранения прогресса между локациями
var size := Vector3.ONE
var color := Color.WHITE
# скорость прошлого кадра: в body_entered текущая скорость уже погашена решателем,
# поэтому силу удара меряем по ней
var _prev_vel := Vector3.ZERO

static func make(parent: Node, kind_: String, pos: Vector3, rot := Vector3.ZERO) -> BreakableProp:
	var p := BreakableProp.new()
	p.kind = kind_
	p.position = pos
	p.rotation_degrees = rot
	parent.add_child(p)
	return p

func _ready() -> void:
	var cfg: Array = KINDS.get(kind, KINDS["vase"])
	size = cfg[0]
	color = cfg[1]
	mass = cfg[2]
	break_threshold = cfg[3]
	mess_value = cfg[4]
	add_to_group("grabbable")
	set_meta("item_label", LABELS.get(kind, kind))
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	_build_visual()

func _build_visual() -> void:
	match kind:
		"vase":
			MeshLib.cylinder(self, size.x * 0.5, size.y, Vector3.ZERO, color, Vector3.ZERO, size.x * 0.32)
			MeshLib.cylinder(self, size.x * 0.36, 0.08, Vector3(0, size.y * 0.55, 0), color)
		"pot":
			MeshLib.sphere(self, size.x * 0.55, Vector3(0, -0.02, 0), color, 0.85)
			MeshLib.cylinder(self, size.x * 0.34, 0.07, Vector3(0, size.y * 0.42, 0), color.darkened(0.15))
			MeshLib.capsule(self, 0.02, 0.22, Vector3(size.x * 0.52, 0.02, 0), color.darkened(0.2), Vector3(0, 0, 90))
		"bottle":
			MeshLib.cylinder(self, size.x * 0.5, size.y * 0.75, Vector3(0, -size.y * 0.1, 0), color)
			MeshLib.cylinder(self, size.x * 0.2, size.y * 0.35, Vector3(0, size.y * 0.35, 0), color)
		"plate":
			MeshLib.cylinder(self, size.x * 0.5, size.y, Vector3.ZERO, color)
		"chair":
			MeshLib.box(self, Vector3(size.x, 0.06, size.z), Vector3(0, -0.08, 0), color)
			MeshLib.box(self, Vector3(size.x, 0.5, 0.06), Vector3(0, 0.2, -size.z * 0.47), color)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					MeshLib.box(self, Vector3(0.05, 0.35, 0.05), Vector3(sx * size.x * 0.42, -0.28, sz * size.z * 0.42), color)
		"table":
			MeshLib.box(self, Vector3(size.x, 0.07, size.z), Vector3(0, size.y * 0.45, 0), color)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					MeshLib.box(self, Vector3(0.08, size.y, 0.08), Vector3(sx * size.x * 0.44, 0, sz * size.z * 0.4), color)
		"shelf":
			MeshLib.box(self, size, Vector3.ZERO, color)
			for i in 3:
				MeshLib.box(self, Vector3(size.x * 0.86, 0.04, size.z * 0.7), Vector3(0, -size.y * 0.3 + i * size.y * 0.3, size.z * 0.1), MeshLib.WOOD)
		"tv":
			MeshLib.box(self, size, Vector3.ZERO, color)
			MeshLib.box(self, Vector3(size.x * 0.8, size.y * 0.7, 0.02), Vector3(0, 0.02, -size.z * 0.5), Color(0.3, 0.4, 0.5))
		"lamp":
			MeshLib.cylinder(self, 0.16, 0.05, Vector3(0, -size.y * 0.48, 0), color)
			MeshLib.cylinder(self, 0.03, size.y * 0.8, Vector3(0, -0.05, 0), color)
			MeshLib.cone(self, 0.2, 0.25, Vector3(0, size.y * 0.42, 0), Color(0.8, 0.7, 0.5))
		"skullpot":
			MeshLib.sphere(self, size.x * 0.5, Vector3.ZERO, color)
			MeshLib.sphere(self, 0.03, Vector3(-0.05, 0.03, -size.x * 0.42), Color.BLACK)
			MeshLib.sphere(self, 0.03, Vector3(0.05, 0.03, -size.x * 0.42), Color.BLACK)
		"plate_dirty":
			MeshLib.cylinder(self, size.x * 0.5, size.y, Vector3.ZERO, color)
			# засохшие остатки — мелкие тёмные нашлёпки
			MeshLib.cylinder(self, 0.05, 0.02, Vector3(0.05, size.y * 0.6, 0.03), Color(0.35, 0.3, 0.18))
			MeshLib.cylinder(self, 0.035, 0.02, Vector3(-0.06, size.y * 0.6, -0.04), Color(0.3, 0.33, 0.15))
		"egg":
			MeshLib.sphere(self, size.x * 0.5, Vector3.ZERO, color, 1.3)
		"flour":
			# мешок с перевязанной горловиной
			MeshLib.box(self, Vector3(size.x, size.y * 0.75, size.z), Vector3(0, -size.y * 0.1, 0), color)
			MeshLib.cylinder(self, size.x * 0.28, size.y * 0.22, Vector3(0, size.y * 0.38, 0), color.darkened(0.1))
			MeshLib.box(self, Vector3(size.x * 0.66, 0.05, 0.03), Vector3(0, size.y * 0.3, -size.z * 0.4), Color(0.5, 0.3, 0.2))
		"breakfast":
			MeshLib.cylinder(self, size.x * 0.5, 0.04, Vector3.ZERO, Color(0.9, 0.9, 0.95))
			# глазунья и что-то мясное
			MeshLib.cylinder(self, 0.07, 0.02, Vector3(0.05, 0.04, 0.03), Color(0.95, 0.95, 0.9))
			MeshLib.sphere(self, 0.03, Vector3(0.05, 0.05, 0.03), Color(0.95, 0.75, 0.2))
			MeshLib.cylinder(self, 0.055, 0.02, Vector3(-0.07, 0.04, -0.04), Color(0.95, 0.95, 0.9))
			MeshLib.sphere(self, 0.026, Vector3(-0.07, 0.05, -0.04), Color(0.95, 0.75, 0.2))
			MeshLib.box(self, Vector3(0.1, 0.025, 0.05), Vector3(0, 0.04, 0.09), Color(0.6, 0.3, 0.25))
		_:
			MeshLib.box(self, size, Vector3.ZERO, color)

func _physics_process(_delta: float) -> void:
	_prev_vel = linear_velocity

func _on_body_entered(body: Node) -> void:
	if broken or carried:
		return
	var other_vel := Vector3.ZERO
	if body is RigidBody3D:
		other_vel = (body as RigidBody3D).linear_velocity
	elif body is CharacterBody3D:
		other_vel = (body as CharacterBody3D).velocity
	var impact := maxf((linear_velocity - other_vel).length(), (_prev_vel - other_vel).length())
	if impact >= break_threshold:
		shatter_prop()

## Отмыть грязную тарелку: перестраиваем визуал под чистую.
func wash() -> void:
	if kind != "plate_dirty" or broken:
		return
	kind = "plate"
	color = KINDS["plate"][1]
	set_meta("item_label", LABELS["plate"])
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	_build_visual()

func shatter_prop() -> void:
	if broken:
		return
	broken = true
	Game.add_mess(mess_value)
	destroyed.emit()
	# осколки
	var n := clampi(int(size.length() * 6.0), 4, 9)
	for i in n:
		var piece := RigidBody3D.new()
		piece.mass = maxf(mass / n, 0.3)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var s := size * randf_range(0.15, 0.3)
		shape.size = s
		col.shape = shape
		piece.add_child(col)
		MeshLib.box(piece, s, Vector3.ZERO, color.darkened(randf_range(0.0, 0.25)))
		get_parent().add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0, 0.3), randf_range(-0.2, 0.2))
		piece.linear_velocity = linear_velocity + Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3))
		piece.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		# через 8 с осколок замерзает: срач остаётся лежать, физика больше не тратится
		get_tree().create_timer(8.0).timeout.connect(func() -> void:
			if is_instance_valid(piece):
				piece.freeze = true)
	queue_free()
