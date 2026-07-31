class_name MeshLib
## Библиотека процедурных мешей и общая палитра игры.
## Все построители контента (кладбище, дом, пропсы) обязаны брать цвета отсюда,
## чтобы картинка держалась в одном стиле «Бёртон-лоуполи».

# Кость грязно-костяная, серо-зеленоватая — НЕ белая. Ориентир по тону:
# Lethal Company / Content Warning: обесцвеченная холодная палитра, тени почти
# чёрные, силуэт читается в темноте за счёт формы, а не за счёт яркости.
const BONE := Color(0.55, 0.55, 0.47)
const BONE_DARK := Color(0.35, 0.36, 0.30)
const BONE_GRIME := Color(0.19, 0.20, 0.16)   # копоть в швах, глазницы, трещины
## Кости-реквизит: россыпь на кладбище, черепа в подземелье, черепушка-горшок.
## Обычный однослойный материал — эмиссионный пол нужен только игроку, который
## всё время крупным планом; декору хватает чистого альбедо.
const BONE_PROP := Color(0.30, 0.325, 0.255)
# Кость САМОГО скелета — отдельно от BONE, потому что BONE это ещё и свечной
# воск, и циферблат часов: их белить нельзя.
#
# Тон держится ДВУМЯ слагаемыми, и это принципиально:
#   albedo    — то, что красит свет сцены. Намеренно низкий.
#   emission  — постоянный серо-зеленоватый пол, светом НЕ красится.
#
# ЧИСЛА ПОСЧИТАНЫ ЧЕРЕЗ ВЕСЬ КОНВЕЙЕР, а не подобраны на глаз. Важно, что
# Color в albedo_color/emission Godot считает sRGB и сам переводит в линейное,
# а сцена идёт через TONE_MAPPER_FILMIC + contrast 1.12 (см. main.gd).
# Обратным ходом по двум замерам критика получена освещённость на скелете:
#   у свечей на крыльце  L ≈ 12.0 (замер купола 145,126,89);
#   в контровом свете    L ≈ 0.54 (замер лица 18-25).
# Разброс 22×, поэтому чистое альбедо в принципе не может дать одинаковый тон:
# либо охра у свечей, либо чёрная маска против света. Отсюда два слагаемых.
#
# Решено под цель «купол ~103 у свечей вместо 145, лицо ~40 против света
# вместо 21»: линейное альбедо 0.030 (было 0.0732 — вдвое с лишним ниже) и
# линейный эмиссионный пол 0.065. Пол чуть холоднее альбедо по синему —
# он и уводит кость из песочной охры в грязно-серо-зеленоватое при свече.
# Пол намеренно НЕ выше: с 0.100 замер дал купол 137 и полностью плоское
# лицо — кость начинала светиться сама и съедала объёмную светотень.
const BONE_SKEL := Color(0.190, 0.208, 0.159)
const BONE_SKEL_EMIT := Color(0.283, 0.310, 0.280)
# Тёмная кость — это ТЕНЬ В УГЛУБЛЕНИИ, а не второй материал. Разница по
# альбедо была 0.48 и на экране разъезжалась примерно вшестеро: тёмное падало
# почти в чёрное и читалось одеждой. Теперь ОБА слагаемых взяты с одним
# коэффициентом 0.55 по линейной шкале, и на экране остаётся 0.68..0.75 по
# светлоте при любом свете — уступ в кости, а не шов между материалами.
const BONE_SKEL_DARK := Color(0.136, 0.150, 0.112)
const BONE_SKEL_DARK_EMIT := Color(0.209, 0.229, 0.206)
# Копоть в швах и трещинах: тот же ход, коэффициент 0.33.
const BONE_SKEL_GRIME := Color(0.099, 0.110, 0.080)
const BONE_SKEL_GRIME_EMIT := Color(0.158, 0.175, 0.156)
## Настоящий провал: глазницы, носовая щель. Эмиссии нет СОЗНАТЕЛЬНО — только
## так дырка остаётся дыркой, когда всё остальное подсвечено полом. Против
## света это даёт лицо ~40 против глазниц ~2, то есть провал наконец читается.
const BONE_SKEL_VOID := Color(0.012, 0.014, 0.012)
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

## Материал кости скелета. `kind`: "bone" | "dark" | "grime" | "void".
## Единственная точка правды для скелета: ей пользуются и процедурный фолбэк
## bone_parts.gd, и мелочь bone_debris.gd, и правка материалов импортированных
## Skeleton_*_own.gltf. Расходиться им нельзя — иначе после рассыпания обломки
## окажутся другого цвета, чем тело, которое только что развалилось.
static func skel_mat(kind := "bone") -> StandardMaterial3D:
	var alb := BONE_SKEL
	var emi := BONE_SKEL_EMIT
	match kind:
		"dark":
			alb = BONE_SKEL_DARK
			emi = BONE_SKEL_DARK_EMIT
		"grime":
			alb = BONE_SKEL_GRIME
			emi = BONE_SKEL_GRIME_EMIT
		"void":
			alb = BONE_SKEL_VOID
			emi = Color.BLACK
	var m := StandardMaterial3D.new()
	m.albedo_color = alb
	m.roughness = 0.95
	m.metallic = 0.0
	if emi != Color.BLACK:
		m.emission_enabled = true
		m.emission = emi
		m.emission_energy_multiplier = 1.0
	return m

## Имя материала из glTF -> вид для `skel_mat`. Сопоставление ИМЕННО по имени:
## Blender пишет примитив только на использованный материал, поэтому порядок
## поверхностей у шести деталей разный и по индексу попадать нельзя.
static func skel_kind_for(mat_name: String) -> String:
	var n := mat_name.to_lower()
	if n.begins_with("bonedark"):
		return "dark"
	if n.begins_with("grime"):
		return "grime"
	if n.begins_with("void"):
		return "void"
	if n.begins_with("bone"):
		return "bone"
	return ""

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

## Гранёная деталь: кольца профиля Vector3(радиус_X, Y, радиус_Z) соединяются
## плоскими гранями. Нормали считаем сами и разворачиваем наружу, cull выключен —
## так фасетки видны при любой намотке и сглаживания нет вовсе.
## Именно этим строятся кости: CapsuleMesh/SphereMesh шейдятся гладко и стилю
## «жёсткие грани и видимые фасетки» прямо противоречат.
static func faceted(parent: Node, rings: Array, sides: int, pos: Vector3, c: Color,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var loops: Array = []
	for r: Vector3 in rings:
		var loop: Array[Vector3] = []
		for i in sides:
			var a := TAU * (float(i) + 0.5) / float(sides)
			loop.append(Vector3(cos(a) * r.x, r.y, sin(a) * r.z))
		loops.append(loop)
	for li in range(loops.size() - 1):
		var lo: Array = loops[li]
		var hi: Array = loops[li + 1]
		for i in sides:
			var j := (i + 1) % sides
			var out := ((lo[i] as Vector3) + (hi[j] as Vector3)) * 0.5
			out.y = 0.0
			_face(st, lo[i], hi[i], hi[j], out)
			_face(st, lo[i], hi[j], lo[j], out)
	var bottom: Array = loops[0]
	var top: Array = loops[loops.size() - 1]
	var cb := Vector3(0, (rings[0] as Vector3).y, 0)
	var ct := Vector3(0, (rings[rings.size() - 1] as Vector3).y, 0)
	for i in sides:
		var j := (i + 1) % sides
		_face(st, cb, bottom[j], bottom[i], Vector3.DOWN)
		_face(st, ct, top[i], top[j], Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat(c)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

## Одна плоская грань. `outward` — куда должна смотреть нормаль (примерно).
static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if outward.length_squared() > 1e-9 and n.dot(outward.normalized()) < 0.0:
		n = -n
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)

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
