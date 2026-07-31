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

## Выключить отсечение спинок у всех материалов ветки: у Meshy-моделей меши
## бывают односторонними, и сзади такая геометрия прозрачна.
static func make_double_sided(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m is BaseMaterial3D:
					var dup := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					dup.cull_mode = BaseMaterial3D.CULL_DISABLED
					mi.set_surface_override_material(i, dup)
	for c in node.get_children():
		make_double_sided(c)

static func merged_aabb(node: Node) -> AABB:
	return _merge_aabb(node, Transform3D.IDENTITY)

## AABB в СОБСТВЕННОЙ системе узла — без его собственного transform.
## merged_aabb отдаёт габарит в системе РОДИТЕЛЯ (учитывает position/rotation узла),
## а для промера самой модели нужен габарит в её осях: у хаус-пака глубина мебели —
## это локальный Z независимо от того, как предмет развернули в комнате.
static func local_aabb(node: Node3D) -> AABB:
	return _merge_aabb(node, node.transform.affine_inverse())

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

# ------------------------------------------------- посадка на мебель по геометрии
##
## ЗАЧЕМ ЭТО ЕСТЬ. solid() ставит модель ПО ORIGIN и AABB НЕ центрирует. Значит
## «посадить на z = 8.55» — это угаданное число: диван Couch_Large1 при HOUSE_SCALE
## занимает локальные z 8.695..9.890 (сырой Z=1.992, origin z=-0.675), и маркер на
## 8.55 стоял на 14 см ВПЕРЕДИ переднего среза — под тазом был виден пол. Подогнать
## одно число можно, но на следующей мебели всё повторится.
##
## Поэтому опора ищется по ФАКТИЧЕСКИМ треугольникам меша, а не по AABB: у AABB
## верх — это спинка дивана, а сесть надо на подушку. Скан идёт в СОБСТВЕННЫХ осях
## модели, поэтому развёрнутая на 90 или 180 мебель считается так же. Все пороги —
## доли промеренного габарита, ни одного сантиметра «на глаз».

## Треугольники всей ветки в СОБСТВЕННОЙ системе node (масштаб визуала учтён,
## собственный transform узла — нет).
static func local_faces(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	_merge_faces(node, node.transform.affine_inverse(), out)
	return out

static func _merge_faces(node: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for v in mi.mesh.get_faces():
			out.push_back(local_xf * v)
	for child in node.get_children():
		_merge_faces(child, local_xf, out)

## Верх геометрии в точке (x, z), но не выше ceil_y. -INF, если там ничего нет.
static func surface_y(tris: PackedVector3Array, x: float, z: float, ceil_y: float) -> float:
	var best := -INF
	var i := 0
	while i + 2 < tris.size():
		var y := _tri_y_at(tris[i], tris[i + 1], tris[i + 2], x, z)
		i += 3
		if y != INF and y <= ceil_y and y > best:
			best = y
	return best

## Высота треугольника над точкой (x, z) по барицентрике в плоскости XZ.
## INF — точка вне треугольника (или треугольник вертикальный, ребром к нам).
static func _tri_y_at(a: Vector3, b: Vector3, c: Vector3, x: float, z: float) -> float:
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 1e-9:
		return INF
	var w1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
	var w2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
	var w3 := 1.0 - w1 - w2
	if w1 < -0.0001 or w2 < -0.0001 or w3 < -0.0001:
		return INF
	return a.y * w1 + b.y * w2 + c.y * w3

## Площадка сиденья в СОБСТВЕННЫХ осях модели.
##
## ОСЬ ГЛУБИНЫ НЕ ЗАДАНА ЗАРАНЕЕ, А НАХОДИТСЯ. Сначала здесь стоял локальный Z —
## конвенция хаус-пака, и на Couch_Large1 всё сходилось. Промер (probe_seat) показал,
## что мебельный пак другой: у SofaDouble габарит модели X=1.400 Z=2.591, то есть
## глубина идёт по X, а по Z — ширина. Скан по Z шёл ПОПЕРЁК дивана, находил длинную
## ровную полосу и возвращал ok=true с посадкой в стену. Молча, без ошибки.
##
## Отличить глубину от ширины даёт СПИНКА: вдоль глубины высокая геометрия стоит
## РОВНО с одной стороны подушки, с другой сидящий спускает ноги. Вдоль ширины по
## обоим концам либо подлокотники, либо ничего. Поэтому пробуем обе горизонтальные
## оси и берём ту, где спинка нашлась.
static func seat_plateau(body: Node3D) -> Dictionary:
	var box := local_aabb(body)
	var out := {"ok": false, "box": box, "axis": 2, "y": box.end.y,
		"lo": box.position.z, "hi": box.end.z, "open_low": true, "backrest": false}
	var tris := local_faces(body)
	if tris.is_empty() or box.size.y <= 0.001:
		return out
	var fallback := {}
	# Z раньше X: при прочих равных остаёмся на конвенции хаус-пака.
	for axis in [2, 0]:
		var r := _scan_seat(tris, box, axis)
		if not bool(r["ok"]):
			continue
		if fallback.is_empty():
			fallback = r
		if bool(r["backrest"]):
			r["box"] = box
			return r
	if not fallback.is_empty():
		# площадка есть, а спинки нет — это стол или табурет, а не сиденье со спинкой
		fallback["box"] = box
		fallback["ok"] = false
		return fallback
	return out

## Скан опоры вдоль одной горизонтальной оси (0 = X, 2 = Z) по центру другой.
static func _scan_seat(tris: PackedVector3Array, box: AABB, axis: int) -> Dictionary:
	var other := 0 if axis == 2 else 2
	var lo_b: float = box.position[axis]
	var hi_b: float = box.end[axis]
	var res := {"ok": false, "axis": axis, "y": box.end.y, "lo": lo_b, "hi": hi_b,
		"open_low": true, "backrest": false}
	if hi_b - lo_b <= 0.001:
		return res
	var mid: float = box.position[other] + box.size[other] * 0.5
	var ceil_y := box.position.y + box.size.y * 0.62   # выше — спинка и подлокотники
	var min_y := box.position.y + box.size.y * 0.14    # ниже — пол, ножки, царга
	var pad := (hi_b - lo_b) * 0.06                    # края среза не сиденье
	var n := 41
	var ts := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for i in n:
		var t := lerpf(lo_b + pad, hi_b - pad, float(i) / float(n - 1))
		var y := surface_y(tris, t if axis == 0 else mid, mid if axis == 0 else t, ceil_y)
		ts.push_back(t)
		ys.push_back(y if y > min_y else -INF)
	# Сиденье — самая ДЛИННАЯ ровная площадка, а не самая низкая и не самая высокая.
	# Промер Couch_Large1 показал, почему обе крайности врут: передний валик дивана
	# (y=0.25) ниже подушки, но сидеть на нём нельзя, а низ спинки (y=0.67) выше.
	# Ровный участок длиной в полметра из всего профиля ровно один — подушка.
	var tol := maxf(box.size.y * 0.05, 0.01)
	var best_from := -1
	var best_len := 0
	for i in n:
		if ys[i] <= -INF:
			continue
		var j := i
		var lo_y: float = ys[i]
		var hi_y: float = ys[i]
		while j < n and ys[j] > -INF:
			var nl := minf(lo_y, ys[j])
			var nh := maxf(hi_y, ys[j])
			if nh - nl > tol:
				break
			lo_y = nl
			hi_y = nh
			j += 1
		if j - i > best_len:
			best_len = j - i
			best_from = i
	if best_len < 3:
		return res
	var sum := 0.0
	for k in range(best_from, best_from + best_len):
		sum += ys[k]
	var seat_y := sum / float(best_len)
	var lo := ts[best_from]
	var hi := ts[best_from + best_len - 1]
	# СПИНКА — вот что отличает глубину от ширины. Ищем её НАД крайними четвертями
	# самой площадки, а не за её краем: у Couch_Large1 спинка нависает над подушкой
	# (высокое стоит на z -0.23..0.01, а площадка начинается с -0.202), и за краем
	# площадки оказывается уже скат спинки высотой 0.876 — проверка «за краем»
	# спинку не находила и роняла ok в false на самом же диване.
	# Порог — доля промеренного габарита, а не сантиметры.
	var gate := seat_y + (box.end.y - seat_y) * 0.35
	var q := maxi(1, best_len / 4)
	var high_lo := false
	var high_hi := false
	for k in q:
		var t_lo: float = ts[best_from + k]
		var t_hi: float = ts[best_from + best_len - 1 - k]
		if surface_y(tris, t_lo if axis == 0 else mid, mid if axis == 0 else t_lo, INF) > gate:
			high_lo = true
		if surface_y(tris, t_hi if axis == 0 else mid, mid if axis == 0 else t_hi, INF) > gate:
			high_hi = true
	res["ok"] = true
	res["y"] = seat_y
	res["lo"] = lo
	res["hi"] = hi
	res["backrest"] = high_lo != high_hi
	# Открыта та сторона, где спинки НЕТ. Если спинку не нашли — по зазору между
	# площадкой и краем габарита: подушка доходит до края там, где сидящий спускает ноги.
	if high_lo != high_hi:
		res["open_low"] = not high_lo
	else:
		res["open_low"] = (lo - lo_b) <= (hi_b - hi)
	return res

## Куда садиться на мебель: точка ВЕРХА ПОДУШКИ и куда смотреть сидящему.
## Всё — в системе РОДИТЕЛЯ body, поэтому результат можно отдавать прямо маркеру.
##
## ГЛУБИНУ ПОСАДКИ ЗАДАЁТ БЕДРО, а не «прижмём к спинке». Прижатый к спинке таз
## выглядит правильно только на бумаге: голень идёт от колена вниз, и если колено
## осталось над подушкой, голень уходит В ПОДУШКУ. На кадре сбоку это видно сразу
## (build/sit_side_A.png первой версии). Поэтому колено ставится на открытый край
## подушки, а таз оказывается там, куда достаёт бедро.
##   pelvis_half — полуглубина таза сидящего (свойство ПЕРСОНАЖА)
##   thigh       — длина бедра, от таза до колена; 0 — прижать таз к спинке
## Оба зажимаются площадкой: таз не свисает с подушки и не влезает в спинку.
##   point       — Vector3, верх подушки под тазом
##   front       — Vector3, тот же уровень на ОТКРЫТОМ крае подушки
##   yaw         — градусы, куда смотреть (от спинки в комнату)
##   front_clear — метры от точки посадки до открытого края подушки
##   ok          — площадка найдена; иначе вернулся центр верха AABB, и это повод
##                 разбираться с моделью, а не подгонять число в комнате
static func seat_spot(body: Node3D, pelvis_half := 0.15, thigh := 0.0,
		margin := 0.03) -> Dictionary:
	var pl := seat_plateau(body)
	var lo: float = pl["lo"]
	var hi: float = pl["hi"]
	var box: AABB = pl["box"]
	var axis: int = pl["axis"]
	var open_low: bool = pl["open_low"]
	var depth := hi - lo
	var near := pelvis_half + margin           # ближе к краю таз начнёт свисать
	var far := depth - pelvis_half - margin    # дальше таз влезет в спинку
	var open_t := lo if open_low else hi
	# Между краем ПЛОЩАДКИ и передней плоскостью самой мебели есть ещё валик: у
	# Couch_Large1 это 0.098 м. Колену надо выйти за плоскость мебели, а не за край
	# площадки, иначе голень идёт сквозь валик — на кадре сбоку это видно.
	var face_t: float = box.position[axis] if open_low else box.end[axis]
	var roll := absf(face_t - open_t)
	var d := depth * 0.5                       # площадка слишком мелкая — по центру
	if far >= near:
		d = clampf(thigh - roll if thigh > 0.0 else far, near, far)
	var t := open_t + (d if open_low else -d)
	# точка строится по НАЙДЕННОЙ оси глубины: поперёк — центр предмета
	var other := 0 if axis == 2 else 2
	var local := Vector3(0, pl["y"], 0)
	local[axis] = t
	local[other] = box.position[other] + box.size[other] * 0.5
	var edge := local
	edge[axis] = open_t
	# Куда смотреть: сидящий смотрит вдоль оси глубины в открытую сторону. У модели
	# «вперёд» — это -Z (конвенция Godot), отсюда развороты ниже.
	# forward(yaw) = (-sin yaw, 0, -cos yaw): 0 смотрит в -Z, 90 в -X, 180 в +Z, 270 в +X
	var face_yaw := 0.0
	if axis == 2:
		face_yaw = 0.0 if open_low else 180.0
	else:
		face_yaw = 90.0 if open_low else 270.0
	var point: Vector3 = body.transform * local
	return {
		"ok": pl["ok"],
		"point": point,
		"front": body.transform * edge,
		"yaw": fposmod(body.rotation_degrees.y + face_yaw, 360.0),
		"front_clear": d,
		"depth": depth,
		"axis": axis,
		"cushion_y": point.y,
	}

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
