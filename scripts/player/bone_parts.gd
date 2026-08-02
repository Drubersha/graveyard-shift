class_name BoneParts
## Скелет собран из ОТДЕЛЬНЫХ деталей: череп, торс, две руки, две ноги.
## Каждая деталь — своя модель и свой узел, поэтому её можно оторвать по одной.
##
## Источник геометрии — экспортированная из Blender модель `Skeleton_*_own.gltf`.
## Пока файла нет, деталь собирается процедурно ровно в тех же габаритах:
## гранёные призмы (MeshLib.faceted) и коробки, без единой гладкой нормали.
## Числа здесь — зеркало `scripts/tools/blender_skeleton.py`; правишь там — правь и
## тут, иначе фолбэк начнёт отличаться от модели. Скрипт лежит в отслеживаемой
## папке (не в build/, который в .gitignore) — иначе `git clean` уносил бы
## единственный источник геометрии.
##
## КОНВЕНЦИЯ ОРИГИНА (сознательно отличается от предметной из скила lowpoly-assets):
## у детали тела origin стоит в СУСТАВЕ, а не в основании, иначе поворот пивота
## при ходьбе будет вращать конечность вокруг ступни.
##   skull  — origin в центре черепной коробки (череп ещё и катается отдельно);
##   torso  — origin в основании таза, низ по Y = 0 (совпадает с предметной);
##   arm_*  — origin в плече, деталь уходит вниз до Y = -0.77;
##   leg_*  — origin в бедре, деталь уходит вниз до Y = -0.82.
##
## ГДЕ СТОИТ ТЁМНЫЙ МАТЕРИАЛ — правило, а не вкус.
## Тёмная кость ставится ТОЛЬКО в утопленные места: перетяжки шеек плеча и
## бедра, борозда запястья, линия костяшек, складка голеностопа, стык плюсны
## и пальцев, задние отрезки рёбер, лопатки, остистые отростки. Всё, что
## торчит на силуэте и ловит свет — головки суставов, локоть, надколенник,
## запястье, кисть, пятка, таз, скулы, тело челюсти — светлое.
## Раньше правило было обратное, и тёмное село ровно туда, где у человека
## одежда: плечи читались майкой, таз — шортами с поясом, кисти — перчатками,
## голеностоп и стопа — ботинками. Не повторять.

const IDS: Array[String] = ["skull", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
const MODEL_DIR := "res://assets/models/"
const MODEL := {
	"skull": "Skeleton_Skull_own.gltf",
	"torso": "Skeleton_Torso_own.gltf",
	"arm_l": "Skeleton_ArmL_own.gltf",
	"arm_r": "Skeleton_ArmR_own.gltf",
	"leg_l": "Skeleton_LegL_own.gltf",
	"leg_r": "Skeleton_LegR_own.gltf",
}

# Модели Meshy из папки «Скелет» (промер probe_model.gd 2026-07-31): origin в
# ЦЕНТРЕ AABB, высота нормирована к ~1.9, фронт +Z (у тела фронт -Z → разворот
# на 180). Текстуры свои — reskin к ним НЕ применяется. Нога левая — в штанине,
# правая — голая кость: гардероб подъедала моль, вопросы к ведьме.
# Записи: [путь, size_y, min_y сырого AABB, целевая высота, якорь, rot_x].
# Якорь: "center" — origin детали в центре модели (череп);
# "bottom" — низ модели на origin (торс: origin в основании таза);
# "top" — верх модели на origin (рука/нога: origin в суставе сверху).
# rot_x — опциональный доворот вокруг X. У черепа он НЕ нужен: лицо модели
# смотрит в +Z (как у всей Meshy-мебели), яw 180 разворачивает его вперёд тела.
# Проверено перебором: rot_x=+90 давал «глаз» затылочного отверстия назад,
# rot_x=-90 — лицо в небо; широкий плоский свод — просто пропорции модели.
const MESHY := {
	"skull": ["res://assets/models/147_Bones_Skull.glb", 1.541, -0.768, 0.34, "center"],
	"torso": ["res://assets/models/148_Bones_Torso.glb", 1.877, -0.950, 0.78, "bottom"],
	"arm_l": ["res://assets/models/149_Bones_ArmL.glb", 1.895, -0.949, 0.77, "top"],
	"arm_r": ["res://assets/models/150_Bones_ArmR.glb", 1.897, -0.950, 0.77, "top"],
	"leg_l": ["res://assets/models/151_Bones_LegTrousers.glb", 1.888, -0.945, 0.82, "top"],
	"leg_r": ["res://assets/models/152_Bones_LegBare.glb", 1.897, -0.950, 0.82, "top"],
}

const LABEL := {
	"skull": "череп",
	"torso": "торс",
	"arm_l": "левая рука",
	"arm_r": "правая рука",
	"leg_l": "левая нога",
	"leg_r": "правая нога",
}

## Точка крепления детали в системе координат тела (Y=0 — пол под скелетом,
## визуал целиком поднят на SkeletonPlayer.VISUAL_LIFT над началом капсулы).
const MOUNT := {
	"skull": Vector3(0, 1.62, 0),
	"torso": Vector3(0, 0.78, 0),
	"arm_l": Vector3(-0.235, 1.44, 0),
	"arm_r": Vector3(0.235, 1.44, 0),
	"leg_l": Vector3(-0.115, 0.84, 0),
	"leg_r": Vector3(0.115, 0.84, 0),
}

## Собрать деталь под `parent`. Возвращает корень детали (origin — в суставе).
## Приоритет: модель Meshy игрока → старая _own.gltf → процедурный фолбэк.
## Meshy выше _own сознательно: _own — бленд-копия процедурного скелета,
## а набор Meshy — присланная замена всего облика.
static func build(parent: Node, id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Part_" + id
	parent.add_child(root)
	if MESHY.has(id) and ResourceLoader.exists(MESHY[id][0]):
		var m: Array = MESHY[id]
		var inst := (load(m[0]) as PackedScene).instantiate() as Node3D
		root.add_child(inst)
		var sc: float = m[3] / float(m[1])
		inst.scale = Vector3.ONE * sc
		inst.rotation_degrees = Vector3(m[5] if m.size() > 5 else 0.0, 180.0, 0.0)
		var min_y: float = m[2]
		match m[4]:
			"bottom":
				inst.position.y = -min_y * sc
			"top":
				inst.position.y = -(min_y + float(m[1])) * sc
			"center":
				inst.position.y = -(min_y + float(m[1]) * 0.5) * sc
		# спины у Meshy-мешей бывают односторонними, а детали видны со всех сторон
		ModelLib.make_double_sided(inst)
		return root
	var path := MODEL_DIR + str(MODEL.get(id, ""))
	if ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps:
			var inst := ps.instantiate()
			root.add_child(inst)
			reskin(inst)
			return root
	match id:
		"skull": _skull(root)
		"torso": _torso(root)
		"arm_l": _arm(root, -1)
		"arm_r": _arm(root, 1)
		"leg_l": _leg(root, -1)
		"leg_r": _leg(root, 1)
	return root

## Перекрыть материалы импортированной модели палитрой из MeshLib.
## Зачем, если цвета уже в .gltf: палитра кости — единственная точка правды,
## и она обязана совпадать у модели, у процедурного фолбэка и у обломков
## BoneDebris. Пока это зависело от того, доехал ли emissiveFactor через
## экспортёр и импортёр, расхождение было бы молчаливым.
##
## Сопоставление ИМЕННО ПО ИМЕНИ материала, а не по индексу поверхности:
## Blender пишет примитив только на использованный материал, поэтому порядок
## поверхностей у шести деталей разный.
static func reskin(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var kind := MeshLib.skel_kind_for(src.resource_name if src else "")
			if kind != "":
				mi.set_surface_override_material(i, MeshLib.skel_mat(kind))
	for c in node.get_children():
		reskin(c)

# ---------------------------------------------------------------- череп

## Origin — центр черепной коробки. Вперёд у скелета -Z.
## Лицо собрано РАМОЙ вокруг тёмной плиты: булевых операций нет, и единственный
## способ получить утопленную глазницу — обстроить провал костью спереди.
static func _skull(p: Node) -> void:
	# Черепная коробка: 8 граней вместо 7. Семигранник симметричен только
	# перёд/зад — слева выходило ребро, справа грань. Кольца шире на 7% по X
	# и 6% по Z: при 8 гранях габарит от этого не вырос (cos22.5 = 0.924),
	# зато рамка лица теперь помещается ВНУТРЬ силуэта коробки. Раньше задний
	# угол виска торчал за купол на 0.009 — на макро это был уступ.
	_skel(MeshLib.faceted(p, [
		Vector3(0.091, -0.100, 0.095),
		Vector3(0.145, -0.055, 0.159),
		Vector3(0.163, 0.010, 0.178),
		Vector3(0.148, 0.070, 0.159),
		Vector3(0.084, 0.115, 0.087),
	], 8, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# Глазница делается ТРЕМЯ ступенями по светлоте, а не одной. Одна ступень
	# (светлая рама + сразу чёрная плита) на замере дала лицо ровным полем
	# 129-133 с двумя чёрными прямоугольниками — «солнечные очки на яйце».
	# Ступень 1 — тёмная плита на дне обеих глазниц. Перед -0.171, на 0.0065
	# впереди самой выпуклой точки купола (-0.1645); рама выходит на -0.185.
	_skel(MeshLib.box(p, Vector3(0.150, 0.072, 0.034), Vector3(0, 0.006, -0.154),
		MeshLib.BONE_SKEL_DARK), "dark")
	# Ступень 2 — сам провал, меньше окна, поэтому вокруг остаётся тёмное
	# кольцо 0.0075..0.013. Стоит на 0.004 ВПЕРЕДИ плиты: булевых дырок нет,
	# и «дальше = темнее» приходится делать порядком, а не глубиной.
	for s in [-1.0, 1.0]:
		_void(MeshLib.box(p, Vector3(0.026, 0.034, 0.040), Vector3(s * 0.0375, 0.005, -0.155),
			MeshLib.BONE_SKEL_VOID))
	# надбровная полка — козырёк над глазницами, шире прежней (0.168 против
	# 0.152), чтобы накрывать верх височных блоков и не давать им ступеньку
	_skel(MeshLib.box(p, Vector3(0.168, 0.034, 0.060), Vector3(0, 0.052, -0.156),
		MeshLib.BONE_SKEL, Vector3(-9, 0, 0)), "bone")
	# переносица между глазницами
	_skel(MeshLib.box(p, Vector3(0.034, 0.072, 0.070), Vector3(0, 0.006, -0.153),
		MeshLib.BONE_SKEL), "bone")
	# виски — внешние стойки рамы. Поворот +8° сводит их вперёд, задний угол
	# уходит под купол (0.094 против 0.102 у купола на той же глубине).
	for s in [-1.0, 1.0]:
		_skel(MeshLib.box(p, Vector3(0.028, 0.078, 0.070), Vector3(s * 0.076, 0.004, -0.150),
			MeshLib.BONE_SKEL, Vector3(0, s * 8.0, 0)), "bone")
	# скулы: нижняя перекладина рамы, разорванная посередине под нос.
	# СВЕТЛЫЕ — это выступ. Тёмными они добивали лицо в чёрную маску против света.
	for s in [-1.0, 1.0]:
		_skel(MeshLib.box(p, Vector3(0.058, 0.042, 0.066), Vector3(s * 0.048, -0.045, -0.152),
			MeshLib.BONE_SKEL, Vector3(0, s * 10.0, 0)), "bone")
	# носовая щель — та же воронка из двух ступеней
	_skel(MeshLib.box(p, Vector3(0.046, 0.058, 0.030), Vector3(0, -0.048, -0.156),
		MeshLib.BONE_SKEL_DARK), "dark")
	_void(MeshLib.box(p, Vector3(0.022, 0.034, 0.036), Vector3(0, -0.050, -0.157),
		MeshLib.BONE_SKEL_VOID))
	# борозда под скулами, над верхней челюстью: линия, по которой лицо
	# перестаёт быть одной плоской пластиной
	_skel(MeshLib.box(p, Vector3(0.104, 0.014, 0.034), Vector3(0, -0.069, -0.155),
		MeshLib.BONE_SKEL_DARK), "dark")
	# верхняя челюсть с зубами (опущена на 0.004: иначе борозда под скулой
	# выходила шириной 0.003 и на экране её просто не было)
	_skel(MeshLib.box(p, Vector3(0.128, 0.026, 0.115), Vector3(0, -0.086, -0.120),
		MeshLib.BONE_SKEL), "bone")
	for i in 5:
		_skel(MeshLib.box(p, Vector3(0.018, 0.026, 0.022),
			Vector3(-0.048 + i * 0.024, -0.104, -0.166), MeshLib.BONE_SKEL), "bone")
	# ветви нижней челюсти: без них челюсть висела бруском, а зубы читались
	# «расчёской в воздухе». Тёмные законно — ветвь уходит ЗА скулу.
	for s in [-1.0, 1.0]:
		_skel(MeshLib.box(p, Vector3(0.024, 0.104, 0.034), Vector3(s * 0.062, -0.114, -0.034),
			MeshLib.BONE_SKEL_DARK, Vector3(0, 0, s * -6.0)), "dark")
	# нижние зубы и тело челюсти — отвисла, скелет вечно слегка в шоке
	for i in 5:
		_skel(MeshLib.box(p, Vector3(0.016, 0.022, 0.020),
			Vector3(-0.044 + i * 0.022, -0.139, -0.164), MeshLib.BONE_SKEL), "bone")
	# щель рта между верхними и нижними зубами — без неё лицо было безротым
	_void(MeshLib.box(p, Vector3(0.100, 0.026, 0.030), Vector3(0, -0.122, -0.158),
		MeshLib.BONE_SKEL_VOID))
	_skel(MeshLib.box(p, Vector3(0.118, 0.036, 0.140), Vector3(0, -0.168, -0.092),
		MeshLib.BONE_SKEL), "bone")
	_skel(MeshLib.box(p, Vector3(0.098, 0.028, 0.026), Vector3(0, -0.162, -0.164),
		MeshLib.BONE_SKEL), "bone")
	# тень под подбородком: уже и мельче челюсти, поэтому читается затенением,
	# а не вторым ярусом челюсти
	_skel(MeshLib.box(p, Vector3(0.100, 0.026, 0.110), Vector3(0, -0.196, -0.088),
		MeshLib.BONE_SKEL_DARK), "dark")
	# износ: скол на темени (выемка — законно тёмный) и трещина
	_skel(MeshLib.box(p, Vector3(0.070, 0.026, 0.060), Vector3(-0.058, 0.100, 0.030),
		MeshLib.BONE_SKEL_DARK, Vector3(0, 0, 18)), "dark")
	_grime(MeshLib.box(p, Vector3(0.012, 0.090, 0.130), Vector3(0.038, 0.062, -0.020),
		MeshLib.BONE_SKEL_GRIME, Vector3(12, 0, 8)))
	# шейный обрубок — им череп садится на торс, сидит в тени под челюстью
	_skel(MeshLib.faceted(p, [
		Vector3(0.048, -0.215, 0.048),
		Vector3(0.040, -0.150, 0.040),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL_DARK), "dark")

# ---------------------------------------------------------------- торс

## Origin — в основании таза, низ по Y = 0, верх ключиц на Y = 0.72.
static func _torso(p: Node) -> void:
	# Таз СВЕТЛЫЙ. Тёмным он читался шортами, а светлые крылья над ним —
	# поясом этих шорт. Сустав теперь определяет перетяжка шейки бедра
	# на самой ноге, а не смена материала на тазу.
	_skel(MeshLib.faceted(p, [
		Vector3(0.120, 0.000, 0.085),
		Vector3(0.175, 0.055, 0.110),
		Vector3(0.195, 0.130, 0.108),
		Vector3(0.120, 0.185, 0.082),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# крылья таза — плоские пластины, силуэт «песочные часы»
	_skel(MeshLib.box(p, Vector3(0.075, 0.150, 0.100), Vector3(-0.150, 0.130, 0.005),
		MeshLib.BONE_SKEL, Vector3(0, 0, -14)), "bone")
	_skel(MeshLib.box(p, Vector3(0.075, 0.150, 0.100), Vector3(0.150, 0.130, 0.005),
		MeshLib.BONE_SKEL, Vector3(0, 0, 14)), "bone")
	# борозда между крылом таза и его телом. Вынесена на 0.005 ВПЕРЁД переднего
	# края таза: внутри шестигранника она была полностью скрыта.
	for s in [-1.0, 1.0]:
		_skel(MeshLib.box(p, Vector3(0.020, 0.140, 0.030), Vector3(s * 0.112, 0.132, -0.098),
			MeshLib.BONE_SKEL_DARK), "dark")
	# позвоночник. Чередование тёмный/светлый убрано: полосатый столб читался
	# орнаментом. Тело позвонка светлое, тёмный — остистый отросток сзади.
	for i in 8:
		var y := 0.215 + i * 0.058
		_skel(MeshLib.faceted(p, [
			Vector3(0.038, y - 0.020, 0.036),
			Vector3(0.046, y, 0.044),
			Vector3(0.036, y + 0.020, 0.034),
		], 5, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
		_skel(MeshLib.box(p, Vector3(0.022, 0.026, 0.050), Vector3(0, y, 0.062),
			MeshLib.BONE_SKEL_DARK), "dark")
	# Грудная клетка. Прежде рёбра стояли строго горизонтально с одинаковым
	# шагом и толщиной — стопка планок, «радиатор». Теперь шаг растёт кверху,
	# рёбра к верху тоньше, и каждое НАКЛОНЕНО внутрь-вниз к грудине.
	for i in 5:
		var y := 0.300 + i * 0.068 + i * i * 0.002
		var w := 0.215 - absf(i - 1) * 0.012
		var th := 0.038 - i * 0.002
		var slope := 6.0 + i * 2.5
		for s in [-1.0, 1.0]:
			# боковая дуга ребра
			_skel(MeshLib.box(p, Vector3(0.028, th, 0.185), Vector3(s * w, y, -0.010),
				MeshLib.BONE_SKEL, Vector3(0, 0, s * -7.0)), "bone")
			# передний отрезок: наклонён вниз к грудине, поэтому линии рёбер
			# больше не параллельны друг другу и не читаются досками
			_skel(MeshLib.box(p, Vector3(0.165, th - 0.004, 0.030),
				Vector3(s * (w - 0.078), y - 0.012, -0.096),
				MeshLib.BONE_SKEL, Vector3(0, s * -16.0, s * slope)), "bone")
			# задний отрезок — уходит за спину, законно тёмный
			_skel(MeshLib.box(p, Vector3(0.175, th - 0.006, 0.030),
				Vector3(s * (w - 0.086), y - 0.010, 0.078),
				MeshLib.BONE_SKEL_DARK, Vector3(0, s * 16.0, s * -slope * 0.5)), "dark")
	# грудина: длиннее прежней, чтобы наклонённое верхнее ребро дотягивалось
	# до неё. Сверху рукоятка — вертикальный акцент, ломающий ритм рёбер.
	_skel(MeshLib.box(p, Vector3(0.048, 0.330, 0.028), Vector3(0, 0.412, -0.116),
		MeshLib.BONE_SKEL), "bone")
	_skel(MeshLib.box(p, Vector3(0.072, 0.058, 0.030), Vector3(0, 0.588, -0.116),
		MeshLib.BONE_SKEL), "bone")
	# Полость грудной клетки. Была плита 0.170×0.290 — плоский прямоугольник,
	# ровно то «чёрное окно посередине радиатора». Теперь гранёный объём:
	# сужается кверху и книзу, шейдится градиентом, прямоугольником не читается.
	# GRIME, а не VOID: это тень внутри клетки, а не дыра.
	# Шире прежней: на радиусе 0.138 шестигранник закрывал только середину,
	# и между рёбрами на флангах просвечивал фон — клетка выходила пустой
	# рамкой. 0.200 по радиусу = 0.173 видимой полуширины (cos30), это внутри
	# боковых дуг рёбер (0.189) и наружу не вылезает.
	_grime(MeshLib.faceted(p, [
		Vector3(0.135, 0.262, 0.042),
		Vector3(0.200, 0.345, 0.055),
		Vector3(0.195, 0.470, 0.052),
		Vector3(0.125, 0.592, 0.038),
	], 6, Vector3(0, 0, 0.020), MeshLib.BONE_SKEL_GRIME))
	# ключицы и лопатки — на них садятся руки (Y = 0.66 в теле = 1.44)
	for s in [-1.0, 1.0]:
		_skel(MeshLib.box(p, Vector3(0.215, 0.038, 0.048), Vector3(s * 0.108, 0.658, -0.062),
			MeshLib.BONE_SKEL, Vector3(0, 0, s * -7.0)), "bone")
		# лопатка — за клеткой, законно тёмная
		_skel(MeshLib.box(p, Vector3(0.150, 0.115, 0.042), Vector3(s * 0.100, 0.615, 0.062),
			MeshLib.BONE_SKEL_DARK, Vector3(0, 0, s * 8.0)), "dark")
	# шейные позвонки светлые: они на виду, тёмными читались воротником
	for i in 3:
		_skel(MeshLib.faceted(p, [
			Vector3(0.036, 0.690 + i * 0.043, 0.034),
			Vector3(0.042, 0.710 + i * 0.043, 0.040),
		], 5, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")

# ---------------------------------------------------------------- рука

## Origin — в плече. side: -1 левая, +1 правая. Деталь уходит в -Y.
static func _arm(p: Node, side: int) -> void:
	var s := float(side)
	# головка плеча СВЕТЛАЯ: тёмной она давала шапку-погон, из-за которой
	# весь плечевой пояс читался майкой-борцовкой
	_skel(MeshLib.faceted(p, [
		Vector3(0.050, -0.055, 0.050),
		Vector3(0.062, -0.020, 0.062),
		Vector3(0.048, 0.020, 0.048),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# шейка плечевой кости — перетяжка УЖЕ и головки, и кости. Вот здесь
	# тёмному место: это углубление сустава, тень в нём настоящая.
	_skel(MeshLib.faceted(p, [
		Vector3(0.032, -0.066, 0.032),
		Vector3(0.032, -0.046, 0.032),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL_DARK), "dark")
	# плечо
	_skel(MeshLib.faceted(p, [
		Vector3(0.040, -0.330, 0.040),
		Vector3(0.030, -0.200, 0.030),
		Vector3(0.036, -0.060, 0.036),
	], 5, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# локоть светлый — это выступ на силуэте, он ловит свет
	_skel(MeshLib.faceted(p, [
		Vector3(0.046, -0.375, 0.046),
		Vector3(0.054, -0.348, 0.054),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# предплечье — две кости, между ними просвет: узнаваемо и «мрачно-анатомично»
	for off in [-0.022, 0.020]:
		_skel(MeshLib.faceted(p, [
			Vector3(0.021, -0.620, 0.021),
			Vector3(0.017, -0.500, 0.017),
			Vector3(0.024, -0.380, 0.024),
		], 5, Vector3(off * s, 0, 0.004), MeshLib.BONE_SKEL), "bone")
	# просвет между лучевой и локтевой: раньше сквозь него светил фон.
	# Тёмная перемычка задвинута между костями — тень в щели.
	_skel(MeshLib.box(p, Vector3(0.030, 0.230, 0.022), Vector3(0, -0.500, 0.004),
		MeshLib.BONE_SKEL_DARK), "dark")
	# борозда запястья
	_skel(MeshLib.box(p, Vector3(0.056, 0.014, 0.040), Vector3(0, -0.660, 0),
		MeshLib.BONE_SKEL_DARK), "dark")
	# запястье и ладонь СВЕТЛЫЕ: тёмный блок запястья был манжетой перчатки
	_skel(MeshLib.box(p, Vector3(0.070, 0.034, 0.052), Vector3(0, -0.640, 0),
		MeshLib.BONE_SKEL), "bone")
	_skel(MeshLib.box(p, Vector3(0.082, 0.050, 0.062), Vector3(0, -0.678, -0.004),
		MeshLib.BONE_SKEL), "bone")
	# линия костяшек — тонкая тёмная борозда, а не пластина на тыле кисти.
	# Пластина GRIME 0.086×0.066, что тут стояла, и была «перчаткой».
	_skel(MeshLib.box(p, Vector3(0.070, 0.012, 0.014), Vector3(0, -0.703, -0.010),
		MeshLib.BONE_SKEL_DARK), "dark")
	# пальцы — по две фаланги, слегка подогнуты, обе светлые
	for i in 4:
		var x := -0.030 + i * 0.020
		_skel(MeshLib.box(p, Vector3(0.014, 0.046, 0.016), Vector3(x, -0.722, -0.010),
			MeshLib.BONE_SKEL), "bone")
		_skel(MeshLib.box(p, Vector3(0.013, 0.036, 0.015), Vector3(x, -0.752, -0.026),
			MeshLib.BONE_SKEL, Vector3(-24, 0, 0)), "bone")
	# большой палец
	_skel(MeshLib.box(p, Vector3(0.040, 0.016, 0.016), Vector3(s * -0.052, -0.694, -0.012),
		MeshLib.BONE_SKEL, Vector3(0, 0, s * 26.0)), "bone")

# ---------------------------------------------------------------- нога

## Origin — в бедре. side: -1 левая, +1 правая. Деталь уходит в -Y.
static func _leg(p: Node, side: int) -> void:
	var s := float(side)
	# головка бедра светлая, тёмное — перетяжка шейки под ней
	_skel(MeshLib.faceted(p, [
		Vector3(0.056, -0.060, 0.056),
		Vector3(0.070, -0.022, 0.070),
		Vector3(0.052, 0.018, 0.052),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	_skel(MeshLib.faceted(p, [
		Vector3(0.040, -0.076, 0.040),
		Vector3(0.040, -0.052, 0.040),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL_DARK), "dark")
	# бедро
	_skel(MeshLib.faceted(p, [
		Vector3(0.048, -0.400, 0.048),
		Vector3(0.036, -0.240, 0.036),
		Vector3(0.044, -0.070, 0.044),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# колено — выступ, светлое
	_skel(MeshLib.faceted(p, [
		Vector3(0.052, -0.455, 0.052),
		Vector3(0.062, -0.420, 0.062),
	], 6, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	_skel(MeshLib.box(p, Vector3(0.062, 0.052, 0.028), Vector3(0, -0.436, -0.048),
		MeshLib.BONE_SKEL), "bone")
	# голень — большая берцовая и тонкая малая рядом
	_skel(MeshLib.faceted(p, [
		Vector3(0.038, -0.720, 0.038),
		Vector3(0.028, -0.590, 0.028),
		Vector3(0.044, -0.460, 0.044),
	], 5, Vector3.ZERO, MeshLib.BONE_SKEL), "bone")
	# малая берцовая — тонкая, лежит в тени большой, законно тёмная
	_skel(MeshLib.faceted(p, [
		Vector3(0.016, -0.700, 0.016),
		Vector3(0.014, -0.480, 0.014),
	], 5, Vector3(s * 0.040, 0, 0.006), MeshLib.BONE_SKEL_DARK), "dark")
	# складка голеностопа: узкая, УЖЕ и голени, и блока стопы
	_skel(MeshLib.box(p, Vector3(0.046, 0.014, 0.050), Vector3(0, -0.727, -0.004),
		MeshLib.BONE_SKEL_DARK), "dark")
	# Блок голеностопа и пяточная кость СВЕТЛЫЕ. Тёмными они вместе с тёмной
	# подошвой-грязью составляли ботинок: тёмный верх, задник и рант.
	# Подошвенная пластина GRIME 0.090×0.176 убрана совсем.
	_skel(MeshLib.box(p, Vector3(0.062, 0.048, 0.070), Vector3(0, -0.752, -0.006),
		MeshLib.BONE_SKEL), "bone")
	_skel(MeshLib.box(p, Vector3(0.086, 0.036, 0.170), Vector3(0, -0.798, -0.038),
		MeshLib.BONE_SKEL), "bone")
	# стык плюсны и пальцев — настоящая борозда, вот она тёмная
	_skel(MeshLib.box(p, Vector3(0.074, 0.014, 0.016), Vector3(0, -0.800, -0.116),
		MeshLib.BONE_SKEL_DARK), "dark")
	for i in 3:
		_skel(MeshLib.box(p, Vector3(0.020, 0.024, 0.044),
			Vector3(-0.026 + i * 0.026, -0.800, -0.140), MeshLib.BONE_SKEL), "bone")
	# пяточная кость
	_skel(MeshLib.box(p, Vector3(0.070, 0.040, 0.056), Vector3(0, -0.796, 0.048),
		MeshLib.BONE_SKEL), "bone")

# ---------------------------------------------------------------- материалы

## Кость скелета через общую точку правды MeshLib.skel_mat: альбедо плюс
## постоянный серо-зеленоватый эмиссионный пол. Без пола кость при свече
## уходила в песочную охру, а против света лицо схлопывалось в чёрную маску.
static func _skel(mi: MeshInstance3D, kind: String) -> MeshInstance3D:
	mi.material_override = MeshLib.skel_mat(kind)
	return mi

## Глазница/носовая щель/рот: почти чёрное, БЕЗ эмиссионного пола — только так
## провал остаётся провалом, когда вся остальная кость подсвечена снизу.
## Имя именно `_void`, а не `_dark`: тёмная КОСТЬ — это отдельный материал
## ("dark"), и путать их нельзя, иначе тень в суставе снова уедет в чёрное.
static func _void(mi: MeshInstance3D) -> MeshInstance3D:
	mi.material_override = MeshLib.skel_mat("void")
	return mi

## Грязь и копоть: тёмный матовый налёт поверх кости.
static func _grime(mi: MeshInstance3D) -> MeshInstance3D:
	mi.material_override = MeshLib.skel_mat("grime")
	return mi
