class_name DoorGate extends Node3D
## Дверь на петле. Может быть заперта (тогда interact даёт подсказку).
## Открывается кодом (open) или интерактом; открытую interact закрывает обратно.
## swing со знаком: в какую сторону распахивается створка (+105 / -105).

signal opened

var locked := false
var locked_hint := "Заперто."
var is_open := false
var prompt := "Открыть дверь"
var swing := 105.0
# Дверь-портал: не распахивается, а передаёт интеракт порталу (смена локации).
# Ставится в проёмы наружу — иначе в проёме видно небо сквозь дырку в стене.
var portal_link: Portal = null

var _panel: StaticBody3D
var _width := 0.9
var _height := 2.0
var _closed_yaw := 0.0
var _overscan := 1.0
var model_path := ""   # модель двери из хауспака вместо процедурной панели
var model_raw := Vector3.ZERO   # сырой AABB glb-модели (Meshy): включает ветку make_glb

static func make(parent: Node, pos: Vector3, rot_y: float, width := 0.9, height := 2.0, color := MeshLib.WOOD_DARK) -> DoorGate:
	var d := DoorGate.new()
	d._width = width
	d._height = height
	d.position = pos
	d.rotation_degrees = Vector3(0, rot_y, 0)
	parent.add_child(d)
	d._build(color)
	return d

## Дверь с моделью Door_* из хауспака (натуральный размер 1.74/3.48 x 4.19).
static func make_model(parent: Node, pos: Vector3, rot_y: float, width: float, height: float, path: String) -> DoorGate:
	var d := DoorGate.new()
	d._width = width
	d._height = height
	d.model_path = path
	d.position = pos
	d.rotation_degrees = Vector3(0, rot_y, 0)
	parent.add_child(d)
	d._build(MeshLib.WOOD_DARK)
	return d

## Дверь из glb-модели с центральным origin (Meshy): raw — промеренный AABB.
## Створка растягивается на весь проём width x height, петля — в origin узла.
## overscan > 1 растягивает полотно с запасом и центрирует его в проёме: AABB
## модели включает шипы навершия и ручку, из-за чего само полотно уже проёма —
## у наружных дверей в щели по периметру сквозило небо.
static func make_glb(parent: Node, pos: Vector3, rot_y: float, width: float, height: float,
		path: String, raw: Vector3, swing_deg := 105.0, overscan := 1.0) -> DoorGate:
	var d := DoorGate.new()
	d._width = width
	d._height = height
	d.model_path = path
	d.model_raw = raw
	d.swing = swing_deg
	d._overscan = overscan
	d.position = pos
	d.rotation_degrees = Vector3(0, rot_y, 0)
	parent.add_child(d)
	d._build(MeshLib.WOOD_DARK)
	return d

func _build(color: Color) -> void:
	add_to_group("interactable")
	_closed_yaw = rotation_degrees.y
	if model_path == "":
		# петля — в корне узла; полотно смещено на полширины
		_panel = MeshLib.solid_box(self, Vector3(_width, _height, 0.08),
			Vector3(_width * 0.5, _height * 0.5, 0), color)
		# ручка
		MeshLib.sphere(_panel.get_child(1), 0.05, Vector3(_width * 0.38, 0, -0.07), Color(0.8, 0.7, 0.3))
	else:
		# невидимая панель-коллизия + модель, растянутая под проём
		_panel = StaticBody3D.new()
		add_child(_panel)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(_width, _height, 0.12)
		col.shape = shape
		col.position = Vector3(_width * 0.5, _height * 0.5, 0)
		_panel.add_child(col)
		# модель ставим и ПОТОМ прижимаем её AABB к петле: у дверей хауспака
		# пивот в разных местах, иначе полотно улетает мимо проёма
		var vis: Node3D
		if model_raw != Vector3.ZERO:
			vis = ModelLib.visual(_panel, model_path, Vector3.ZERO, 0.0)
			var sy := _height * _overscan / model_raw.y
			vis.scale = Vector3(_width * _overscan / model_raw.x, sy, sy)
			# у Meshy-дверей геометрия односторонняя: без выключенного кулинга
			# полотно прозрачно со спины и сквозь проём видно соседнюю комнату
			ModelLib.make_double_sided(vis)
		else:
			var nat_w := 3.48 if model_path.contains("Double") else 1.74
			vis = ModelLib.visual(_panel, model_path, Vector3.ZERO, 180.0)
			vis.scale = Vector3(_width / nat_w, _height / 4.19, 0.7)
		var box := ModelLib.merged_aabb(vis)
		vis.position -= Vector3(box.position.x, box.position.y, box.position.z + box.size.z / 2.0)
		# запас растяжки поровну на обе стороны проёма; по высоте — весь вверх
		vis.position.x -= _width * (_overscan - 1.0) * 0.5

func get_prompt() -> String:
	if portal_link:
		return portal_link.prompt
	if locked:
		return locked_hint
	return "Закрыть дверь" if is_open else prompt

func interact(by: Node) -> void:
	if portal_link:
		portal_link.interact(by)
		return
	if locked:
		Game.hint(locked_hint)
		return
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	locked = false
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:y", _closed_yaw + swing, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:y", _closed_yaw, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func unlock() -> void:
	locked = false
