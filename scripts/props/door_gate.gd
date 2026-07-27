class_name DoorGate extends Node3D
## Дверь на петле. Может быть заперта (тогда interact даёт подсказку).
## Открывается кодом (open) или интерактом, когда не заперта.

signal opened

var locked := false
var locked_hint := "Заперто."
var is_open := false
var prompt := "Открыть дверь"

var _panel: StaticBody3D
var _width := 0.9
var _height := 2.0

static func make(parent: Node, pos: Vector3, rot_y: float, width := 0.9, height := 2.0, color := MeshLib.WOOD_DARK) -> DoorGate:
	var d := DoorGate.new()
	d._width = width
	d._height = height
	d.position = pos
	d.rotation_degrees = Vector3(0, rot_y, 0)
	parent.add_child(d)
	d._build(color)
	return d

func _build(color: Color) -> void:
	add_to_group("interactable")
	# петля — в корне узла; полотно смещено на полширины
	_panel = MeshLib.solid_box(self, Vector3(_width, _height, 0.08),
		Vector3(_width * 0.5, _height * 0.5, 0), color)
	# ручка
	MeshLib.sphere(_panel.get_child(1), 0.05, Vector3(_width * 0.38, 0, -0.07), Color(0.8, 0.7, 0.3))

func get_prompt() -> String:
	return locked_hint if locked else prompt

func interact(_by: Node) -> void:
	if locked:
		Game.hint(locked_hint)
		return
	if is_open:
		return
	open()

func open() -> void:
	if is_open:
		return
	is_open = true
	locked = false
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:y", rotation_degrees.y + 105.0, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit()

func unlock() -> void:
	locked = false
