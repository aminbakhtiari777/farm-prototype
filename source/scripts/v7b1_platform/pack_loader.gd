extends Node
## v7b.1 PackLoader (autoload, FIRST in the list): mounts installed update packs
## (user://updates/*.pck, listed in user://updates/installed.json) before any other
## autoload or the main scene loads, so later scripts/resources come from the newest
## pack. Native only; the web build always loads the latest index.pck from the site.
## Self-contained on purpose (no class_name dependencies).
##
## Also usable by the perf worker's split resource packs: PackLoader.mount(path).

const DIR := "user://updates"
const LIST := "user://updates/installed.json"

var mounted: Array = []  ## [{file, version, ok}]
var installed_version: String = ""


func _init() -> void:
	if OS.has_feature("web"):
		return
	for a in OS.get_cmdline_user_args():
		if a == "--no-update-packs":
			return
	if not FileAccess.file_exists(LIST):
		return
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	if not (v is Dictionary):
		return
	installed_version = str((v as Dictionary).get("version", ""))
	for e in (v as Dictionary).get("packs", []):
		var f := "%s/%s" % [DIR, str(e.get("file", ""))]
		var ok := FileAccess.file_exists(f) and ProjectSettings.load_resource_pack(f, true)
		mounted.append({"file": f, "version": str(e.get("version", "")), "ok": ok})
		if ok:
			print("PackLoader: mounted ", f)
		else:
			push_warning("PackLoader: could not mount %s (kept playing base)" % f)


## Mount an extra pack at runtime (perf streaming packs / freshly downloaded update).
func mount(path: String, replace_files: bool = true) -> bool:
	var ok := ProjectSettings.load_resource_pack(path, replace_files)
	mounted.append({"file": path, "version": "", "ok": ok})
	return ok


## Record a verified, downloaded pack so it mounts at the next start.
func register_installed(file_name: String, version: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var data := {"version": version, "packs": []}
	if FileAccess.file_exists(LIST):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST))
		if v is Dictionary:
			data = v
	var packs: Array = data.get("packs", [])
	packs.append({"file": file_name, "version": version})
	data["packs"] = packs
	data["version"] = version
	var f := FileAccess.open(LIST, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


## Roll back: forget all installed packs (base pck only at next start).
func clear_installed() -> void:
	if FileAccess.file_exists(LIST):
		DirAccess.remove_absolute(LIST)
