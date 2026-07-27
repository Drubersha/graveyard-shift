class_name ModelLib
## Фабрика внешних моделей (Quaternius, CC0) и текстурных материалов особняка.
## Паки в разном масштабе: хауспак крупнее жизни, мебельный — мельче.

const HOUSE_SCALE := 0.6   # хауспак крупнее жизни
const FURN_SCALE := 1.9    # мебельный пак мельче

const TEX := "res://assets/textures/"

static var _scene_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

# ---------------------------------------------------------------- сцены

## Принимает короткое имя из каталога («Kitchen_Fridge») или полный res://-путь.
static func scene(name_or_path: String) -> PackedScene:
	var path := name_or_path if name_or_path.begins_with("res://") else ItemCatalog.path(name_or_path)
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

## Чистый визуал без коллизии (растения, шторы, светильники, ковры).
static func visual(parent: Node, path: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	var ps := scene(path)
	if ps == null:
		push_warning("ModelLib: нет модели " + path)
		return Node3D.new()
	var node := ps.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees = Vector3(0, rot_y, 0)
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	return node

## Модель со статичной коллизией по AABB (мебель, сантехника, верстаки).
static func solid(parent: Node, path: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = Vector3(0, rot_y, 0)
	parent.add_child(body)
	var vis := visual(body, path, Vector3.ZERO, 0.0, scale)
	# merged_aabb уже включает масштаб визуала — второй раз не умножать
	var aabb := merged_aabb(vis)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size.max(Vector3(0.05, 0.05, 0.05)) * 0.92
	col.shape = shape
	col.position = aabb.position + aabb.size * 0.5
	body.add_child(col)
	return body

## Хватаемая физическая модель (зелья, книги, черепа, вёдра).
## Кладёт в meta("item_label") подпись вида «042_Barrel» для интерфейса.
static func grab(parent: Node, path: String, pos: Vector3, mass := 2.0, rot_y := 0.0, scale := 1.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass
	body.position = pos
	body.rotation_degrees = Vector3(0, rot_y, 0)
	body.add_to_group("grabbable")
	body.set_meta("item_label", ItemCatalog.label(path))
	parent.add_child(body)
	var vis := visual(body, path, Vector3.ZERO, 0.0, scale)
	var aabb := merged_aabb(vis)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size.max(Vector3(0.05, 0.05, 0.05)) * 0.9
	col.shape = shape
	col.position = aabb.position + aabb.size * 0.5
	body.add_child(col)
	return body

static func merged_aabb(node: Node) -> AABB:
	return _merge_aabb(node, Transform3D.IDENTITY)

static func _merge_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = local_xf * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for child in node.get_children():
		var sub := _merge_aabb(child, local_xf)
		if sub.size.length_squared() > 0.0001:
			result = result.merge(sub) if has else sub
			has = true
	return result

# ---------------------------------------------------------------- текстуры

static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(TEX + name)
	return _tex_cache[name]

## PBR-материал из бесшовного набора (basecolor+normal+roughness), трипланарный.
static func pbr_mat(base_name: String, tint := Color.WHITE, uv_scale := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/wood/" + base_name + "_basecolor.png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/wood/" + base_name + "_normal.png")
	m.roughness_texture = load("res://assets/textures/wood/" + base_name + "_roughness.png")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	return m

## Надгробие из Spooky Graveyard: FBX + свой диффуз/нормал вручную.
## Нейминг текстур в паке гуляет (grave_1 vs grave_01, «name normal.png») — подбираем.
static func grave(parent: Node, name: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> StaticBody3D:
	var dir := "res://assets/ext/graveyard/"
	var body := solid(parent, dir + name + ".fbx", pos, rot_y, scale)
	var alt := name.replace("_0", "_")
	var mat := StandardMaterial3D.new()
	var albedo := _first_existing([dir + name + ".png", dir + alt + ".png", dir + name + "a.png"])
	if albedo != "":
		mat.albedo_texture = load(albedo)
	var nrm := _first_existing([dir + name + "_normal.png", dir + name + "_normal1.png",
		dir + alt + "_normal.png", dir + alt + "_normal1.png", dir + name + " normal.png"])
	if nrm != "":
		mat.normal_enabled = true
		mat.normal_texture = load(nrm)
	mat.roughness = 0.95
	_override_all(body, mat)
	return body

static func _first_existing(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(p):
			return p
	return ""

static func _override_all(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_override_all(child, mat)

## Готическое окно-витраж: текстура с альфой, светится изнутри.
static func gothic_window(parent: Node, width: float, height: float, pos: Vector3,
		rot_y := 0.0, tint := Color(1.0, 0.95, 0.9)) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.position = pos
	mi.rotation_degrees = Vector3(0, rot_y, 0)
	var m := StandardMaterial3D.new()
	var t := load("res://assets/textures/gothic/Gothic_Window_001.png")
	m.albedo_texture = t
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission_texture = t
	m.emission = Color(1.0, 0.85, 0.6)
	m.emission_energy_multiplier = 0.9
	mi.material_override = m
	parent.add_child(mi)
	return mi

## Готический орнамент-розетка (Gothic_Flower) — накладка на стену.
static func gothic_ornament(parent: Node, size: float, pos: Vector3, rot_y := 0.0, index := 1) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.position = pos
	mi.rotation_degrees = Vector3(0, rot_y, 0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/gothic/Gothic_Flower_%03d.png" % index)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	mi.material_override = m
	parent.add_child(mi)
	return mi

## Трипланарный текстурный материал: не зависит от UV процедурных боксов.
static func tex_mat(tex_name: String, tint := Color.WHITE, uv_scale := 0.5, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name)
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

## Текстурная коробка без коллизии.
static func tex_box(parent: Node, size: Vector3, pos: Vector3, tex_name: String,
		tint := Color.WHITE, uv_scale := 0.5, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshLib.box(parent, size, pos, Color.WHITE, rot)
	mi.material_override = tex_mat(tex_name, tint, uv_scale)
	return mi

## Текстурная коробка с коллизией — стены, полы, лестницы.
static func tex_solid_box(parent: Node, size: Vector3, pos: Vector3, tex_name: String,
		tint := Color.WHITE, uv_scale := 0.5, rot := Vector3.ZERO) -> StaticBody3D:
	var body := MeshLib.solid_box(parent, size, pos, Color.WHITE, rot)
	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = tex_mat(tex_name, tint, uv_scale)
	return body
