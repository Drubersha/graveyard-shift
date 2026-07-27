class_name SnapPoint extends Node3D
## Точка «прилипания»: сесть на скамейку, сесть в машину и т.п.
## Скелет интерактится — его притягивает в позицию точки.

var prompt := "Присесть"

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt

func interact(by: Node) -> void:
	var skel := by as SkeletonPlayer
	if skel:
		skel.sit_at(self)
