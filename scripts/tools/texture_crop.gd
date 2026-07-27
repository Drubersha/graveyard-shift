extends SceneTree
## Нарезает тайл-текстуры для особняка из трим-листов MegaKit.
## Запуск: godot --headless --path . -s res://scripts/tools/texture_crop.gd

const SRC := "res://assets/ext/megakit/"
const OUT := "res://assets/textures/"

const CROPS := {
	# из T_Trim_Furniture_BaseColor: рукописные доски и филёнка
	"wood_planks.png": ["T_Trim_Furniture_BaseColor.png", Rect2i(16, 16, 2016, 792)],
	"wood_panel.png": ["T_Trim_Furniture_BaseColor.png", Rect2i(40, 900, 920, 360)],
	# из T_Trim_Props_BaseColor: золото, светлый камень, тёмный дощатый пол
	"gold_band.png": ["T_Trim_Props_BaseColor.png", Rect2i(16, 8, 2016, 148)],
	"stone_light.png": ["T_Trim_Props_BaseColor.png", Rect2i(1310, 850, 700, 370)],
	"floor_dark.png": ["T_Trim_Props_BaseColor.png", Rect2i(8, 1878, 2032, 162)],
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for out_name: String in CROPS:
		var spec: Array = CROPS[out_name]
		var img := Image.load_from_file(SRC + (spec[0] as String))
		if img == null:
			print("CROP FAIL: не читается ", spec[0])
			continue
		var region := img.get_region(spec[1] as Rect2i)
		var err := region.save_png(OUT + out_name)
		print("CROP ", out_name, " ", region.get_size(), " -> ", ("OK" if err == OK else str(err)))
	quit(0)
