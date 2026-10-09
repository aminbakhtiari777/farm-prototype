#!/usr/bin/env python3
"""Copies the third-party CC0 assets used by v3 into res://assets/third_party/
and downscales their textures for the web build. Source packs (downloaded
from the authors' official pages, see assets/third_party/CREDITS.md) are
expected in /workspace/v3-assets/. Re-run after updating a pack."""
import json, os, shutil, struct, sys
from PIL import Image

SRC = "/workspace/v3-assets"
DST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "third_party")


def tex(src, dst, size):
    im = Image.open(src)
    if max(im.size) > size:
        im = im.resize((size, size) if im.size[0] == im.size[1] else (size, int(size * im.size[1] / im.size[0])), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)


def gltf_with_textures(src_dir, name, dst_dir, size, rename=None):
    g = json.load(open(os.path.join(src_dir, name + ".gltf")))
    for b in g.get("buffers", []):
        copy(os.path.join(src_dir, b["uri"]), os.path.join(dst_dir, b["uri"]))
    for im in g.get("images", []):
        uri = im["uri"]
        real = uri if os.path.exists(os.path.join(src_dir, uri)) else uri.replace("_png.png", ".png")
        s = size(uri) if callable(size) else size
        tex(os.path.join(src_dir, real), os.path.join(dst_dir, uri), s)
    json.dump(g, open(os.path.join(dst_dir, (rename or name) + ".gltf"), "w"))


def glb_json(path):
    data = open(path, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    return data, json.loads(data[20:20 + jlen]), 20 + jlen


def prune_glb_animations(src, dst, keep):
    data, g, end = glb_json(src)
    g["animations"] = [a for a in g["animations"] if a["name"] in keep]
    js = json.dumps(g).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[end:]
    total = 12 + 8 + len(js) + len(rest)
    out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "wb").write(out)


def main():
    # --- Quaternius Universal Base Characters (CC0) -------------------------
    ubc = os.path.join(SRC, "ubc", "Universal Base Characters[Standard]")
    body_dir = os.path.join(ubc, "Base Characters", "Godot - UE")
    dst = os.path.join(DST, "quaternius", "characters")
    sizes = lambda uri: 1024 if ("Superhero" in uri and "Rough" not in uri) else 512
    for n in ("Superhero_Male_FullBody", "Superhero_Female_FullBody"):
        gltf_with_textures(body_dir, n, dst, sizes)
    for extra in ("T_Superhero_Male_Ligh.png", "T_Superhero_Female_Light_BaseColor.png"):
        tex(os.path.join(ubc, "Base Characters", "Textures", extra), os.path.join(dst, extra), 1024)
    hair_dir = os.path.join(ubc, "Hairstyles", "Origin at 0", "glTF (Godot)")
    for n in ("Hair_SimpleParted", "Hair_Buzzed", "Hair_Long", "Hair_Buns", "Hair_Beard", "Eyebrows_Regular", "Eyebrows_Female"):
        gltf_with_textures(hair_dir, n, os.path.join(dst, "hair"), 512)
    copy(os.path.join(ubc, "License_Standard.txt"), os.path.join(dst, "LICENSE_Quaternius_UBC.txt"))

    # --- Quaternius Universal Animation Library (CC0), pruned ---------------
    ual = os.path.join(SRC, "ual", "Universal Animation Library[Standard]")
    keep = {"Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Jump_Start", "Jump_Loop", "Jump_Land",
            "Sitting_Enter", "Sitting_Idle_Loop", "Sitting_Exit", "Interact", "PickUp_Table", "Push_Loop",
            "Idle_Talking_Loop", "Crouch_Idle_Loop", "Fixing_Kneeling", "Walk_Formal_Loop"}
    prune_glb_animations(os.path.join(ual, "Unreal-Godot", "UAL1_Standard.glb"),
                         os.path.join(DST, "quaternius", "animations", "UAL1_Standard.glb"), keep)
    copy(os.path.join(ual, "License.txt"), os.path.join(DST, "quaternius", "animations", "LICENSE_Quaternius_UAL.txt"))

    # --- Quaternius Stylized Nature MegaKit (CC0) ----------------------------
    nat = os.path.join(SRC, "nature", "glTF")
    ndst = os.path.join(DST, "quaternius", "nature")
    for n in ["CommonTree_%d" % i for i in range(1, 6)] + ["Pine_%d" % i for i in range(1, 6)] + \
             ["DeadTree_1", "Bush_Common", "Bush_Common_Flowers", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3",
              "Grass_Wispy_Tall", "Grass_Wispy_Short", "Fern_1", "Flower_3_Group", "Flower_4_Group", "Plant_1_Big"]:
        gltf_with_textures(nat, n, ndst, 512)
    copy(os.path.join(SRC, "nature", "License_Standard.txt"), os.path.join(ndst, "LICENSE_Quaternius_Nature.txt"))

    # --- Kenney kits (CC0) ---------------------------------------------------
    fur = os.path.join(SRC, "kenney_furniture-kit", "Models", "GLTF format")
    fdst = os.path.join(DST, "kenney", "furniture")
    for n in ("bedDouble", "bedSingle", "table", "tableRound", "tableCloth", "chair", "chairCushion", "televisionModern",
              "televisionVintage", "cabinetTelevision", "kitchenFridge", "kitchenFridgeLarge", "kitchenStove", "kitchenSink",
              "kitchenCabinet", "bookcaseOpen", "bookcaseClosedWide", "loungeSofa", "loungeChair", "rugRectangle", "rugRound",
              "pottedPlant", "plantSmall1", "lampRoundFloor", "lampSquareTable", "sideTable", "desk", "chairDesk",
              "computerScreen", "coatRackStanding", "bench", "benchCushion", "cardboardBoxClosed", "trashcan",
              "stoolBar", "kitchenBar", "radio", "books", "washer", "bathtub", "toilet", "speaker"):
        copy(os.path.join(fur, n + ".glb"), os.path.join(fdst, n + ".glb"))
    copy(os.path.join(SRC, "kenney_furniture-kit", "License.txt"), os.path.join(fdst, "LICENSE_Kenney_Furniture.txt"))
    car = os.path.join(SRC, "kenney_car-kit", "Models", "GLB format")
    cdst = os.path.join(DST, "kenney", "cars")
    for n in ("sedan", "van", "tractor", "police", "ambulance", "delivery"):
        copy(os.path.join(car, n + ".glb"), os.path.join(cdst, n + ".glb"))
    tex(os.path.join(car, "Textures", "colormap.png"), os.path.join(cdst, "Textures", "colormap.png"), 512)
    copy(os.path.join(SRC, "kenney_car-kit", "License.txt"), os.path.join(cdst, "LICENSE_Kenney_Cars.txt"))
    food = os.path.join(SRC, "kenney_food-kit", "Models", "GLB format")
    fodst = os.path.join(DST, "kenney", "food")
    for n in ("pumpkin", "fish", "mussel", "barrel", "coconut", "watermelon", "cup-coffee", "bread"):
        copy(os.path.join(food, n + ".glb"), os.path.join(fodst, n + ".glb"))
    tex(os.path.join(food, "Textures", "colormap.png"), os.path.join(fodst, "Textures", "colormap.png"), 512)
    copy(os.path.join(SRC, "kenney_food-kit", "License.txt"), os.path.join(fodst, "LICENSE_Kenney_Food.txt"))
    print("assets copied to", DST)


if __name__ == "__main__":
    main()
