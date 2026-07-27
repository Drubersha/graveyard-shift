extends Node
## Дев-скрипт: открыть мини-игру мытья и снять её.
## godot --path . -s res://scripts/tools/shot_minigame.gd не годится (нужна сцена),
## поэтому запускается автолоадом DevShot по флагу --minigame.

var _frame := 0
var _shot := ""

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(shot_path: String) -> void:
	_shot = shot_path

func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 10:
		Game.main_node.switch_location("indoor", "kitchen_door")
	elif _frame == 100:
		var mansion := get_tree().get_first_node_in_group("mansion") as Mansion
		var skel := Game.player_skeleton as SkeletonPlayer
		var plate := BreakableProp.make(get_tree().current_scene, "plate_dirty", Vector3.ZERO)
		plate.global_position = skel.global_position + Vector3(0, 1.0, 0)
		skel.held = plate
		plate.freeze = true
		mansion.sink.interact(skel)
	elif _frame == 140:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot)
		print("minigame shot: ", _shot)
		get_tree().quit()
