class_name SinkCounter extends StaticBody3D
## Кухонная мойка. Грязная тарелка, попавшая в раковину, отмывается сама
## (вода волшебная, как и всё в этом доме).

signal washed

var model_path := ""   # модель мойки из хауспака вместо процедурной тумбы

func _ready() -> void:
	var zone_y := 1.05
	if model_path == "":
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.1, 0.9, 0.6)
		col.shape = shape
		col.position = Vector3(0, 0.45, 0)
		add_child(col)
		MeshLib.box(self, Vector3(1.1, 0.9, 0.6), Vector3(0, 0.45, 0), MeshLib.WOOD_DARK)
		MeshLib.box(self, Vector3(1.14, 0.06, 0.64), Vector3(0, 0.93, 0), MeshLib.METAL)
		MeshLib.box(self, Vector3(0.7, 0.3, 0.44), Vector3(0, 0.83, 0), MeshLib.METAL.darkened(0.25))
		MeshLib.box(self, Vector3(0.6, 0.26, 0.36), Vector3(0, 0.86, 0), Color(0.3, 0.4, 0.5))
		MeshLib.cylinder(self, 0.03, 0.35, Vector3(0, 1.1, -0.22), MeshLib.METAL)
		MeshLib.cylinder(self, 0.025, 0.25, Vector3(0, 1.26, -0.12), MeshLib.METAL, Vector3(90, 0, 0))
	else:
		var vis := ModelLib.visual(self, model_path, Vector3.ZERO, 180.0, ModelLib.HOUSE_SCALE)
		var aabb := ModelLib.merged_aabb(vis)  # масштаб уже внутри
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = aabb.size.max(Vector3(0.3, 0.3, 0.3)) * 0.95
		col.shape = shape
		col.position = aabb.position + aabb.size * 0.5
		add_child(col)
		zone_y = aabb.size.y * 0.8
	# зона мойки над чашей
	var zone := Area3D.new()
	zone.position = Vector3(0, zone_y, 0)
	var zc := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(0.8, 0.7, 0.6)
	zc.shape = zs
	zone.add_child(zc)
	add_child(zone)
	zone.body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	var prop := body as BreakableProp
	if prop and prop.kind == "plate_dirty":
		prop.wash()
		# всплеск чистоты
		var sparkle := MeshLib.sphere(self, 0.12, Vector3(0, 1.2, 0), MeshLib.ACCENT)
		sparkle.material_override = MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
		var tw := create_tween()
		tw.tween_property(sparkle, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		tw.tween_callback(sparkle.queue_free)
		washed.emit()
