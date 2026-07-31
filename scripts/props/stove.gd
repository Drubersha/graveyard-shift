class_name Stove extends StaticBody3D
## Плита. Положи на неё яйцо, муку и вино и нажми E — получишь завтрак.
## Завтрак разбил? Плита милосердна: готовит добавку без ингредиентов.

signal cooked

const RECIPE := ["egg", "flour", "bottle"]
const RECIPE_NAMES := {"egg": "яйцо", "flour": "мука", "bottle": "вино"}

var prompt := "Готовить завтрак"
var cooked_once := false
var model_path := ""   # модель плиты из хауспака вместо процедурного корпуса
var model_scale := ModelLib.HOUSE_SCALE
var model_rot := 180.0
var top_y := 1.0       # высота варочной поверхности (для спавна завтрака)
var top_y_override := NAN   # локальная высота варочной, если у модели AABB выше неё (вытяжка)
var _breakfast: BreakableProp = null
var _zone: Area3D
var _flame: MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")
	if model_path == "":
		_build_procedural()
	else:
		var vis := ModelLib.visual(self, model_path, Vector3.ZERO, model_rot, model_scale)
		var aabb := ModelLib.merged_aabb(vis)  # масштаб уже внутри
		top_y = top_y_override if not is_nan(top_y_override) \
			else aabb.position.y + aabb.size.y * 0.98
		# Коллизия — только до варочной поверхности: если у модели сзади вытяжка,
		# полный AABB задирает крышу box-коллизии выше стола, и положенные на плиту
		# ингредиенты оказываются ВНУТРИ коллизии — физика их выкидывает.
		var col_h := maxf(top_y - aabb.position.y, 0.3)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(aabb.size.x * 0.95, 0.3), col_h, maxf(aabb.size.z * 0.95, 0.3))
		col.shape = shape
		col.position = Vector3(aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y + col_h * 0.5, aabb.position.z + aabb.size.z * 0.5)
		add_child(col)
	# зелёное ведьминское пламя над конфоркой (жутко, но работает)
	_flame = MeshLib.sphere(self, 0.08, Vector3(0, top_y + 0.04, 0), MeshLib.ACCENT, 0.5)
	_flame.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	_flame.visible = false
	# зона приёма ингредиентов над плитой
	_zone = Area3D.new()
	_zone.position = Vector3(0, top_y + 0.38, 0)
	var zc := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(1.3, 0.85, 1.1)
	zc.shape = zs
	_zone.add_child(zc)
	add_child(_zone)

func _build_procedural() -> void:
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
	MeshLib.box(self, Vector3(0.5, 0.5, 0.4), Vector3(0, 1.6, 0.1), MeshLib.METAL.darkened(0.5))
	top_y = 1.0

func get_prompt() -> String:
	if cooked_once and not is_instance_valid(_breakfast):
		return "Приготовить добавку"
	var have := Game.stove_have()
	if have.is_empty():
		return "Готовить завтрак (нужны: яйцо, мука, вино)"
	return "Плита: %s ✓ — не хватает: %s" % [_names(have), _names(_missing())]

func _names(keys: Array) -> String:
	var out: Array[String] = []
	for k in keys:
		out.append(RECIPE_NAMES[k])
	return ", ".join(out) if not out.is_empty() else "ничего"

func _missing() -> Array:
	var have := Game.stove_have()
	return RECIPE.filter(func(k: String) -> bool: return not have.has(k))

## Ингредиенты принимаются по одному и запоминаются: можно сходить за вином
## в погреб и вернуться — принятое не пропадёт.
func interact(by: Node) -> void:
	if cooked_once and not is_instance_valid(_breakfast):
		_serve_plate()
		Game.hint("Плита милосердна. Не разбей хотя бы эту.")
		return
	var candidates: Array[BreakableProp] = []
	for body in _zone.get_overlapping_bodies():
		var prop := body as BreakableProp
		if prop:
			candidates.append(prop)
	var skel := by as SkeletonPlayer
	if skel and is_instance_valid(skel.held) and skel.held is BreakableProp:
		candidates.append(skel.held as BreakableProp)
	var taken: Array[String] = []
	for prop in candidates:
		if prop.kind in RECIPE and not Game.stove_have().has(prop.kind):
			Game.stove_add(prop.kind)
			taken.append(RECIPE_NAMES[prop.kind])
			if skel and skel.held == prop:
				skel.held = null
			prop.queue_free()
	if not taken.is_empty():
		_flash()
	var missing := _missing()
	if not missing.is_empty():
		if taken.is_empty():
			Game.hint("Плита ждёт: %s. Держи ингредиент в руках или положи сверху и жми E." % _names(missing))
		else:
			Game.hint("Принято: %s. Осталось: %s." % [", ".join(taken), _names(missing)])
		return
	_serve_plate()
	cooked_once = true
	Game.stove_reset()
	cooked.emit()

func _flash() -> void:
	_flame.visible = true
	var tw := create_tween()
	tw.tween_property(_flame, "scale", Vector3(2.0, 2.0, 2.0), 0.2)
	tw.tween_property(_flame, "scale", Vector3.ONE, 0.2)
	tw.tween_callback(func() -> void: _flame.visible = false)

func _serve_plate() -> void:
	_flash()
	_breakfast = BreakableProp.make(get_parent(), "breakfast", Vector3.ZERO)
	_breakfast.position = position + Vector3(0, top_y + 0.15, 0)
