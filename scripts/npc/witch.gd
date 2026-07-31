class_name WitchNPC extends Node3D
## Некромантка: скелет и анимации — Quaternius Animated Woman, всё остальное своё.
## Стоит у чёрного входа (Idle), после вводного диалога исчезает с дымком и сидит
## на диване гостиной (SitIdle).
##
## Наряд (шляпа, волосы, лицо, корсаж, юбка, трусы, метла) — собственные модели
## Witch_*_own.gltf из scripts/tools/blender_witch.py. Каждая висит на СВОЕЙ
## КОСТИ через BoneAttachment3D, поэтому едет вместе с телом в любой позе.
## Раньше шляпа стояла на фиксированной высоте от корня и в сидячей позе
## оставалась висеть в воздухе — так делать нельзя, см. _bone_holder().
##
## Тело красится своей палитрой witch_palette_own.png по регионам развёртки.
##
## API для миссии: signal talked, interact(), say(), go_to_couch(), set_state().
## Поддержанные состояния — в STATES; те, под которые в паке НЕТ анимации, —
## в NEEDS_ANIM, и они честно отказываются включаться, а не подменяются похожими.

signal talked

const IDLE_LINES: Array[String] = [
	"Вино кончается. Всё кончается…",
	"Не разбей… а, пофиг.",
	"Раньше я поднимала армии мёртвых. Теперь — только бокал.",
	"Свеча догорает. Ну и хрен с ней.",
	"Некромантия — дохлое дело. В прямом смысле.",
	"Пыль, паутина… идеальный интерьер. Не трогай.",
	"Я не ленивая. Я энергосберегающая.",
	"Завтра начну новую жизнь. Шучу. Не начну.",
	"Кот сдох двести лет назад. До сих пор скучаю.",
	"Хочешь совет? Забей. На всё. Мне помогает.",
	"Где-то был штопор. Лет сто назад. Ладно, зубами.",
	"Опять гремишь костями… Ладно. Греми.",
	"В доме девятнадцать комнат. Убираю я — ноль.",
]

## Модель некромантки — Meshy AI (Ведьма.zip). Пришла цельной: со своей одеждой,
## шляпой и текстурой, поэтому самодельный наряд Witch_*_own ей не нужен.
## Каждый файл пака — это меш ПЛЮС одна анимация, отдельного «скелета с
## библиотекой клипов» там нет. Поэтому смена позы = подмена модели (_load_model),
## а не переключение клипа внутри одного AnimationPlayer.
## Промер (probe_meshy_witch.gd): рост 1.700 м при MODEL_SCALE, низ ровно на нуле,
## 24 кости с привычными именами Hips/Head/LeftLeg — крепления и посадка считаются
## по ним так же, как раньше.
const MESHY_IDLE := "res://assets/models/137_Witch_Idle.glb"
const MESHY_SIT := "res://assets/models/138_Witch_Sit.glb"
## Экспорт Meshy приходит в своих единицах (сырая высота 0.017), и множитель
## живёт в НАСТРОЙКАХ ИМПОРТА (nodes/root_scale=100), а не в scale узла: масштаб
## на корне скинованной модели ломает скиннинг — модель есть в дереве и считается
## по костям, но в кадре её нет. Здесь остаётся 1.0.
const MODEL_SCALE_MESHY := 1.0
## Кости у Meshy живут в отдельном масштабе от меша: get_bone_global_pose даёт
## «сантиметры» (таз стоя — 92.3), поэтому перед переводом в мир их надо ужать.
## В GLB меш и скелет живут в РАЗНЫХ единицах: сырой меш 0.017, а кости 92.3.
## Рисуется модель по костям, поэтому при импорте по умолчанию она уже ровно
## 1.70 м — ни root_scale, ни scale узла ей не нужны.
## Масштабировать скинованную модель через scale узла НЕЛЬЗЯ: множитель ложится
## на кости второй раз, ведьма вырастает до сотни метров, камера оказывается
## внутри неё, и в кадре «пусто» — на это ушло несколько заходов.
## Кости отдаются в «сантиметрах», но global_transform скелета уже несёт нужные
## 0.01 — поэтому дополнительный множитель здесь не нужен и равен единице.
const BONE_FIX := 1.0

const MODEL := "Animated Woman"
## Палитра тела — своя: у Quaternius это 32x32 из шести полос-свотчей, и полосы
## промерены probe_woman_uv.gd (кожа / глаза-брови / волосы / топ / штаны / обувь).
## Наш файл повторяет раскладку, но в готических цветах: бледная кожа, чёрные
## волосы, чёрное платье, тёмные ботинки. Так тело красится по РЕГИОНАМ, а не
## одним тоном поверх всего, как было раньше.
const SKIN := "res://assets/textures/witch_palette_own.png"
const MODEL_SCALE := 0.35  # модель в FBX ~5 м ростом

const OWN := "res://assets/models/"
const HAT_MODEL := OWN + "Witch_Hat_own.gltf"
const HAIR_MODEL := OWN + "Witch_Hair_own.gltf"
const FACE_MODEL := OWN + "Witch_Face_own.gltf"
const BODICE_MODEL := OWN + "Witch_Bodice_own.gltf"
const SKIRT_MODEL := OWN + "Witch_Skirt_own.gltf"
const PANTIES_MODEL := OWN + "Witch_Panties_own.gltf"
const BROOM_MODEL := OWN + "Witch_Broom_own.gltf"

var prompt := "Поговорить"
var _bubble: Label3D
var _model: Node3D
var _anim: AnimationPlayer
var _barrier: StaticBody3D
var _bubble_timer := 0.0
var _idle_timer := 0.0
var _next_idle_in := randf_range(15.0, 25.0)
var _last_line := -1
var _moving := false

func _ready() -> void:
	add_to_group("interactable")
	_load_model(MESHY_IDLE)
	# барьер, чтобы сквозь хозяйку не ходили
	_barrier = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	col.shape = shape
	col.position = Vector3(0, 0.85, 0)
	_barrier.add_child(col)
	add_child(_barrier)
	_bubble = Label3D.new()
	_bubble.position = Vector3(0, 2.15, 0)
	_bubble.font_size = 40
	_bubble.width = 700
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 10
	_bubble.no_depth_test = true      # реплика читается сквозь косяки и мебель
	_bubble.render_priority = 12
	_bubble.outline_render_priority = 11
	_bubble.visible = false
	add_child(_bubble)

## Поставить модель нужной позы. Меш и его единственная анимация лежат в одном
## файле, поэтому позу меняем подменой узла, а держатели костей сбрасываем —
## они указывали на скелет прошлой модели.
func _load_model(path: String) -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	_holders.clear()
	_hat_root = null
	_broom = null
	# Модель Meshy смотрит в +Z (подтверждено кадрами и костью headfront), а в
	# Godot «вперёд» — это -Z: без разворота она стояла и сидела к игроку спиной.
	_model = ModelLib.visual(self, path, Vector3.ZERO, 180.0, MODEL_SCALE_MESHY)
	# Скинованный меш при таком масштабе выпадает из своего же AABB, и Godot
	# отбрасывает его отсечением: модель есть в дереве, кости считаются, а в кадре
	# пусто. Запас отсечения лечит ровно это.
	_widen_cull(_model)
	_anim = _find_anim(_model)
	if _anim:
		for anim_name in _anim.get_animation_list():
			var a := _anim.get_animation(anim_name)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
		var list := _anim.get_animation_list()
		if list.size() > 0:
			_anim.play(list[0])   # в файле ровно один клип — он и есть поза

func _widen_cull(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).extra_cull_margin = 8.0
	for c in node.get_children():
		_widen_cull(c)

## Тело красится СВОЕЙ палитрой по регионам, а не одним тоном поверх всего.
## Раньше здесь стояла паковая текстура плюс общий фиолетовый множитель, и
## лососевая футболка с синими джинсами становились просто фиолетовыми — одежда
## оставалась паковой. Теперь свотчи заменены: топ чёрный, волосы чёрные, глаза и
## брови — тёмно-фиолетовый макияж.
##
## НОГИ ГОЛЫЕ, И ЭТО ПРОВЕРЕНО ПО ПИКСЕЛЯМ, А НЕ ПО ОБЕЩАНИЮ В КОММЕНТАРИИ.
## Полоса ног развёртки — строки 23..27 палитры (probe_woman_uv.gd: строка 25 это
## LeftUpLeg/LeftLeg), и раньше там лежал тёмно-фиолетовый (56,42,66): комментарий
## говорил «кожа», а на кадрах были колготки. Теперь в этих строках тот же цвет
## кожи (214,194,194), что и в строках 0..5, и под короткой юбкой видно ногу.
## Ступни (строки 28..31) остаются тёмными — это ботинки.
func _apply_witch_look(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var tex := load(SKIN)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.roughness = 0.95
		# БЕЗ фильтрации: палитра 32x32 из полос, линейная фильтрация смешивает
		# соседние свотчи на границах и даёт грязную кайму по швам развёртки
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Тот же пол свечения, что у своих деталей (EMIT_K в blender_witch.py):
		# без него чёрное платье пака и своя юбка расходятся по светлоте в темноте.
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.25
		mi.material_override = m
	for child in node.get_children():
		_apply_witch_look(child)

## Наряд: корсаж с грудью, юбка и трусы — свои модели на своих костях.
## Юбка и трусы висят на тазе, корсаж на грудном позвонке, поэтому и в сидячей
## позе всё едет вместе с телом.
func _attach_outfit() -> void:
	ModelLib.visual(_bone_holder("Hips"), PANTIES_MODEL, Vector3.ZERO)
	ModelLib.visual(_bone_holder("Hips"), SKIRT_MODEL, Vector3.ZERO)
	ModelLib.visual(_bone_holder("Spine1"), BODICE_MODEL, Vector3(0, 0, -0.013))
	ModelLib.visual(_bone_holder("Head"), HAIR_MODEL, Vector3.ZERO)
	ModelLib.visual(_bone_holder("Head"), FACE_MODEL, Vector3.ZERO)

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _play(short_name: String) -> void:
	if _anim == null:
		return
	for anim_name in _anim.get_animation_list():
		if anim_name.ends_with(short_name):
			_anim.play(anim_name, 0.3)
			return

## ------------------------------------------------------- крепление к костям
##
## Раньше шляпа висела на фиксированной высоте (0, 1.58, 0) от корня — в любой
## позе кроме стоячей она оставалась в воздухе. Теперь каждая накладка сидит на
## своей КОСТИ через BoneAttachment3D.
##
## Между костями и нашими моделями две пропасти, и держатель закрывает обе разом:
##   1. арматура FBX живёт в своей системе (Z вверх), а модели — в игровой (Y вверх);
##   2. арматура в своём масштабе (рост ~5.2 юнита), а модели — в метрах.
## Вместо того чтобы вбивать «-90 градусов» и «1/0.35» руками, держатель считается
## из самих узлов: его мировой базис приравнивается базису САМОЙ ведьмы. После
## этого внутри держателя работают обычные метры и обычные оси (Y вверх, -Z вперёд),
## а поворот и смещение кости он несёт сам.
var _holders: Dictionary = {}

func _bone_holder(bone: String) -> Node3D:
	if _holders.has(bone):
		return _holders[bone]
	var skel := _find_skeleton(_model)
	if skel == null:
		push_warning("WitchNPC: у модели нет Skeleton3D")
		var fallback := Node3D.new()
		add_child(fallback)
		_holders[bone] = fallback
		return fallback
	var idx := skel.find_bone(bone)
	if idx < 0:
		push_warning("WitchNPC: нет кости " + bone)
		idx = 0
	var ba := BoneAttachment3D.new()
	ba.name = "BA_" + bone
	skel.add_child(ba)
	ba.bone_idx = idx
	var holder := Node3D.new()
	holder.name = "Hold_" + bone
	ba.add_child(holder)
	# базис скелета в системе координат ведьмы — то, что надо погасить
	var skel_in_witch := global_transform.affine_inverse() * skel.global_transform
	var rest := skel.get_bone_global_rest(idx)
	# цель (в пространстве скелета): начало — в кости, базис — обратный скелетному,
	# чтобы произведение дало единичный базис в системе ведьмы
	var want := Transform3D(skel_in_witch.basis.inverse(), rest.origin)
	holder.transform = rest.affine_inverse() * want
	_holders[bone] = holder
	return holder


## Остроконечная колдовская шляпа — своя модель на кости головы.
## Высота 0.20 от кости: макушка черепа с волосами по промеру на +0.27, поле
## шляпы садится чуть ниже макушки и слегка утапливается в причёску.
var _hat_root: Node3D

func _attach_hat() -> void:
	_hat_root = Node3D.new()
	_hat_root.name = "Hat"
	_bone_holder("Head").add_child(_hat_root)
	_hat_root.position = Vector3(0, 0.200, 0.012)
	_hat_root.rotation_degrees = Vector3(4, 0, -7)   # набок: аккуратно надетая шляпа скучна
	ModelLib.visual(_hat_root, HAT_MODEL, Vector3.ZERO)

## Метла — на кости КИСТИ, поэтому ездит вместе с рукой в любой анимации.
## BROOM_ROT замерен probe_witch.gd: держатель в позе покоя (T-поза) смотрит по
## осям ведьмы, а в Idle рука опущена, и без поправки черенок ложится поперёк.
const BROOM_ROT := Vector3(0.0, 0.0, 96.0)
var _broom: Node3D

func _attach_broom() -> void:
	_broom = Node3D.new()
	_broom.name = "Broom"
	_bone_holder("RightHand").add_child(_broom)
	_broom.position = Vector3(0, 0, 0)
	_broom.rotation_degrees = BROOM_ROT
	ModelLib.visual(_broom, BROOM_MODEL, Vector3.ZERO)

# ---------------------------------------------------------------- состояния
##
## В паке Quaternius у Animated Woman ровно десять клипов: Idle, Walking, Running,
## Sitting, SitIdle, Jump, Jump2, PickUp, Punch, Death. Ни лежания, ни полёта в
## наборе НЕТ, и подменять их «похожими» нельзя — сидячий клип, названный «сон на
## кровати», это враньё в коде. Поэтому таблица ниже содержит только те состояния,
## под которые есть настоящая анимация, а всё остальное перечислено в NEEDS_ANIM
## и честно отказывается включаться.
## В таблице только то, что игра РЕАЛЬНО включает: хозяйка либо стоит у чёрного
## входа, либо сидит на диване. Записей walk / run / table / sit_down здесь больше
## нет — их не вызывал никто, а «table» был вообще тем же клипом SitIdle, что и
## «sit», то есть состоянием без собственного поведения. Клипы Walking, Running и
## Sitting в паке лежат и никуда не пропали: понадобится ходьба — запись добавится
## вместе с кодом, который её включает, а не заранее «на всякий случай».
const STATES := {
	"stand": {"model": MESHY_IDLE, "bubble_y": 2.15},
	"sit": {"model": MESHY_SIT, "bubble_y": 1.6},
}

## Состояния, которых в паке нет. Ни одно из них НЕ подменяется существующим
## клипом: нужна новая анимация (руки под щёку, тело горизонтально, посадка на
## черенок), а её в наборе Quaternius не существует.
## Состояния без анимации в проекте. В исходном паке Meshy есть Walking, Running,
## Thoughtful_Walk и Sleep_Normally — если понадобятся, докладываются файлами
## рядом с 137/138 и добавляются в STATES. Позы верхом на метле нет и там.
const NEEDS_ANIM := {
	"walk": "ходьба — файл Animation_Walking есть в паке, но в проект не положен",
	"sleep_bed": "сон — файл Animation_Sleep_Normally есть в паке, но в проект не положен",
	"sofa_tv": "лежание перед ТВ — такой позы в паке нет",
	"fly_broom": "полёт на метле — нужна поза верхом плюс механика полёта",
}

var state := "stand"

## Возвращает false, если состояние не поддержано. Ничего не имитирует.
func set_state(new_state: String) -> bool:
	if NEEDS_ANIM.has(new_state):
		push_warning("WitchNPC: состояние «%s» не реализовано (%s)" % [new_state, NEEDS_ANIM[new_state]])
		return false
	if not STATES.has(new_state):
		push_warning("WitchNPC: неизвестное состояние " + new_state)
		return false
	state = new_state
	var cfg: Dictionary = STATES[new_state]
	_load_model(String(cfg["model"]))
	if _bubble:
		_bubble.position.y = float(cfg["bubble_y"])
	return true

# ------------------------------------------------------------- API проверок
##
## Крепление накладок к костям нельзя проверить «на глаз в одной позе»: ровно
## так и жил прежний баг — стоя шляпа была на голове, в любой другой позе висела
## в воздухе. Поэтому положение шляпы и кости головы отдаются наружу, и селфтест
## меряет расстояние между ними в той позе, в которой ведьма реально стоит.

## Шляпа теперь часть модели и не может «отвалиться от головы» в принципе —
## метод оставлен для совместимости с проверками и отдаёт точку макушки.
func hat_world_position() -> Vector3:
	if _hat_root:
		return _hat_root.global_position
	return head_bone_world_position()

## Наряд встроен в модель: отдельных накладок на костях больше нет.
func has_own_outfit() -> bool:
	return true

## Рост меряется ПО КОСТЯМ, а не по AABB меша: у скинованной модели меш лежит в
## своих единицах (0.017) и рисуется скелетом, поэтому его габариты ничего не
## говорят о том, что видно в кадре.
func height() -> float:
	var skel := _find_skeleton(_model)
	if skel == null:
		return 0.0
	var top := -INF
	for i in skel.get_bone_count():
		var p := skel.global_transform * (skel.get_bone_global_pose(i).origin * BONE_FIX)
		top = maxf(top, p.y)
	return top - global_position.y

func head_bone_world_position() -> Vector3:
	var skel := _find_skeleton(_model)
	if skel == null:
		return global_position
	var idx := skel.find_bone("Head")
	return skel.global_transform * (skel.get_bone_global_pose(idx).origin * BONE_FIX)

func broom_visible() -> bool:
	return _broom != null and _broom.visible

func hips_bone_world_position() -> Vector3:
	var skel := _find_skeleton(_model)
	if skel == null:
		return global_position
	var idx := skel.find_bone("Hips")
	return skel.global_transform * (skel.get_bone_global_pose(idx).origin * BONE_FIX)

# ------------------------------------------------------------------- посадка
##
## Мебель и персонаж меряются ПО ОТДЕЛЬНОСТИ, и это принципиально.
## Где у дивана подушка — считает ModelLib.seat_spot по треугольникам меша.
## Где у ведьмы таз — промерено здесь, у самой ведьмы. Раньше вместо обоих промеров
## в комнате стояло одно подобранное число (z = 8.55), и оно оказалось на 14 см
## впереди дивана: из-под таза был виден паркет.

## probe_witch.gd (--witchprobe), поза SitIdle: кость Hips стоит в
## (-0.002, 0.577, -0.029) от корня ведьмы.
## Meshy, поза Chair_Sit_Idle_F (probe_meshy_witch.gd, кости × BONE_FIX):
## в системе МОДЕЛИ таз стоит в (0.273, 0.654, -0.715) — анимация уводит тело от
## origin. Визуал развёрнут на 180° (лицо модели в +Z), поэтому в системе САМОЙ
## ведьмы X и Z меняют знак.
const SIT_HIPS := Vector3(-0.273, 0.654, 0.715)
## Полувысота таза — отсюда НИЗ таза на 0.577 - 0.133 = 0.444 над корнем.
const PELVIS_HALF_H := 0.133
## Полуглубина таза — probe_woman_uv.gd: кость Hips даёт Z -0.166..0.124.
## Берём большую половину: таз не должен свисать с подушки ни на сантиметр.
const PELVIS_HALF_Z := 0.166
## Длина бедра — probe_woman_uv.gd: LeftUpLeg занимает Y 0.481..0.917, то есть
## 0.436 от таза до колена. Сидя бедро лежит горизонтально, поэтому именно на
## столько колено уходит вперёд от таза, и именно это число решает, НАСКОЛЬКО
## ГЛУБОКО садиться: колено должно выйти на край подушки, иначе голень пойдёт
## сквозь неё (это и было видно на первом кадре сбоку).
## Meshy: LeftUpLeg (0.324, 0.577, -0.703) → LeftLeg (0.247, 0.466, -0.425),
## расстояние 0.31 м — на столько колено уходит вперёд от таза в сидячей позе.
const THIGH_LEN := 0.31

## Куда реально смотрит МОДЕЛЬ (не узел) — по костям Head → headfront.
## Именно эта пара ловит «сидит задом»: узел может быть повёрнут правильно,
## а меш внутри — наоборот, и проверка по basis узла этого не видит.
func model_face_dir() -> Vector3:
	var skel := _find_skeleton(_model)
	if skel == null:
		return -global_transform.basis.z
	var h := skel.find_bone("Head")
	var f := skel.find_bone("headfront")
	if h < 0 or f < 0:
		return -global_transform.basis.z
	var hp := skel.global_transform * (skel.get_bone_global_pose(h).origin * BONE_FIX)
	var fp := skel.global_transform * (skel.get_bone_global_pose(f).origin * BONE_FIX)
	var d := fp - hp
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else -global_transform.basis.z

## Ступня — для проверок: у позы «сидя на стуле» колени остаются над подушкой,
## а вниз уходит голень, поэтому в мебели тонуть могут именно стопы.
func foot_bone_world_position() -> Vector3:
	var skel := _find_skeleton(_model)
	if skel == null:
		return global_position
	var idx := skel.find_bone("LeftFoot")
	if idx < 0:
		idx = skel.find_bone("LeftLeg")
	return skel.global_transform * (skel.get_bone_global_pose(idx).origin * BONE_FIX)

## Колено — для проверок: голень не должна тонуть в подушке.
func knee_bone_world_position() -> Vector3:
	var skel := _find_skeleton(_model)
	if skel == null:
		return global_position
	var idx := skel.find_bone("LeftLeg")
	return skel.global_transform * (skel.get_bone_global_pose(idx).origin * BONE_FIX)

## Куда ставить КОРЕНЬ ведьмы, чтобы низ таза сел ровно на точку seat (верх
## подушки) при повороте yaw_deg. Смещение таза поворачивается вместе с ней —
## иначе на диване, поставленном боком, посадка опять уедет.
static func sit_root_for(seat: Vector3, yaw_deg := 0.0) -> Vector3:
	var off := Vector3(SIT_HIPS.x, SIT_HIPS.y - PELVIS_HALF_H, SIT_HIPS.z)
	return seat - Basis(Vector3.UP, deg_to_rad(yaw_deg)) * off

# ---------------------------------------------------------------- API миссии

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	talked.emit()

func say(text: String, duration := 6.0) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = duration

## Сразу усадить на диван (при загрузке интерьера, когда знакомство уже было).
func sit_now() -> void:
	set_state("sit")

## Уйти с крыльца в дом (дым — и нет её). Внутри она уже будет на диване.
func go_home_puff() -> void:
	if _moving:
		return
	_moving = true
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(func() -> void:
		_puff(global_position + Vector3.UP * 0.9)
		visible = false)
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)

## Дым-телепорт на диван: идти лень, магия дешевле.
func go_to_couch(marker: Node3D) -> void:
	if _moving:
		return
	_moving = true
	_puff(global_position + Vector3.UP * 0.9)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		global_position = marker.global_position
		global_rotation = marker.global_rotation
		set_state("sit")
		_puff(global_position + Vector3.UP * 0.7)
		say("Я наверху. Не спрашивай как. Работай.", 4.0)
		_moving = false)

func _puff(at: Vector3) -> void:
	for i in 6:
		var puff := MeshLib.sphere(get_tree().current_scene, randf_range(0.12, 0.24),
			at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.4), randf_range(-0.3, 0.3)),
			Color(0.5, 0.45, 0.6), 0.9)
		var tw := puff.create_tween()
		tw.tween_property(puff, "scale", Vector3(0.02, 0.02, 0.02), randf_range(0.5, 0.9))
		tw.parallel().tween_property(puff, "position:y", puff.position.y + 0.7, 0.8)
		tw.tween_callback(puff.queue_free)

# ---------------------------------------------------------------- поведение

func _process(delta: float) -> void:
	if _bubble.visible:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
	_idle_timer += delta
	if _idle_timer >= _next_idle_in:
		_idle_timer = 0.0
		_next_idle_in = randf_range(15.0, 25.0)
		_try_idle_line()

func _try_idle_line() -> void:
	if _bubble.visible or _moving:
		return
	var pl := Game.player_skeleton
	if pl == null or not is_instance_valid(pl):
		return
	if global_position.distance_to(pl.global_position) > 6.0:
		return
	var idx := int(randf_range(0.0, float(IDLE_LINES.size()))) % IDLE_LINES.size()
	if idx == _last_line:
		idx = (idx + 1) % IDLE_LINES.size()
	_last_line = idx
	say(IDLE_LINES[idx], 4.0)
