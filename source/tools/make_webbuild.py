#!/usr/bin/env python3
"""Sync the project into a web copy with web-friendly settings.
Usage: python3 tools/make_webbuild.py [dest] [export_dir]
Compatibility renderer, no SSAO/SSIL/DOF/SSS, grass ~24k (farm/nature_density),
fewer trees, shadows 4096 / quality 3, ambient 0.75, exposure 0.92, single-threaded.
PERF: character/hair textures capped at 512 px (process/size_limit) - smaller pck + faster decode; lossless kept (VRAM ETC2+S3TC would double download size). Quality Auto = Medium on the web (PerfWorld)."""
import os, re, shutil, subprocess, sys
SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = sys.argv[1] if len(sys.argv) > 1 else "/workspace/farm-prototype-v7b1-webbuild"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/workspace/farm-prototype-v7b1-web"
os.makedirs(DST, exist_ok=True)
# Mirror SRC -> DST (keep DST/.godot so re-imports are fast).
for name in os.listdir(DST):
    if name != ".godot":
        full = os.path.join(DST, name)
        shutil.rmtree(full) if os.path.isdir(full) and not os.path.islink(full) else os.remove(full)
for name in os.listdir(SRC):
    if name in (".godot", ".git", ".github", "devtmp", "builds", "export_presets.cfg"):
        continue
    full = os.path.join(SRC, name)
    if os.path.isdir(full):
        shutil.copytree(full, os.path.join(DST, name))
    else:
        shutil.copy2(full, os.path.join(DST, name))

def patch(path, subs):
    p = os.path.join(DST, path)
    s = open(p).read()
    for a, b in subs:
        if a not in s:
            raise SystemExit("patch failed in %s: %r" % (path, a))
        s = s.replace(a, b, 1)
    open(p, "w").write(s)

patch("project.godot", [
    ('config/name="Farm Town"', 'config/name="Farm Town (Web)"'),
    ('PackedStringArray("4.7", "Forward Plus")', 'PackedStringArray("4.6", "GL Compatibility")'),
    ("[rendering]\n", "[farm]\n\nnature_density=0.27\n\n[rendering]\n\nrenderer/rendering_method=\"gl_compatibility\"\n"
                      "renderer/rendering_method.mobile=\"gl_compatibility\"\ntextures/vram_compression/import_etc2_astc=true\n"),
    ("anti_aliasing/quality/screen_space_aa=1\n", ""),
    ("directional_shadow/size=8192", "directional_shadow/size=4096"),
    ("directional_shadow/soft_shadow_filter_quality=4", "directional_shadow/soft_shadow_filter_quality=3"),
    ("positional_shadow/soft_shadow_filter_quality=4", "positional_shadow/soft_shadow_filter_quality=3"),
    ("environment/ssao/quality=3\n", ""),
    ("environment/ssil/quality=2\n", ""),
])
patch("scenes/world/Main.tscn", [
    ("ambient_light_energy = 1\n", "ambient_light_energy = 0.75\n"),
    ("tonemap_exposure = 1\n", "tonemap_exposure = 0.92\n"),
    ("ssao_enabled = true", "ssao_enabled = false"),
    ("ssil_enabled = true", "ssil_enabled = false"),
    ("dof_blur_far_enabled = true", "dof_blur_far_enabled = false"),
])
# Fewer trees + particles on the web.
p = os.path.join(DST, "scenes/world/Main.tscn")
s = open(p).read()
s = re.sub(r'(\[node name="Nature"[^\n]*\n)', r'\1tree_count = 120\nedge_tree_count = 150\n', s, count=1)
s = re.sub(r'(\[node name="SeasonVisuals"[^\n]*\n)', r'\1particle_scale = 0.6\n', s, count=1)
open(p, "w").write(s)
for m in ("skin", "lips"):
    p = os.path.join(DST, "assets/materials/%s.tres" % m)
    s = open(p).read()
    s = re.sub(r"subsurf_scatter_[a-z_]+ = [^\n]+\n", "", s)
    open(p, "w").write(s)
# PERF v7b.1 WEB DIET (web copy only - desktop / native keep the lossless originals):
# 1) every texture -> Lossy WebP inside the pck (NOT VRAM compression: one small file per
#    texture, decoded to RGBA on load, no ETC2+S3TC double set); 3D auto-VRAM switched off.
#    Colour maps q=0.80, normal maps q=0.90. Character textures stay capped at 512 px.
# 2) duplicate hair textures (characters/ and characters/hair/ held identical copies):
#    the two body glTFs now point at the hair/ copies and the duplicates are dropped.
# 3) dev / test-only scripts, native-only icons and docs are kept out of the pck (filter below).
for root, _dirs, files in os.walk(os.path.join(DST, "assets")):
    for f in files:
        if not f.endswith(".import"):
            continue
        ip = os.path.join(root, f)
        s = open(ip).read()
        if 'importer="texture"' not in s or "/icons/" in ip:
            continue
        normal = "_normal" in f.lower()
        s = re.sub(r"compress/mode=\d+", "compress/mode=1", s)
        s = re.sub(r"compress/lossy_quality=[0-9.]+", "compress/lossy_quality=%s" % ("0.9" if normal else "0.8"), s)
        s = re.sub(r"detect_3d/compress_to=\d+", "detect_3d/compress_to=0", s)
        open(ip, "w").write(s)
chars = os.path.join(DST, "assets/third_party/quaternius/characters")
for g, subs in (("Superhero_Male_FullBody.gltf", [("T_Hair_1_Normal_png.png", "hair/T_Hair_1_Normal.png"), ("T_Hair_1_BaseColor.png", "hair/T_Hair_1_BaseColor.png")]),
                ("Superhero_Female_FullBody.gltf", [("T_Hair_2_Normal.png", "hair/T_Hair_2_Normal.png"), ("T_Hair_2_BaseColor.png", "hair/T_Hair_2_BaseColor.png")])):
    gp = os.path.join(chars, g)
    s = open(gp).read()
    for a, b in subs:
        assert '"%s"' % a in s, (g, a)
        s = s.replace('"%s"' % a, '"%s"' % b)
    open(gp, "w").write(s)
for dup in ("T_Hair_1_Normal_png.png", "T_Hair_1_BaseColor.png", "T_Hair_2_Normal.png", "T_Hair_2_BaseColor.png"):
    for ext in ("", ".import"):
        if os.path.exists(os.path.join(chars, dup + ext)):
            os.remove(os.path.join(chars, dup + ext))
WEB_EXCLUDE = ("README.md, *.md, tools/*, devtmp/*, docs/*, server/*, builds/*, scripts/tools/dev_tools.gd, scripts/tools/dev_shots.gd, "
               "scripts/tools/net_test_driver.gd, *_smoke.gd, *_shots.gd, scripts/v7b1_perf/perf_profiler.gd, assets/icons/ios/*, assets/icons/android_*, assets/icons/*.icns, assets/icons/*.ico")
preset = open(os.path.join(SRC, "config/web_export_presets.cfg")).read()
preset = preset.replace('export_path="../farm-prototype-web/index.html"', 'export_path="%s/index.html"' % OUT)
preset = preset.replace('exclude_filter="README.md, *.md, tools/*"', 'exclude_filter="%s"' % WEB_EXCLUDE)
assert WEB_EXCLUDE in preset
assert OUT in preset
# v7b.1: iOS Safari / phones - no page scroll, pinch or double-tap zoom on touch,
# full-screen canvas; a refused pointer lock (mouse look) is logged, not an error.
HEAD = """<meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<style>html,body{overscroll-behavior:none;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;position:fixed;inset:0;overflow:hidden;touch-action:none}#canvas{touch-action:none}</style>
<script>(function(){var p=function(e){e.preventDefault();};
document.addEventListener('gesturestart',p,{passive:false});document.addEventListener('gesturechange',p,{passive:false});
document.addEventListener('dblclick',p,{passive:false});
document.addEventListener('touchmove',function(e){if(e.touches.length>1||e.target===document.body||e.target.id==='canvas'){e.preventDefault();}},{passive:false});
var r=Element.prototype.requestPointerLock;if(r){Element.prototype.requestPointerLock=function(){try{var q=r.apply(this,arguments);if(q&&q.catch){q.catch(function(err){console.log('pointer lock not available: '+(err&&err.name));});}return q;}catch(err){console.log('pointer lock not available');}};}
})();</script>"""
assert 'html/head_include=""' in preset
preset = preset.replace('html/head_include=""', 'html/head_include="%s"' % HEAD.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n"))
open(os.path.join(DST, "export_presets.cfg"), "w").write(preset)
print("web copy ready:", DST)
