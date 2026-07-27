class_name DishMinigame extends CanvasLayer
## Мини-игра мытья тарелки: тарелка крупным планом, костлявая рука с губкой
## ходит за мышью. Возишь по пятну — оно оттирается. Кончились пятна — вышли.
## B (или кнопка) — разбить тарелку и закончить мгновенно.

signal finished(washed: bool)

const PLATE_R := 250.0
const SPONGE := Vector2(96, 64)
const WEAR_PER_PX := 0.0042   # «несколько проходов» на пятно

## Возможные следы вчерашнего ужина.
const STAIN_COLORS := [
	Color(0.72, 0.14, 0.12),   # кетчуп
	Color(0.85, 0.68, 0.12),   # горчица
	Color(0.42, 0.28, 0.14),   # подлива
	Color(0.34, 0.5, 0.2),     # что-то зелёное
	Color(0.55, 0.25, 0.5),    # варенье
	Color(0.85, 0.82, 0.62),   # присохший желток
]

class Stain:
	var pos: Vector2
	var radius: float
	var color: Color
	var wear := 0.0
	var blobs: Array[Vector3] = []   # x, y — смещение, z — радиус

var plate: BreakableProp
var _root: Control
var _sponge_pos := Vector2.ZERO
var _prev_pos := Vector2.ZERO
var _stains: Array[Stain] = []
var _center := Vector2.ZERO
var _done := false

static func start(parent: Node, plate_: BreakableProp) -> DishMinigame:
	var mg := DishMinigame.new()
	mg.plate = plate_
	parent.add_child(mg)
	return mg

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_scene)
	add_child(_root)
	_center = _root.size / 2.0
	_spawn_stains()
	_sponge_pos = _center + Vector2(0, PLATE_R + 120)
	_prev_pos = _sponge_pos
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(_sponge_pos)
	get_tree().paused = true
	for h in get_tree().get_nodes_in_group("hud"):
		(h as CanvasLayer).visible = false   # игровой интерфейс не должен просвечивать

func _spawn_stains() -> void:
	var count := randi_range(2, 5)
	var palette := STAIN_COLORS.duplicate()
	palette.shuffle()
	for i in count:
		var s := Stain.new()
		# случайно по тарелке, но не на самом ободке
		var ang := randf() * TAU
		var dist := sqrt(randf()) * (PLATE_R - 90.0)
		s.pos = Vector2(cos(ang), sin(ang)) * dist
		s.radius = randf_range(46.0, 76.0)
		s.color = palette[i % palette.size()]
		for j in randi_range(3, 5):
			s.blobs.append(Vector3(randf_range(-0.5, 0.5) * s.radius,
				randf_range(-0.5, 0.5) * s.radius, randf_range(0.45, 0.85) * s.radius))
		_stains.append(s)

func _process(_delta: float) -> void:
	if _done:
		return
	_center = _root.size / 2.0
	_sponge_pos = _root.get_global_mouse_position()
	var moved := _sponge_pos.distance_to(_prev_pos)
	if moved > 0.5:
		_scrub(_prev_pos, _sponge_pos, moved)
		_prev_pos = _sponge_pos
	_root.queue_redraw()

## Тереть можно только по тарелке и только движением — стоя на месте не отмоешь.
func _scrub(from: Vector2, to: Vector2, dist: float) -> void:
	var steps := maxi(1, int(dist / 8.0))
	var cleared := false
	for i in steps + 1:
		var p: Vector2 = from.lerp(to, float(i) / float(steps)) - _center
		if p.length() > PLATE_R:
			continue
		for s in _stains:
			if s.wear < 1.0 and p.distance_to(s.pos) < s.radius:
				s.wear = minf(s.wear + WEAR_PER_PX * (dist / float(steps + 1)) * 8.0, 1.0)
				if s.wear >= 1.0:
					cleared = true
	if cleared:
		_stains = _stains.filter(func(s: Stain) -> bool: return s.wear < 1.0)
		if _stains.is_empty():
			_finish(true)

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_B:
		_finish(false)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_finish(false)

func finish_wash() -> void:
	_finish(true)

func _finish(washed: bool) -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for h in get_tree().get_nodes_in_group("hud"):
		(h as CanvasLayer).visible = true
	if is_instance_valid(plate):
		if washed:
			plate.wash()
		else:
			plate.shatter_prop()
	finished.emit(washed)
	queue_free()

# ---------------------------------------------------------------- отрисовка

func _draw_scene() -> void:
	var size := _root.size
	_center = size / 2.0
	_root.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.06, 0.82))
	# раковина за тарелкой
	_root.draw_circle(_center, PLATE_R + 70.0, Color(0.16, 0.18, 0.22))
	_root.draw_circle(_center, PLATE_R + 52.0, Color(0.22, 0.26, 0.3))
	# тарелка
	_root.draw_circle(_center, PLATE_R, Color(0.88, 0.89, 0.92))
	_root.draw_arc(_center, PLATE_R, 0, TAU, 96, Color(0.62, 0.64, 0.7), 8.0, true)
	_root.draw_circle(_center, PLATE_R * 0.72, Color(0.93, 0.94, 0.96))
	# пятна
	for s in _stains:
		var a := 1.0 - s.wear * 0.85
		var shrink := 1.0 - s.wear * 0.45
		for b in s.blobs:
			_root.draw_circle(_center + s.pos + Vector2(b.x, b.y) * shrink,
				b.z * shrink, Color(s.color.r, s.color.g, s.color.b, a))
	# костлявая рука с губкой
	_draw_hand()
	# подписи
	var font := ThemeDB.fallback_font
	var left := "Осталось пятен: %d" % _stains.size()
	_root.draw_string(font, Vector2(40, 56), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.95, 0.95, 1.0))
	_root.draw_string(font, Vector2(40, size.y - 74),
		"Води губкой по пятнам — тереть надо с движением", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.85, 0.87, 0.95))
	_root.draw_string(font, Vector2(40, size.y - 40),
		"B или ПКМ — разбить тарелку (быстро, но так себе решение)", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.95, 0.6, 0.55))

func _draw_hand() -> void:
	var p := _sponge_pos
	var bone := Color(0.92, 0.9, 0.82)
	# губка под ладонью
	_root.draw_rect(Rect2(p - SPONGE / 2.0, SPONGE), Color(0.95, 0.82, 0.35), true)
	_root.draw_rect(Rect2(p - SPONGE / 2.0 + Vector2(6, 6), SPONGE - Vector2(12, 12)), Color(0.88, 0.72, 0.28), true)
	_root.draw_rect(Rect2(p - SPONGE / 2.0, SPONGE), Color(0.6, 0.5, 0.2), false, 3.0)
	# ладонь и пальцы
	_root.draw_rect(Rect2(p - Vector2(34, 74), Vector2(68, 46)), bone, true)
	for i in 4:
		var fx := p.x - 26 + i * 17
		_root.draw_line(Vector2(fx, p.y - 30), Vector2(fx, p.y - 4), bone, 8.0)
	_root.draw_line(Vector2(p.x - 40, p.y - 58), Vector2(p.x - 18, p.y - 30), bone, 9.0)
	# предплечье уходит за край экрана
	_root.draw_line(p + Vector2(0, -74), p + Vector2(120, -320), bone, 16.0)
	_root.draw_line(p + Vector2(18, -74), p + Vector2(150, -320), Color(0.8, 0.78, 0.7), 12.0)
