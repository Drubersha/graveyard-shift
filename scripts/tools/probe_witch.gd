extends Node
## Численная проверка крепления накладок ведьмы к костям — ДО всякой картинки.
##
## Проверяем ровно то, что ломалось раньше: шляпа на фиксированной высоте
## оставалась в воздухе, как только поза переставала быть стоячей.
## Условия:
##   1. смещение держателя от начала кости — одна и та же константа в ЛЮБОЙ позе;
##   2. абсолютные высоты в Idle и SitIdle РАЗНЫЕ (иначе накладка не поехала);
##   3. масштаб держателя = 1 (значит внутри метры, а не юниты FBX);
##   4. в Idle шляпа садится примерно туда, где её раньше вбивали руками.
##
## Запускается внутри игры (автолоады нужны): dev_shot.gd, ключ --witchprobe
##   godot --headless --path . -- --witchprobe

const POSES := ["Idle", "SitIdle", "Walking", "Sitting", "Death"]

var _fails := 0
var _started := false


func _process(_delta: float) -> void:
	if _started:
		return
	if get_tree().current_scene == null:
		return
	_started = true
	_run()


func _run() -> void:
	print("WITCHPROBE: старт")
	var witch := WitchNPC.new()
	witch.position = Vector3(0, 0, 0)
	get_tree().current_scene.add_child(witch)
	witch.set_process(false)   # холостые реплики тут не нужны
	var model: Node3D = witch.get("_model")
	var skel := _find_skel(model)
	var anim := _find_anim(model)
	print("костей: %d, анимаций: %s" % [skel.get_bone_count(), ", ".join(anim.get_animation_list())])

	var samples := {}
	for pose in POSES:
		_apply(anim, pose)
		# BoneAttachment3D подхватывает кости не по вызову, а по сигналу скелета
		# в кадре — без реальных кадров держатель остаётся на месте покоя,
		# и промер врёт «ничего не двигается». Ждём кадры.
		for i in 4:
			await get_tree().process_frame
		var row := {}
		for bone: String in ["Head", "RightHand", "Hips"]:
			var holder: Node3D = witch.call("_bone_holder", bone)
			var bone_world: Vector3 = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone))).origin
			row[bone] = {
				"holder": holder.global_position,
				"bone": bone_world,
				"delta": holder.global_position - bone_world,
				"scale": holder.global_transform.basis.get_scale(),
			}
		var hat: Node3D = witch.get("_hat_root")
		row["hat"] = hat.global_position
		var broom: Node3D = witch.get("_broom")
		row["broom_up"] = broom.global_transform.basis.y if broom else Vector3.ZERO
		samples[pose] = row
		print("\n[%s]" % pose)
		for bone: String in ["Head", "RightHand", "Hips"]:
			var r: Dictionary = row[bone]
			print("  %-10s кость=%s держатель=%s Δ=%s масштаб=%s" % [bone,
				(r["bone"] as Vector3).snappedf(0.001), (r["holder"] as Vector3).snappedf(0.001),
				(r["delta"] as Vector3).snappedf(0.001), (r["scale"] as Vector3).snappedf(0.001)])
		print("  шляпа мир=%s | «вверх» метлы=%s" % [
			(row["hat"] as Vector3).snappedf(0.001), (row["broom_up"] as Vector3).snappedf(0.001)])

	print("\n--- проверки")
	for bone: String in ["Head", "RightHand", "Hips"]:
		var base: Vector3 = samples["Idle"][bone]["delta"]
		for pose in POSES:
			var d: Vector3 = samples[pose][bone]["delta"]
			_check(d.distance_to(base) < 0.02,
				"%s: смещение держателя постоянно (в %s %s против %s в Idle)" % [bone, pose,
					d.snappedf(0.001), base.snappedf(0.001)])
	var stand: Vector3 = samples["Idle"]["hat"]
	var sit: Vector3 = samples["SitIdle"]["hat"]
	_check(absf(stand.y - sit.y) > 0.1,
		"шляпа едет за позой: стоя y=%.3f, сидя y=%.3f" % [stand.y, sit.y])
	_check(absf(samples["Death"]["hat"].y - stand.y) > 0.2,
		"шляпа падает вместе с телом: Death y=%.3f против стоячих %.3f" % [samples["Death"]["hat"].y, stand.y])
	for bone: String in ["Head", "RightHand"]:
		var s: Vector3 = samples["Idle"][bone]["scale"]
		_check(absf(s.x - 1.0) < 0.02 and absf(s.y - 1.0) < 0.02 and absf(s.z - 1.0) < 0.02,
			"%s: масштаб держателя единичный (%s)" % [bone, s.snappedf(0.001)])
	_check(absf(stand.y - 1.70) < 0.20, "шляпа стоя y=%.3f — на голове, а не в воздухе" % stand.y)
	var up: Vector3 = samples["Idle"]["broom_up"]
	_check(up.y > 0.4, "метла стоя держится черенком вверх: up=%s" % up.snappedf(0.001))

	print("\nWITCHPROBE: провалов %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  — " + msg)
	else:
		_fails += 1
		print("  FAIL— " + msg)


func _apply(anim: AnimationPlayer, short_name: String) -> void:
	for n in anim.get_animation_list():
		if n.ends_with(short_name):
			anim.play(n)
			# Death и Sitting — переходные клипы: в начале тело ещё стоит,
			# поэтому берём кадр ближе к концу, а не 0.4 с от старта.
			anim.seek(anim.get_animation(n).length * 0.85, true)
			anim.pause()
			return
	print("  (нет анимации %s)" % short_name)


func _find_skel(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find_skel(c)
		if f:
			return f
	return null


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim(c)
		if f:
			return f
	return null
