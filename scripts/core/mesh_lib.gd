class_name MeshLib
## Библиотека процедурных мешей и общая палитра игры.
## Все построители контента (кладбище, дом, пропсы) обязаны брать цвета отсюда,
## чтобы картинка держалась в одном стиле «Бёртон-лоуполи».

const BONE := Color(0.91, 0.88, 0.78)
const BONE_DARK := Color(0.72, 0.68, 0.58)
const NIGHT_SKY := Color(0.10, 0.08, 0.17)
const FOG_COLOR := Color(0.16, 0.13, 0.24)
const GRASS := Color(0.15, 0.22, 0.16)
const DIRT := Color(0.23, 0.18, 0.14)
const STONE := Color(0.42, 0.42, 0.48)
const STONE_DARK := Color(0.28, 0.28, 0.34)
const WOOD := Color(0.32, 0.22, 0.14)
const WOOD_DARK := Color(0.20, 0.13, 0.09)
const HOUSE_WALL := Color(0.22, 0.17, 0.28)
const HOUSE_TRIM := Color(0.13, 0.10, 0.18)
const ROOF := Color(0.12, 0.09, 0.16)
const METAL := Color(0.55, 0.57, 0.62)
const WITCH_SKIN := Color(0.85, 0.80, 0.82)
const WITCH_DRESS := Color(0.16, 0.05, 0.20)
const WITCH_HAIR := Color(0.38, 0.10, 0.42)
const ACCENT := Color(0.55, 0.85, 0.45)  # ведьминский зелёный: подсветки, зелья, маркеры
const WINE := Color(0.45, 0.08, 0.16)

static func mat(c: Color, rough := 0.9, metallic := 0.0, emission := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.5
	return m

static func _mesh_node(parent: Node, mesh: Mesh, pos: Vector3, c: Color, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh_node(parent, m, pos, c, rot)

static func sphere(parent: Node, radius: float, pos: Vector3, c: Color, squash := 1.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * squash
	return _mesh_node(parent, m, pos, c, Vector3.ZERO)

static func capsule(parent: Node, radius: float, height: float, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return _mesh_node(parent, m, pos, c, rot)

static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, c: Color, rot := Vector3.ZERO, top_radius := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	return _mesh_node(parent, m, pos, c, rot)

## Конус (для крыш, шляп, ёлок): цилиндр с нулевым верхом.
static func cone(parent: Node, radius: float, height: float, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return cylinder(parent, radius, height, pos, c, rot, 0.0)

## Статичная коробка с коллизией — основной кирпич мира (стены, земля, заборы).
static func solid_box(parent: Node, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c)
	body.add_child(mi)
	parent.add_child(body)
	return body

## Невидимая коллизия (для пандусов/огораживания уровня).
static func solid_invisible(parent: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body

## Небольшая постоянная надпись (указатели ▼/▲). Крупные тексты — через SignPost,
## иначе они закрывают пол-экрана.
static func label(parent: Node, text: String, pos: Vector3, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = color
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 8
	l.pixel_size = 0.0028
	l.render_priority = 4
	parent.add_child(l)
	return l
