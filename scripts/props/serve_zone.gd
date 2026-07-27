class_name ServeZone extends Area3D
## Зона подачи у дивана: принеси сюда завтрак — хозяйка примет.

signal served

var active := false

static func make(parent: Node, pos: Vector3) -> ServeZone:
	var z := ServeZone.new()
	z.position = pos
	parent.add_child(z)
	return z

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.6, 1.6)
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)
	add_child(col)
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if not active:
		return
	var prop := body as BreakableProp
	if prop and prop.kind == "breakfast" and not prop.broken:
		active = false
		prop.queue_free()
		served.emit()
