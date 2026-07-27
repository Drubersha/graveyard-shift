class_name TutorialMission extends Node
## Туториал «Рабочий день скелета»: встреча с хозяйкой на заднем крыльце →
## подмести кухню → разобраться с грязной посудой (мыть или бить — ей похер) →
## приготовить завтрак (мука в запертой кладовке: рука через вентиляцию) →
## подать завтрак на диван, не разбив.

enum Stage { MEET, SWEEP, DISHES, BREAKFAST, SERVE, DONE }

var mansion: Mansion
var player: SkeletonPlayer

var stage := Stage.MEET
var _dust_done := 0
var _dust_total := 0
var _plates_done := 0
var _plates_total := 0
var _beacon: MeshInstance3D

func _ready() -> void:
	_dust_total = mansion.dust_list.size()
	_plates_total = mansion.dirty_plates.size()
	mansion.witch.talked.connect(_on_talk)
	for d in mansion.dust_list:
		d.cleaned.connect(_on_dust)
	mansion.sink.washed.connect(_on_plate_washed)
	for p in mansion.dirty_plates:
		p.destroyed.connect(_on_plate_broken.bind(p))
	mansion.pantry_lever.activated.connect(mansion.pantry_door.open)
	mansion.stove.cooked.connect(_on_cooked)
	mansion.serve_zone.served.connect(_on_served)
	_beacon = MeshLib.cylinder(self, 0.35, 4.0, Vector3.ZERO, MeshLib.ACCENT)
	var m := MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.22
	_beacon.material_override = m
	_enter(Stage.MEET)
	Game.hint("WASD — ходить. Остальное управление — на панели справа сверху.")

func _enter(s: Stage) -> void:
	stage = s
	Game.mission_stage_changed.emit(s)
	match s:
		Stage.MEET:
			Game.objective_changed.emit("Кладбище — это, оказывается, твой задний двор. Хозяйка ждёт у чёрного входа особняка.")
			_beacon_at(mansion.witch.global_position)
		Stage.SWEEP:
			_objective_sweep()
			_beacon_at(mansion.broom.global_position)
			Game.hint("Веник хватается ЛКМ. Таскай его по пыльным пятнам — как получится. Хоть волоком.")
			if _dust_done >= _dust_total:
				_sweep_complete()
		Stage.DISHES:
			_objective_dishes()
			_beacon_at(mansion.sink.global_position)
			Game.hint("Неси тарелки к раковине. Или бей. Результат один — грязной посуды нет.")
			if _plates_done >= _plates_total:
				_dishes_complete()
		Stage.BREAKFAST:
			Game.objective_changed.emit("Завтрак: положи на плиту ЯЙЦО, МУКУ и ВИНО, затем жми E. Мука — в кладовке. Кладовка заперта. Ну, ты понял.")
			_beacon_at(mansion.stove.global_position)
			Game.hint("Запертая кладовка? В стене кухни у пола есть вентиляция. Рука (F) пролезет.")
		Stage.SERVE:
			Game.objective_changed.emit("Отнеси завтрак хозяйке на диван. НЕ. РАЗБЕЙ.")
			mansion.serve_zone.active = true
			_beacon_at(mansion.serve_zone.global_position)
		Stage.DONE:
			Game.objective_changed.emit("Рабочий день окончен! Особняк — твоя песочница: ломай, кидай череп, тренируй руку. Скоро — город (M2).")
			_beacon.visible = false

## Маяк парит над целью, не накрывая её саму.
func _beacon_at(pos: Vector3) -> void:
	_beacon.visible = true
	_beacon.global_position = pos + Vector3.UP * 4.3

# ---------------------------------------------------------------- диалоги

func _on_talk() -> void:
	match stage:
		Stage.MEET:
			mansion.witch.say("О. Ожил. Значит так: дом — свинарник, у меня депрессия и лапки. Начни с кухни — подмети. Веник где-то там.", 7.0)
			mansion.witch.go_to_couch(mansion.couch_marker)
			_enter(Stage.SWEEP)
		Stage.SWEEP:
			mansion.witch.say("Веник. Пыль. Веником — по пыли. Что непонятного?")
		Stage.DISHES:
			mansion.witch.say("Посуда сама себя не помоет. И не разобьёт. К сожалению.")
		Stage.BREAKFAST:
			mansion.witch.say("Яйцо, мука, вино. Всё на плиту. Это не рецепт, это стиль жизни.")
		Stage.SERVE:
			mansion.witch.say("Я жду. Голодная. И трезвая. Опасное сочетание.")
		Stage.DONE:
			mansion.witch.say("Иди уже. Погреми костями во дворе.")

# ---------------------------------------------------------------- уборка

func _on_dust() -> void:
	_dust_done += 1
	if stage != Stage.SWEEP:
		return
	if _dust_done >= _dust_total:
		_sweep_complete()
	else:
		_objective_sweep()
		if _dust_done == 2:
			mansion.witch.say("Гляди-ка. Умеет.", 3.0)

func _sweep_complete() -> void:
	mansion.witch.say("Уже не свинарник. Хлев, максимум. Теперь — посуда.", 5.0)
	_enter(Stage.DISHES)

func _objective_sweep() -> void:
	Game.objective_changed.emit("«Уборка», часть 1: подмети кухню (%d/%d). Веник — твой лучший друг. Единственный друг." % [_dust_done, _dust_total])

# ---------------------------------------------------------------- посуда

func _on_plate_washed() -> void:
	_plates_done = mini(_plates_done + 1, _plates_total)
	_after_plate()

func _on_plate_broken(plate: BreakableProp) -> void:
	# разбитая ГРЯЗНАЯ тарелка — тоже решение (помытые бьются бесплатно)
	if plate.kind != "plate_dirty":
		return
	_plates_done = mini(_plates_done + 1, _plates_total)
	if stage == Stage.DISHES:
		mansion.witch.say("Минус тарелка — минус проблема.", 3.0)
	_after_plate()

func _after_plate() -> void:
	if stage != Stage.DISHES:
		return
	if _plates_done >= _plates_total:
		_dishes_complete()
	else:
		_objective_dishes()

func _dishes_complete() -> void:
	mansion.witch.say("Так. С посудой разобрались. Теперь главное: я голодная.", 5.0)
	_enter(Stage.BREAKFAST)

func _objective_dishes() -> void:
	Game.objective_changed.emit("«Уборка», часть 2: грязная посуда (%d/%d). Мой в раковине. Или разбей — мне правда всё равно." % [_plates_done, _plates_total])

# ---------------------------------------------------------------- завтрак

func _on_cooked() -> void:
	if stage != Stage.BREAKFAST:
		return
	mansion.witch.say("Пахнет… съедобно? Неси сюда. Аккуратно, руки-крюки.", 5.0)
	# если завтрак разбить — плита выдаст добавку, миссия не ломается
	var b := mansion.stove._breakfast
	if is_instance_valid(b):
		b.destroyed.connect(func() -> void:
			if stage == Stage.SERVE:
				Game.hint("Завтрак — всё. Плита милосердна: вернись и нажми E — будет добавка."))
	_enter(Stage.SERVE)

func _on_served() -> void:
	if stage != Stage.SERVE:
		# сработало вне миссии — вернём флаг зоне
		mansion.serve_zone.active = true
		return
	mansion.witch.say("…Съедобно. Наверное. Ладно, кости. На сегодня свободен.", 6.0)
	_enter(Stage.DONE)
