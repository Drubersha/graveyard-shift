"""Палитра тела некромантки -> assets/textures/witch_palette_own.png.

    python scripts/tools/make_witch_palette.py

ЗАЧЕМ ГЕНЕРАТОР, А НЕ КАРТИНКА В РЕПОЗИТОРИИ. Палитра лежала бинарником, и по
ней нельзя было прочитать, какая полоса что красит. Из-за этого в witch.gd жил
комментарий «штаны перекрашены в кожу (под короткой юбкой нужны голые ноги)», а в
полосе ног все эти круги стоял тёмно-фиолетовый (56,42,66) — на кадрах ноги
читались колготками. Код обещал одно, картинка показывала другое, и проверить это
можно было только пипеткой. Теперь цвета видны текстом.

РАСКЛАДКА. У Quaternius Animated Woman развёртка кладёт тело в шесть
горизонтальных полос текстуры 32x32. Кто в какой полосе — промерено
probe_woman_uv.gd по ДОМИНИРУЮЩЕЙ кости каждой вершины, а не на глаз:

    строка  1  Head, Spine2, плечи, кисти      -> кожа лица, шеи, рук
    строка  8  Head (428 вершин)               -> глаза и брови
    строка 13  Head (825 вершин)               -> волосы
    строка 18  Spine2, Spine1, Hips            -> платье, торс
    строка 25  LeftUpLeg, LeftLeg, пальцы      -> НОГИ
    строка 30  LeftToeBase, LeftFoot           -> обувь

Фильтрация в witch.gd стоит NEAREST: полосы нельзя размывать, иначе на границах
свотчей появляется грязная кайма по швам развёртки. Поэтому и градиентов здесь
нет — только ровные полосы.
"""

import os
import struct
import zlib

SIZE = 32
OUT = os.path.join(os.path.dirname(__file__), "..", "..",
                   "assets", "textures", "witch_palette_own.png")

SKIN = (214, 194, 194)      # бледная кожа
MAKEUP = (46, 26, 54)       # тёмно-фиолетовые глаза и брови
HAIR = (28, 22, 34)         # почти чёрные волосы
DRESS = (34, 25, 44)        # чёрно-фиолетовое платье
BOOTS = (30, 22, 36)        # тёмные ботинки

# (первая строка, последняя строка включительно, цвет, что это)
BANDS = [
    (0, 5, SKIN, "кожа: лицо, шея, руки"),
    (6, 10, MAKEUP, "глаза и брови — макияж"),
    (11, 16, HAIR, "волосы"),
    (17, 22, DRESS, "платье и торс"),
    # НОГИ — КОЖА. Здесь стоял DRESS-фиолетовый, и ровно из-за него ноги на кадрах
    # выглядели колготками, хотя юбка короткая и под ней задуманы голые ноги.
    # Сюда же попадают пальцы правой кисти — им телесный цвет тоже правильный.
    (23, 27, SKIN, "ноги (и пальцы кисти) — голая кожа"),
    (28, 31, BOOTS, "обувь"),
]


def rows():
    out = []
    for y in range(SIZE):
        color = None
        for (lo, hi, rgb, _what) in BANDS:
            if lo <= y <= hi:
                color = rgb
                break
        if color is None:
            raise SystemExit("строка %d не покрыта ни одной полосой" % y)
        out.append(bytes(color) * SIZE)
    return out


def png(rows_rgb):
    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))

    raw = b"".join(b"\x00" + r for r in rows_rgb)     # фильтр 0 на каждой строке
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def main():
    path = os.path.normpath(OUT)
    with open(path, "wb") as fh:
        fh.write(png(rows()))
    print("записано: %s (%dx%d)" % (path, SIZE, SIZE))
    for (lo, hi, rgb, what) in BANDS:
        print("  строки %2d..%-2d  rgb%-16s %s" % (lo, hi, rgb, what))


if __name__ == "__main__":
    main()
