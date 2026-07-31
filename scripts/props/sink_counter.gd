class_name SinkCounter extends StaticBody3D
## Кухонная мойка. Подойди с грязной тарелкой и нажми E — откроется мини-игра
## мытья: тарелка крупным планом, костлявая рука с губкой, пятна оттираются.

signal washed

var prompt := "Помыть тарелку"
var model_path := ""   # модель мойки из хауспака вместо процедурной тумбы
var model_scale := ModelLib.HOUSE_SCALE
var model_rot := 180.0
var zone_y_override := NAN   # локальная высота чаши, если AABB модели выше неё (кран)
var _minigame: DishMinigame = null

func _ready() -> void:
	add_to_group("interactable")
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
		var vis := ModelLib.visual(self, model_path, Vector3.ZERO, model_rot, model_scale)
		var aabb := ModelLib.merged_aabb(vis)  # масштаб уже внутри
		zone_y = zone_y_override if not is_nan(zone_y_override) \
			else aabb.position.y + aabb.size.y * 0.8
		# Коллизия — только до кромки чаши: полный AABB включает кран, и брошенная
		# в мойку тарелка ложилась бы на невидимую крышку выше чаши.
		var col_h := maxf(zone_y - aabb.position.y, 0.3)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(aabb.size.x * 0.95, 0.3), col_h, maxf(aabb.size.z * 0.95, 0.3))
		col.shape = shape
		col.position = Vector3(aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y + col_h * 0.5, aabb.position.z + aabb.size.z * 0.5)
		add_child(col)
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

func get_prompt() -> String:
	return prompt

func interact(by: Node) -> void:
	if is_instance_valid(_minigame):
		return
	var skel := by as SkeletonPlayer
	var plate: BreakableProp = null
	if skel and is_instance_valid(skel.held):
		plate = skel.held as BreakableProp
	if plate == null or plate.kind != "plate_dirty":
		Game.hint("Возьми грязную тарелку (ЛКМ) и подойди к раковине.")
		return
	_minigame = DishMinigame.start(get_tree().current_scene, plate)
	_minigame.finished.connect(func(ok: bool) -> void:
		_minigame = null
		if ok:
			washed.emit()
			Game.hint("Чистая. Можно вернуть в обеденный зал — короткий клик ЛКМ кладёт аккуратно."))

## Просто бросить тарелку в мойку недостаточно — мыть надо руками (мини-игра).
func _on_body(body: Node) -> void:
	var prop := body as BreakableProp
	if prop and prop.kind == "plate_dirty" and not is_instance_valid(_minigame):
		Game.hint("Тарелка в мойке, но сама себя не отмоет. Возьми её (ЛКМ) и нажми E.")
