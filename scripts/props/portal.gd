class_name Portal extends Node3D
## Точка перехода между локациями (улица ↔ особняк ↔ подвал).
## Локация только объявляет портал; переключение делает main.gd.

signal used

var prompt := "Войти"
var target := ""      # имя целевой локации: outdoor / indoor / cellar
var spawn_id := ""    # точка появления в целевой локации

static func make(parent: Node, pos: Vector3, prompt_: String, target_: String, spawn_id_: String) -> Portal:
	var p := Portal.new()
	p.position = pos
	p.prompt = prompt_
	p.target = target_
	p.spawn_id = spawn_id_
	parent.add_child(p)
	return p

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	used.emit()
