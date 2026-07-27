class_name WitchNPC extends Node3D
## Некромантка. Бьюти-гот в депрессии, валяется на диване с вином.
## Квестгивер: interact → сигнал talked, миссия сама решает, что она скажет (say).
## Пассивно бормочет апатичные реплики, если скелет ошивается рядом.

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
]

var prompt := "Поговорить"
var _bubble: Label3D
var _torso: Node3D
var _bottle: Node3D
var _bubble_timer := 0.0
var _candle_light: OmniLight3D
var _idle_timer := 0.0
var _next_idle_in := randf_range(15.0, 25.0)
var _last_line := -1

func _ready() -> void:
	add_to_group("interactable")
	_build_couch()
	_build_witch()
	_build_corner()
	_bubble = Label3D.new()
	_bubble.position = Vector3(0, 1.9, 0)
	_bubble.font_size = 40
	_bubble.width = 700
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 10
	_bubble.visible = false
	add_child(_bubble)

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	talked.emit()

func say(text: String, duration := 6.0) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = duration

func _build_couch() -> void:
	var c := MeshLib.WITCH_DRESS.lightened(0.12)
	MeshLib.solid_box(self, Vector3(2.3, 0.4, 0.95), Vector3(0, 0.3, 0), c)          # сиденье
	MeshLib.solid_box(self, Vector3(2.3, 0.7, 0.25), Vector3(0, 0.75, 0.42), c)      # спинка
	MeshLib.solid_box(self, Vector3(0.28, 0.45, 0.95), Vector3(-1.12, 0.62, 0), c)   # подлокотники
	MeshLib.solid_box(self, Vector3(0.28, 0.45, 0.95), Vector3(1.12, 0.62, 0), c)
	for sx in [-1.0, 1.0]:
		MeshLib.box(self, Vector3(0.08, 0.2, 0.08), Vector3(sx * 1.0, 0.1, 0.35), MeshLib.WOOD_DARK)

func _build_witch() -> void:
	var w := Node3D.new()
	w.position = Vector3(0.1, 0.55, 0)
	add_child(w)
	# платье-конус, полулёжа: голова у левого подлокотника
	_torso = Node3D.new()
	w.add_child(_torso)
	MeshLib.cone(_torso, 0.3, 0.95, Vector3(0.25, 0.12, 0), MeshLib.WITCH_DRESS, Vector3(0, 0, -65))
	# корсет — тёмная перетяжка на талии, дышит вместе с торсом
	MeshLib.cylinder(_torso, 0.215, 0.16, Vector3(0.12, 0.06, 0), MeshLib.WITCH_DRESS.darkened(0.5), Vector3(0, 0, -65))
	# голова: бледное лицо, закрытые глаза-чёрточки, тёмные губы (лицом к игроку, -z)
	MeshLib.sphere(w, 0.16, Vector3(-0.55, 0.35, 0), MeshLib.WITCH_SKIN.lightened(0.2))
	MeshLib.box(w, Vector3(0.05, 0.012, 0.015), Vector3(-0.61, 0.4, -0.135), Color.BLACK, Vector3(0, 0, 10))
	MeshLib.box(w, Vector3(0.05, 0.012, 0.015), Vector3(-0.49, 0.4, -0.135), Color.BLACK, Vector3(0, 0, -10))
	MeshLib.box(w, Vector3(0.05, 0.018, 0.015), Vector3(-0.54, 0.3, -0.148), MeshLib.WINE.darkened(0.4), Vector3(0, 0, -6))
	# чокер на шее (сплющенный цилиндр) с зелёным камушком
	MeshLib.cylinder(w, 0.085, 0.045, Vector3(-0.43, 0.24, 0), Color.BLACK, Vector3(0, 0, 50))
	MeshLib.box(w, Vector3(0.03, 0.03, 0.015), Vector3(-0.43, 0.24, -0.085), MeshLib.ACCENT, Vector3(0, 0, 50))
	# волосы — растеклись по подлокотнику
	MeshLib.sphere(w, 0.19, Vector3(-0.62, 0.42, 0.05), MeshLib.WITCH_HAIR, 0.7)
	MeshLib.box(w, Vector3(0.3, 0.1, 0.34), Vector3(-0.72, 0.22, 0), MeshLib.WITCH_HAIR)
	# длинные пряди перевалились через подлокотник и свисают
	MeshLib.box(w, Vector3(0.3, 0.06, 0.42), Vector3(-1.2, 0.32, -0.1), MeshLib.WITCH_HAIR, Vector3(0, 0, -7))
	MeshLib.capsule(w, 0.035, 0.5, Vector3(-1.12, 0.06, -0.52), MeshLib.WITCH_HAIR, Vector3(-12, 0, 6))
	MeshLib.capsule(w, 0.03, 0.55, Vector3(-1.26, 0.02, -0.5), MeshLib.WITCH_HAIR, Vector3(-8, 0, -14))
	MeshLib.capsule(w, 0.026, 0.3, Vector3(-1.33, -0.28, -0.54), MeshLib.WITCH_HAIR, Vector3(-4, 0, -30))
	MeshLib.capsule(w, 0.032, 0.42, Vector3(-1.42, 0.14, 0.1), MeshLib.WITCH_HAIR, Vector3(8, 0, -12))
	MeshLib.capsule(w, 0.03, 0.5, Vector3(-1.4, 0.05, -0.3), MeshLib.WITCH_HAIR, Vector3(-10, 0, -10))
	# шляпа набекрень: поля + тулья + лента с пряжкой
	var hat := Node3D.new()
	hat.position = Vector3(-0.88, 0.56, 0)
	hat.rotation_degrees = Vector3(0, 0, 55)
	w.add_child(hat)
	MeshLib.cylinder(hat, 0.36, 0.05, Vector3(0, -0.22, 0), MeshLib.WITCH_DRESS)
	MeshLib.cone(hat, 0.24, 0.5, Vector3(0, 0.03, 0), MeshLib.WITCH_DRESS)
	MeshLib.cylinder(hat, 0.245, 0.07, Vector3(0, -0.17, 0), MeshLib.WITCH_DRESS.darkened(0.5))
	var buckle := MeshLib.box(hat, Vector3(0.07, 0.07, 0.03), Vector3(0, -0.17, -0.235), MeshLib.ACCENT)
	buckle.material_override = MeshLib.mat(MeshLib.ACCENT, 0.5, 0.0, MeshLib.ACCENT.darkened(0.5))
	# ноги через подлокотник
	MeshLib.capsule(w, 0.055, 0.5, Vector3(0.95, 0.35, 0.08), MeshLib.WITCH_SKIN, Vector3(0, 0, 100))
	MeshLib.capsule(w, 0.055, 0.5, Vector3(0.9, 0.3, -0.12), MeshLib.WITCH_SKIN, Vector3(0, 0, 115))
	MeshLib.box(w, Vector3(0.09, 0.2, 0.09), Vector3(1.22, 0.32, 0.08), Color.BLACK)
	MeshLib.box(w, Vector3(0.09, 0.2, 0.09), Vector3(1.2, 0.22, -0.14), Color.BLACK)
	# рука с бутылкой
	MeshLib.capsule(w, 0.045, 0.4, Vector3(-0.3, 0.28, -0.25), MeshLib.WITCH_SKIN, Vector3(0, 0, 70))
	_bottle = MeshLib.cylinder(w, 0.05, 0.28, Vector3(-0.12, 0.3, -0.3), MeshLib.WINE, Vector3(0, 0, -30))

## Уголок у изголовья: столик с запасом вина и торшер со свечой.
func _build_corner() -> void:
	MeshLib.solid_box(self, Vector3(0.55, 0.5, 0.55), Vector3(-1.55, 0.25, 0.05), MeshLib.WOOD_DARK)
	BreakableProp.make(self, "bottle", Vector3(-1.62, 0.68, 0.15))
	BreakableProp.make(self, "bottle", Vector3(-1.44, 0.68, -0.08))
	# торшер: база, стойка, чашка, свеча и тёплый огонёк
	MeshLib.cylinder(self, 0.17, 0.06, Vector3(-1.6, 0.03, 0.55), MeshLib.WOOD_DARK)
	MeshLib.cylinder(self, 0.028, 1.4, Vector3(-1.6, 0.73, 0.55), MeshLib.METAL.darkened(0.35))
	MeshLib.cylinder(self, 0.11, 0.035, Vector3(-1.6, 1.45, 0.55), MeshLib.METAL.darkened(0.2))
	MeshLib.cylinder(self, 0.045, 0.22, Vector3(-1.6, 1.58, 0.55), MeshLib.BONE)
	var flame := MeshLib.sphere(self, 0.038, Vector3(-1.6, 1.73, 0.55), MeshLib.BONE, 1.5)
	flame.material_override = MeshLib.mat(MeshLib.BONE, 1.0, 0.0, MeshLib.BONE.lightened(0.2))
	_candle_light = OmniLight3D.new()
	_candle_light.position = Vector3(-1.6, 1.7, 0.55)
	_candle_light.light_color = MeshLib.BONE
	_candle_light.omni_range = 3.5
	_candle_light.light_energy = 0.9
	add_child(_candle_light)

func _process(_delta: float) -> void:
	# дыхание, лениво покачивающаяся бутылка и мерцание свечи
	var t := Time.get_ticks_msec() * 0.001
	_torso.scale.y = 1.0 + sin(t * 1.7) * 0.02
	_bottle.rotation.z = deg_to_rad(-30) + sin(t * 0.9) * 0.12
	_candle_light.light_energy = 0.85 + sin(t * 6.7) * 0.07 + sin(t * 11.3) * 0.05
	if _bubble.visible:
		_bubble_timer -= _delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
	# апатичное бормотание себе под нос
	_idle_timer += _delta
	if _idle_timer >= _next_idle_in:
		_idle_timer = 0.0
		_next_idle_in = randf_range(15.0, 25.0)
		_try_idle_line()

func _try_idle_line() -> void:
	if _bubble.visible:
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
