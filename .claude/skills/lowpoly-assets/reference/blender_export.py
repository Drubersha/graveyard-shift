"""Экспорт лоу-поли модели из Blender под Graveyard Shift.

ПРОВЕРЕНО сквозным прогоном 2026-07-29 на Blender 5.2.0 LTS: ящик 0.8x0.6x1.0 м
экспортирован этим путём и промерен в Godot как X=0.800 Y=1.000 Z=0.600, низ по Y
ровно 0.000, 1 меш, 1 материал. Все параметры export_scene.gltf ниже в 5.2
поддерживаются (проверено через bpy.ops...get_rna_type().properties).

После КАЖДОГО экспорта всё равно промеряй:

    godot --headless --path . -s res://scripts/tools/probe_model.gd -- "res://assets/models/<файл>.gltf"

и сверяй с эталонами (дверь 4.188 сырых / 2.51 после x0.6, холодильник 3.308 / 1.98).
Если габариты не сошлись — правь экспорт, а НЕ подгоняй scale в коде.

Запуск внутри Blender (Scripting) или через blender-mcp execute_code.
"""

import math
from pathlib import Path

import bpy

# Куда класть. models/ — плоский каталог проекта, ext/ — исходные паки.
OUT_DIR = Path(r"C:\Users\1\Desktop\graveyard-shift\assets\models")


def prepare(obj):
    """Приводит объект к конвенциям проекта до экспорта."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    # 1. Масштаб применить. Иначе Bevel и физика считают в локальном пространстве,
    #    а Godot получит трансформ, который потом всплывёт в merged_aabb.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # 2. Origin в основание: у всех моделей пака низ по Y лежит на нуле.
    #    В Blender вверх — это Z, ось меняется при экспорте (export_yup).
    bbox_min_z = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    bpy.context.scene.cursor.location = (obj.location.x, obj.location.y, bbox_min_z)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.location = (0.0, 0.0, 0.0)

    # 3. Плоское затенение — стиль Quaternius.
    bpy.ops.object.shade_flat()


def join_by_material():
    """Один материал = один меш. У промеренных моделей пака 1 меш и 1-2 материала."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in meshes:
            o.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()


def export(name: str):
    """glTF, а не FBX: в проекте у .gltf включены generate_lods и shadow meshes."""
    out = OUT_DIR / f"{name}.gltf"
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLTF_SEPARATE",  # .gltf + .bin, как остальные модели пака
        use_selection=True,
        export_apply=True,      # применить модификаторы
        export_yup=True,        # Blender Z-up -> Godot Y-up
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
        export_cameras=False,
        export_lights=False,
    )
    return out


def check_scale(obj, expected_height_m: float, tol: float = 0.05):
    """Грубая сверка до экспорта. Настоящая проверка — probe_model.gd после."""
    dims = obj.dimensions
    height = dims.z  # в Blender вверх это Z
    ok = math.isclose(height, expected_height_m, rel_tol=tol)
    print(f"высота {height:.3f} м, ожидали {expected_height_m:.3f} — {'ок' if ok else 'НЕ СХОДИТСЯ'}")
    print(f"габариты XYZ: {dims.x:.3f} {dims.y:.3f} {dims.z:.3f}")
    return ok


if __name__ == "__main__":
    target = bpy.context.active_object
    if target is None:
        raise SystemExit("нет активного объекта")
    prepare(target)
    join_by_material()
    check_scale(target, expected_height_m=1.0)   # подставь реальную высоту предмета
    path = export("999_MyThing")
    print("экспортировано:", path)
    print("ТЕПЕРЬ ПРОМЕРЬ: probe_model.gd -- res://assets/models/999_MyThing.gltf")
