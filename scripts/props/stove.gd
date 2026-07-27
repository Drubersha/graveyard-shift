class_name Stove extends StaticBody3D
## Плита. Положи на неё яйцо, муку и вино и нажми E — получишь завтрак.
## Завтрак разбил? Плита милосердна: готовит добавку без ингредиентов.

signal cooked

const RECIPE := ["egg", "flour", "bottle"]
const RECIPE_NAMES := {"egg": "яйцо", "flour": "мука", "bottle": "вино"}

var prompt := "Готовить завтрак"
var cooked_once := false
var _breakfast: BreakableProp = null
var _zone: Area3D
var _flame: MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.95, 0.65)
	col.shape = shape
	col.position = Vector3(0, 0.475, 0)
	add_child(col)
	# корпус, конфорки, духовка
	MeshLib.box(self, Vector3(0.9, 0.95, 0.65), Vector3(0, 0.475, 0), MeshLib.METAL.darkened(0.4))
	MeshLib.box(self, Vector3(0.94, 0.05, 0.69), Vector3(0, 0.97, 0), MeshLib.METAL.darkened(0.55))
	for cx in [-0.2, 0.2]:
		for cz in [-0.15, 0.15]:
			MeshLib.cylinder(self, 0.11, 0.02, Vector3(cx, 1.0, cz), Color(0.1, 0.1, 0.1))
	MeshLib.box(self, Vector3(0.6, 0.35, 0.03), Vector3(0, 0.45, -0.33), Color(0.2, 0.16, 0.12))
	MeshLib.box(self, Vector3(0.5, 0.25, 0.02), Vector3(0, 0.45, -0.34), Color(0.9, 0.6, 0.3)) \
		.material_override = MeshLib.mat(Color(0.9, 0.6, 0.3), 1.0, 0.0, Color(0.8, 0.4, 0.1))
	# труба-вытяжка
	MeshLib.box(self, Vector3(0.5, 0.5, 0.4), Vector3(0, 1.6, 0.1), MeshLib.METAL.darkened(0.5))
	# зелёное ведьминское пламя под конфоркой (жутко, но работает)
	_flame = MeshLib.sphere(self, 0.08, Vector3(0, 1.02, 0), MeshLib.ACCENT, 0.5)
	_flame.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	_flame.visible = false
	# зона приёма ингредиентов над плитой
	_zone = Area3D.new()
	_zone.position = Vector3(0, 1.35, 0)
	var zc := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(1.3, 0.85, 1.1)
	zc.shape = zs
	_zone.add_child(zc)
	add_child(_zone)

func get_prompt() -> String:
	if cooked_once and not is_instance_valid(_breakfast):
		return "Приготовить добавку"
	return "Готовить завтрак (нужны: яйцо, мука, вино)"

func interact(_by: Node) -> void:
	# добавка после разбитого завтрака — бесплатно
	if cooked_once and not is_instance_valid(_breakfast):
		_serve_plate()
		Game.hint("Плита милосердна. Не разбей хотя бы эту.")
		return
	var found := {}
	for body in _zone.get_overlapping_bodies():
		var prop := body as BreakableProp
		if prop and prop.kind in RECIPE and not found.has(prop.kind):
			found[prop.kind] = prop
	var missing: Array[String] = []
	for need in RECIPE:
		if not found.has(need):
			missing.append(RECIPE_NAMES[need])
	if not missing.is_empty():
		Game.hint("На плите не хватает: %s. Положи (или брось) сверху." % ", ".join(missing))
		return
	for k in found:
		(found[k] as Node).queue_free()
	_serve_plate()
	cooked_once = true
	cooked.emit()

func _serve_plate() -> void:
	_flame.visible = true
	var tw := create_tween()
	tw.tween_property(_flame, "scale", Vector3(2.5, 2.5, 2.5), 0.25)
	tw.tween_property(_flame, "scale", Vector3.ONE, 0.25)
	tw.tween_callback(func() -> void: _flame.visible = false)
	_breakfast = BreakableProp.make(get_parent(), "breakfast", Vector3.ZERO)
	_breakfast.position = position + Vector3(0, 1.15, 0)
