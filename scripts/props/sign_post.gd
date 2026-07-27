class_name SignPost extends Node3D
## Читаемая надпись (эпитафия, вывеска). Молчит, пока не нажмёшь E рядом:
## текст всплывает поверх геометрии, висит 3 секунды и медленно тает.

const SHOW_TIME := 3.0
const FADE_TIME := 1.2

var text := ""
var prompt := "Прочитать"
var _label: Label3D
var _timer := 0.0

static func make(parent: Node, pos: Vector3, text_: String, prompt_ := "Прочитать надпись") -> SignPost:
	var s := SignPost.new()
	s.position = pos
	s.text = text_
	s.prompt = prompt_
	parent.add_child(s)
	return s

func _ready() -> void:
	add_to_group("interactable")
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 44
	_label.outline_size = 12
	_label.width = 600
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 12
	_label.outline_render_priority = 11
	_label.pixel_size = 0.0032
	_label.modulate = Color(1, 1, 1, 0)
	_label.visible = false
	add_child(_label)

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	_label.visible = true
	_label.modulate.a = 1.0
	_timer = SHOW_TIME + FADE_TIME

func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= FADE_TIME:
		_label.modulate.a = clampf(_timer / FADE_TIME, 0.0, 1.0)
	if _timer <= 0.0:
		_label.visible = false
