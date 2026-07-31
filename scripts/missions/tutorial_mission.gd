class_name TutorialMission extends Node
## Туториал в трёх локациях (персистентный, переживает переключения).
## Кладбище: собраться из костей → пройтись туда-обратно → рукой открыть ворота →
## встреча с хозяйкой у чёрного входа. Особняк: подмести кухню → грязная посуда
## в обеденном зале → завтрак (яйцо из холодильника, вино из погреба, мука из
## запертой зельеварочной) → подать наверх в гостиную.

enum Stage { ASSEMBLE, WALK_OUT, WALK_BACK, GATE, MEET, SWEEP, DISHES, BREAKFAST, SERVE, DONE }

var player: SkeletonPlayer
var stage := Stage.ASSEMBLE

# рефы текущей локации (обновляются при каждой загрузке)
var graveyard: GraveyardScene
var shell: Mansion       # экстерьер
var mansion: Mansion     # интерьер
var cellar: Dungeon

var _dust_done := 0
var _plates_done := 0
var _plates_total := 2
var _dust_total := 6
var _beacon: MeshInstance3D

func _ready() -> void:
	# «дым» цели: столб всегда стоит НА полу цели и тянется вверх
	_beacon = MeshLib.cylinder(self, 0.22, 3.0, Vector3.ZERO, MeshLib.ACCENT)
	var m := MeshLib.mat(MeshLib.ACCENT, 1.0, 0.0, MeshLib.ACCENT)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.11
	_beacon.material_override = m
	_beacon.visible = false

## Старт игры: рассыпаться и учиться собираться.
func start_intro() -> void:
	player.reassembled.connect(_on_reassembled)
	player.call_deferred("shatter", Vector3.UP)
	_enter(Stage.ASSEMBLE)
	Game.hint("Мышь — камера. Жми R, чтобы собраться: сам скелет уже не срастается.")

# ---------------------------------------------------------------- привязка локаций

func bind_outdoor(g: GraveyardScene, s: Mansion) -> void:
	graveyard = g
	shell = s
	mansion = null
	cellar = null
	g.gate_opened.connect(_on_gate_opened)
	if is_instance_valid(s.witch):
		s.witch.talked.connect(_on_talk)
		if stage > Stage.MEET:
			s.witch.queue_free()   # знакомство уже было
	# ворота могли открыть заранее — этап с рукой не должен превращаться в софтлок
	if stage <= Stage.GATE and g.gate_is_open:
		stage = Stage.MEET
	_enter(stage)

func bind_indoor(m: Mansion) -> void:
	graveyard = null
	shell = null
	cellar = null
	mansion = m
	for d in m.dust_list:
		d.cleaned.connect(_on_dust.bind(d))
	m.sink.washed.connect(_on_plate_washed)
	for p in m.dirty_plates:
		p.destroyed.connect(_on_plate_broken.bind(p))
	m.pantry_lever.activated.connect(func() -> void:
		Game.world_state["pantry_open"] = true    # дверь останется открытой и после подвала
		m.pantry_door.open())
	m.stove.cooked.connect(_on_cooked)
	m.serve_zone.served.connect(_on_served)
	m.witch.talked.connect(_on_talk)
	_enter(stage)

func bind_cellar(c: Dungeon) -> void:
	graveyard = null
	shell = null
	mansion = null
	cellar = c
	_enter(stage)

# ---------------------------------------------------------------- стадии

func _enter(s: Stage) -> void:
	stage = s
	Game.mission_stage_changed.emit(s)
	match s:
		Stage.ASSEMBLE:
			Game.objective_changed.emit("Ты — куча костей в открытой могиле. Само не срастётся: жми R — кости слетятся к черепу.")
			_beacon.visible = false
		Stage.WALK_OUT:
			Game.objective_changed.emit("Отлично, стоишь. Теперь разомни кости: пройдись до маяка (WASD).")
			if graveyard:
				_beacon_at(graveyard.global_position + graveyard.walk_marker_out)
		Stage.WALK_BACK:
			Game.objective_changed.emit("А теперь обратно к могиле. Да, это и есть разминка. Да, вся.")
			if graveyard:
				_beacon_at(graveyard.global_position + graveyard.walk_marker_back)
		Stage.GATE:
			if graveyard and graveyard.gate_is_open:
				_enter(Stage.MEET)
				return
			Game.objective_changed.emit("Ворота кладбища заперты, рычаг — снаружи. Оторви руку (F), проползи в щель ПОД воротами и дёрни его (E).")
			if graveyard:
				_beacon_at(graveyard.global_position + graveyard.gate_center)
			Game.hint("Рука управляется как машинка: WASD, Space — подскок, Tab — вернуться в тело.")
		Stage.MEET:
			Game.objective_changed.emit("Кладбище — это, оказывается, твой задний двор. Хозяйка ждёт у чёрного входа особняка.")
			if shell and is_instance_valid(shell.witch):
				_beacon_at(shell.witch.global_position)
		Stage.SWEEP:
			_objective_sweep()
			if mansion:
				_beacon_at(mansion.broom.global_position)
				Game.hint("Мётлы — в кладовке на 2-м этаже, восточное крыло. Хватай ЛКМ и таскай по пыли на кухне.")
			elif shell:
				Game.hint("Пыль сама себя не подметёт. Заходи в дом через чёрный ход.")
				_beacon_at(shell.portals[0].global_position)
			if _dust_done >= _dust_total:
				_sweep_complete()
		Stage.DISHES:
			_objective_dishes()
			if mansion:
				_beacon_at(mansion.sink.global_position)
				Game.hint("Две тарелки — в обеденном зале. Бери (ЛКМ), неси к раковине, жми E — и три губкой. Или разбей, дело твоё.")
			if _plates_done >= _plates_total:
				_dishes_complete()
		Stage.BREAKFAST:
			Game.objective_changed.emit("Завтрак: ЯЙЦО (в холодильнике, E), ВИНО (в погребе — спуск с кухни), МУКА (в зельеварочной, восточное крыло). Всё на плиту, потом E.")
			if mansion:
				_beacon_at(mansion.stove.global_position)
				Game.hint("Зельеварочная заперта: в стене у пола вентиляция — рука (F) пролезет и дёрнет рычаг.")
			elif cellar:
				Game.hint("Вино — на стеллажах и в ящике. Возьми бутылку (ЛКМ) — она поедет с тобой наверх.")
		Stage.SERVE:
			Game.objective_changed.emit("Отнеси завтрак хозяйке в гостиную на 2-м этаже. По лестнице. НЕ. РАЗБЕЙ.")
			if mansion:
				mansion.serve_zone.active = true
				_beacon_at(mansion.serve_zone.global_position)
		Stage.DONE:
			Game.objective_changed.emit("Рабочий день окончен! Особняк, подвал и кладбище — твоя песочница. Скоро — город (M2).")
			_beacon.visible = false

## Маяк стоит на полу цели и тянется вверх — виден, но не тонет в геометрии.
func _beacon_at(pos: Vector3) -> void:
	_beacon.visible = true
	_beacon.global_position = pos + Vector3.UP * 1.5

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or graveyard == null:
		return
	match stage:
		Stage.WALK_OUT:
			if player.global_position.distance_to(graveyard.global_position + graveyard.walk_marker_out) < 1.8:
				_enter(Stage.WALK_BACK)
		Stage.WALK_BACK:
			if player.global_position.distance_to(graveyard.global_position + graveyard.walk_marker_back) < 1.8:
				Game.hint("Разминка окончена. Кости в тонусе. Ну, насколько это возможно.")
				_enter(Stage.GATE)

# ---------------------------------------------------------------- события пролога

func _on_reassembled() -> void:
	if stage == Stage.ASSEMBLE:
		_enter(Stage.WALK_OUT)

func _on_gate_opened() -> void:
	if stage <= Stage.GATE:
		Game.hint("Ворота открыты. Руку можно прирастить обратно: подойди к ней и жми F.")
		_enter(Stage.MEET)

# ---------------------------------------------------------------- диалоги

func _on_talk() -> void:
	var w: WitchNPC = null
	if shell and is_instance_valid(shell.witch):
		w = shell.witch
	elif mansion and is_instance_valid(mansion.witch):
		w = mansion.witch
	if w == null:
		return
	match stage:
		Stage.MEET:
			w.say("О. Ожил. Значит так: особняк — свинарник, у меня депрессия и лапки. Начни с кухни — подмети. Мётлы наверху, в кладовке.", 7.0)
			w.go_home_puff()
			_enter(Stage.SWEEP)
		Stage.SWEEP:
			w.say("Мётлы в кладовке на втором этаже. Да, я храню мётлы в другом крыле от пыли. Логистика.")
		Stage.DISHES:
			w.say("Посуда в обеденном зале. Сама себя не помоет. И не разобьёт. К сожалению.")
		Stage.BREAKFAST:
			w.say("Яйцо из холодильника, вино из погреба, мука из зельеварочной. Это не рецепт, это квест.")
		Stage.SERVE:
			w.say("Я жду. Голодная. И трезвая. Опасное сочетание.")
		Stage.DONE:
			w.say("Иди уже. Погреми костями во дворе.")
		_:
			w.say("Сначала выберись с собственного кладбища. Потом поговорим.")

# ---------------------------------------------------------------- уборка/посуда/завтрак

func _on_dust(patch: DustPatch = null) -> void:
	if patch and patch.id >= 0:
		Game.mark("dust_cleaned", patch.id)
	_dust_done = Game.world_state["dust_cleaned"].size()
	if stage != Stage.SWEEP:
		return
	if _dust_done >= _dust_total:
		_sweep_complete()
	else:
		_objective_sweep()
		if _dust_done == 2 and mansion:
			mansion.witch.say("Гляди-ка. Умеет.", 3.0)

func _sweep_complete() -> void:
	if mansion:
		mansion.witch.say("Уже не свинарник. Хлев, максимум. Теперь — посуда в обеденном зале.", 5.0)
	_enter(Stage.DISHES)

func _objective_sweep() -> void:
	Game.objective_changed.emit("«Уборка», часть 1: подмети кухню (%d/%d). Метла — твой лучший друг. Единственный друг." % [_dust_done, _dust_total])

func _on_plate_washed() -> void:
	var skel := player as SkeletonPlayer
	if skel and is_instance_valid(skel.held) and skel.held is BreakableProp:
		var p := skel.held as BreakableProp
		if p.id >= 0:
			Game.mark("plates_done", p.id)
	_plates_done = maxi(_plates_done + 1, Game.world_state["plates_done"].size())
	_after_plate()

func _on_plate_broken(plate: BreakableProp) -> void:
	if plate.kind != "plate_dirty":
		return
	if plate.id >= 0:
		Game.mark("plates_done", plate.id)
	_plates_done = maxi(_plates_done + 1, Game.world_state["plates_done"].size())
	if stage == Stage.DISHES and mansion:
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
	if mansion:
		mansion.witch.say("Так. С посудой разобрались. Теперь главное: я голодная.", 5.0)
	_enter(Stage.BREAKFAST)

func _objective_dishes() -> void:
	Game.objective_changed.emit("«Уборка», часть 2: грязная посуда (%d/%d). Неси тарелку из обеденного зала к раковине и жми E — начнётся мытьё. Или разбей, мне всё равно." % [_plates_done, _plates_total])

func _on_cooked() -> void:
	if stage != Stage.BREAKFAST or mansion == null:
		return
	mansion.witch.say("Пахнет… съедобно? Неси наверх. Аккуратно, руки-крюки.", 5.0)
	var b := mansion.stove._breakfast
	if is_instance_valid(b):
		b.destroyed.connect(func() -> void:
			if stage == Stage.SERVE:
				Game.hint("Завтрак — всё. Плита милосердна: вернись и нажми E — будет добавка."))
	_enter(Stage.SERVE)

func _on_served() -> void:
	if stage != Stage.SERVE:
		if mansion:
			mansion.serve_zone.active = true
		return
	if mansion:
		mansion.witch.say("…Съедобно. Наверное. Ладно, кости. На сегодня свободен.", 6.0)
	_enter(Stage.DONE)
