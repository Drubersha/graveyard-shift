class_name WitchNPC extends Node3D
## Некромантка. Бьюти-гот в депрессии, валяется на диване с вином.
## Квестгивер: interact → сигнал talked, миссия сама решает, что она скажет (say).

signal talked

var prompt := "Поговорить"
var _bubble: Label3D
var _torso: Node3D
var _bottle: Node3D
var _bubble_timer := 0.0

func _ready() -> void:
	add_to_group("interactable")
	_build_couch()
	_build_witch()
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
	# голова
	MeshLib.sphere(w, 0.16, Vector3(-0.55, 0.35, 0), MeshLib.WITCH_SKIN)
	# волосы — растеклись по подлокотнику
	MeshLib.sphere(w, 0.19, Vector3(-0.62, 0.42, 0.05), MeshLib.WITCH_HAIR, 0.7)
	MeshLib.box(w, Vector3(0.3, 0.1, 0.34), Vector3(-0.72, 0.22, 0), MeshLib.WITCH_HAIR)
	# шляпа набекрень
	MeshLib.cone(w, 0.24, 0.5, Vector3(-0.85, 0.5, 0), MeshLib.WITCH_DRESS, Vector3(0, 0, 55))
	# ноги через подлокотник
	MeshLib.capsule(w, 0.055, 0.5, Vector3(0.95, 0.35, 0.08), MeshLib.WITCH_SKIN, Vector3(0, 0, 100))
	MeshLib.capsule(w, 0.055, 0.5, Vector3(0.9, 0.3, -0.12), MeshLib.WITCH_SKIN, Vector3(0, 0, 115))
	MeshLib.box(w, Vector3(0.09, 0.2, 0.09), Vector3(1.22, 0.32, 0.08), Color.BLACK)
	MeshLib.box(w, Vector3(0.09, 0.2, 0.09), Vector3(1.2, 0.22, -0.14), Color.BLACK)
	# рука с бутылкой
	MeshLib.capsule(w, 0.045, 0.4, Vector3(-0.3, 0.28, -0.25), MeshLib.WITCH_SKIN, Vector3(0, 0, 70))
	_bottle = MeshLib.cylinder(w, 0.05, 0.28, Vector3(-0.12, 0.3, -0.3), MeshLib.WINE, Vector3(0, 0, -30))

func _process(_delta: float) -> void:
	# дыхание и лениво покачивающаяся бутылка
	var t := Time.get_ticks_msec() * 0.001
	_torso.scale.y = 1.0 + sin(t * 1.7) * 0.02
	_bottle.rotation.z = deg_to_rad(-30) + sin(t * 0.9) * 0.12
	if _bubble.visible:
		_bubble_timer -= _delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
