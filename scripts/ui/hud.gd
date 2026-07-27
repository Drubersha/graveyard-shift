class_name GameHUD extends CanvasLayer
## Интерфейс: цель миссии, подсказки, промпт взаимодействия,
## срач-о-метр и оверлей кулдауна при рассыпании.

var _objective: Label
var _hint: Label
var _prompt: Label
var _cooldown: Label
var _meter: ProgressBar
var _meter_label: Label
var _hint_timer := 0.0

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_objective = _make_label(root, 20, HORIZONTAL_ALIGNMENT_LEFT)
	_set_rect(_objective, 0.0, 0.0, 16, 12, 620, 90)

	var help := _make_label(root, 13, HORIZONTAL_ALIGNMENT_RIGHT)
	_set_rect(help, 1.0, 0.0, -370, 12, 356, 200)
	help.text = "WASD — ходить  |  Space — прыжок
ЛКМ — схватить / держать и отпустить — швырнуть
E — взаимодействовать
F — оторвать/прирастить руку
G — бросить череп (тело соберётся у него)
R — рассыпаться  |  Tab — тело/рука  |  Esc — мышь"

	_prompt = _make_label(root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_set_rect(_prompt, 0.5, 1.0, -400, -150, 800, 34)

	_hint = _make_label(root, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.modulate = Color(1.0, 0.95, 0.7)
	_set_rect(_hint, 0.5, 1.0, -450, -110, 900, 60)

	_cooldown = _make_label(root, 38, HORIZONTAL_ALIGNMENT_CENTER)
	_cooldown.modulate = Color(1.0, 0.6, 0.55)
	_set_rect(_cooldown, 0.5, 0.5, -400, -40, 800, 80)
	_cooldown.visible = false

	_meter = ProgressBar.new()
	_meter.show_percentage = false
	root.add_child(_meter)
	_set_rect(_meter, 0.5, 0.0, -220, 14, 440, 26)
	_meter.visible = false
	_meter_label = _make_label(_meter, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_meter_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	var crosshair := _make_label(root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	crosshair.text = "·"
	_set_rect(crosshair, 0.5, 0.5, -10, -16, 20, 20)

	Game.objective_changed.connect(func(text: String) -> void: _objective.text = text)
	Game.hint_shown.connect(_show_hint)

func _make_label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _set_rect(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h

func _show_hint(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	_hint_timer = 5.0

func _process(delta: float) -> void:
	# подсказка гаснет
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer < 1.0:
			_hint.modulate.a = maxf(_hint_timer, 0.0)

func _physics_process(_delta: float) -> void:
	# промпт ближайшего интерактива (рейкаст видимости — только в physics-тике)
	_prompt.text = ""
	var possessed := Game.possessed
	if is_instance_valid(possessed):
		var best_d := 2.3
		var best: Node = null
		for node in possessed.get_tree().get_nodes_in_group("interactable"):
			if node is Node3D and node.has_method("get_prompt"):
				var d: float = (node as Node3D).global_position.distance_to(possessed.global_position)
				if d < best_d and Game.has_line_of_sight(possessed, node):
					best_d = d
					best = node
		if best:
			_prompt.text = "[E] " + str(best.call("get_prompt"))
	_update_meters()

func _update_meters() -> void:
	# срач-о-метр
	if Game.mess_target > 0:
		_meter.visible = true
		_meter.max_value = Game.mess_target
		_meter.value = Game.mess_points
		_meter_label.text = "СРАЧ: %d / %d" % [Game.mess_points, Game.mess_target]
	else:
		_meter.visible = false
	# кулдаун рассыпания
	var skel := Game.player_skeleton as SkeletonPlayer
	if skel and skel.state == SkeletonPlayer.State.SHATTERED:
		_cooldown.visible = true
		var left := skel.cooldown_ratio() * SkeletonPlayer.REASSEMBLE_COOLDOWN
		if left > 0.05:
			_cooldown.text = "РАССЫПАЛСЯ\nсборка через %.1f с" % left
		else:
			_cooldown.text = "СОБИРАЕМСЯ…\n(череп должен остановиться)"
	else:
		_cooldown.visible = false
