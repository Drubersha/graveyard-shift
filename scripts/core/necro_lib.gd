class_name NecroLib
## Каталог и фабрика Meshy-мебели «некро» (единый стиль игры, модели юзера).
##
## КОНВЕНЦИЯ МОДЕЛЕЙ: origin в ЦЕНТРЕ AABB, высота нормирована к ~1.9,
## фронт смотрит в +Z (в комнату модель разворачивают yaw'ом узла).
## Из-за центрального origin напольная мебель ставится узлом на floor_y + h/2.
## Промеры probe_model.gd: [путь, сырой AABB]. Планировка комнат — в Mansion;
## здесь только «что это за модель и как её корректно поставить».

const CATALOG := {
	"icebox": ["res://assets/models/139_Necro_Icebox.glb", Vector3(0.714, 1.899, 0.560)],
	"sink": ["res://assets/models/140_Necro_Sink.glb", Vector3(1.886, 1.899, 1.363)],
	"stove": ["res://assets/models/141_Necro_Stove.glb", Vector3(1.689, 1.900, 1.042)],
	"cabinet": ["res://assets/models/142_Necro_Cabinet.glb", Vector3(1.899, 1.653, 0.751)],
	"wall_cab": ["res://assets/models/143_Necro_WallCabinet.glb", Vector3(0.988, 1.900, 0.399)],
	"door_in": ["res://assets/models/144_Necro_InteriorDoor.glb", Vector3(1.001, 1.899, 0.159)],
	"chandelier": ["res://assets/models/145_Necro_Chandelier.glb", Vector3(1.807, 1.897, 1.574)],
	"sconce": ["res://assets/models/146_Necro_Sconce.glb", Vector3(0.629, 1.899, 1.138)],
	"wall_clock": ["res://assets/models/153_Necro_WallClock.glb", Vector3(1.604, 1.899, 0.231)],
	"table": ["res://assets/models/154_Necro_Table.glb", Vector3(1.411, 1.900, 1.033)],
	"chair": ["res://assets/models/155_Necro_Chair.glb", Vector3(0.839, 1.899, 0.904)],
	"gf_clock": ["res://assets/models/156_Necro_GrandfatherClock.glb", Vector3(0.525, 1.899, 0.358)],
	"wine_rack": ["res://assets/models/157_Necro_WineRack.glb", Vector3(1.468, 1.899, 0.580)],
	"mannequin": ["res://assets/models/158_Necro_Mannequin.glb", Vector3(0.600, 1.899, 0.532)],
	"tool_rack": ["res://assets/models/159_Necro_ToolRack.glb", Vector3(1.447, 1.900, 0.366)],
	"workbench": ["res://assets/models/160_Necro_Workbench.glb", Vector3(1.899, 0.977, 1.208)],
	"stool": ["res://assets/models/161_Necro_Stool.glb", Vector3(1.570, 1.900, 1.396)],
	"wardrobe": ["res://assets/models/162_Necro_Wardrobe.glb", Vector3(1.061, 1.900, 0.414)],
	"toilet": ["res://assets/models/163_Necro_Toilet.glb", Vector3(1.183, 1.899, 1.780)],
	"bath_a": ["res://assets/models/164_Necro_BathroomA.glb", Vector3(1.612, 1.899, 1.530)],
	"bath_b": ["res://assets/models/165_Necro_BathroomB.glb", Vector3(1.104, 1.899, 0.967)],
	"chest": ["res://assets/models/166_Necro_Chest.glb", Vector3(1.899, 1.165, 1.098)],
	"bench": ["res://assets/models/167_Necro_Bench.glb", Vector3(1.900, 0.840, 0.596)],
	"candelabra": ["res://assets/models/168_Necro_Candelabra.glb", Vector3(1.310, 1.895, 0.644)],
	"cauldron": ["res://assets/models/169_Necro_Cauldron.glb", Vector3(1.899, 1.717, 1.397)],
	"cage": ["res://assets/models/170_Necro_Cage.glb", Vector3(1.184, 1.900, 1.150)],
	"anvil": ["res://assets/models/171_Necro_Anvil.glb", Vector3(1.899, 1.582, 1.510)],
	"ingredient": ["res://assets/models/172_Necro_IngredientShelf.glb", Vector3(1.387, 1.900, 0.382)],
	"barrel": ["res://assets/models/173_Necro_Barrel.glb", Vector3(1.535, 1.900, 1.595)],
	"bookcase": ["res://assets/models/174_Necro_Bookcase.glb", Vector3(0.983, 1.899, 0.405)],
	"front_door": ["res://assets/models/175_Necro_FrontDoor.glb", Vector3(1.370, 1.900, 0.272)],
	"grand_chand": ["res://assets/models/176_Necro_GrandChandelier.glb", Vector3(1.406, 1.899, 1.407)],
}

static func path(key: String) -> String:
	return CATALOG[key][0]

static func raw(key: String) -> Vector3:
	return CATALOG[key][1]

static func scale_for(key: String, target_h: float) -> float:
	return target_h / raw(key).y

## Напольная мебель: узел поднимается на полвысоты (origin в центре).
static func solid(parent: Node, floor_y: float, key: String, x: float, z: float,
		rot_y: float, target_h: float) -> StaticBody3D:
	return ModelLib.solid(parent, path(key),
		Vector3(x, floor_y + target_h * 0.5, z), rot_y, scale_for(key, target_h))

## Настенная/потолочная модель: pos — ЦЕНТР модели.
static func at(parent: Node, key: String, pos: Vector3, rot_y: float, target_h: float,
		make_solid := true) -> Node3D:
	if make_solid:
		return ModelLib.solid(parent, path(key), pos, rot_y, scale_for(key, target_h))
	return ModelLib.visual(parent, path(key), pos, rot_y, scale_for(key, target_h))

## Бра с тёплым огоньком; rot 0 — фронт на север (+Z), -90 — на запад (-X).
static func sconce(parent: Node, pos: Vector3, rot_y: float) -> void:
	at(parent, "sconce", pos, rot_y, 0.6, false)
	var dir := Vector3(sin(deg_to_rad(rot_y)), 0, cos(deg_to_rad(rot_y)))
	var l := OmniLight3D.new()
	l.position = pos + dir * 0.32 + Vector3(0, 0.12, 0)
	l.light_color = Color(1.0, 0.72, 0.42)
	l.omni_range = 4.5
	l.light_energy = 0.9
	parent.add_child(l)

## Навесной кухонный шкаф пропорцией под тумбу: 1.10 x 1.30 x 0.36. Модель
## вертикальная (0.99 x 1.9), равномерный масштаб делал его узким — тянем по осям.
static func wall_cab(parent: Node, pos: Vector3, rot_y: float) -> void:
	var r := raw("wall_cab")
	ModelLib.solid_xyz(parent, path("wall_cab"), pos, rot_y,
		Vector3(1.10 / r.x, 1.30 / r.y, 0.36 / r.z))

## Дверь-модель в проём width x height на петле DoorGate.
static func door(parent: Node, key: String, pos: Vector3, rot_y: float, width: float,
		height: float, swing_deg := 105.0, overscan := 1.0) -> DoorGate:
	return DoorGate.make_glb(parent, pos, rot_y, width, height,
		path(key), raw(key), swing_deg, overscan)
