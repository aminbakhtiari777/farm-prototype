class_name ModuleManifest
extends RefCounted
## v5d live modular updates (module "live_updates").
## A manifest is {"format":1,"modules":{type:{"version":N,"active":id,
##   "files":{vid:{"path","sha256","bytes"}}}}}.
## The client's local manifest starts as res://data/module_manifest.json (the
## built-in modules) and is overlaid by downloaded updates, persisted in
## user://updates/ (and browser localStorage on the web). Each update is
## verified (type allowed, size, sha256, sanitizer, loads as an AssetModule of
## the right type) BEFORE it is swapped in through the AssetRegistry, so a bad
## update never replaces the working module. rollback(type) goes back to the
## previous installed version (or the built-in one).

const BUILTIN := "res://data/module_manifest.json"
const LOCAL_DIR := "user://updates"
const LOCAL_PATH := "user://updates/manifest.json"
const WEB_KEY := "farm_prototype_manifest"
const WEB_FILE_PREFIX := "farm_mod_"

## Last install / rollback log lines (UI + tests).
static var history: Array = []


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func style() -> LiveUpdatesStyle:
	return Modules.style("live_updates") as LiveUpdatesStyle


static func _registry() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(^"AssetRegistry") if loop and loop.root else null


static func _parse(text: String) -> Dictionary:
	var v: Variant = JSON.parse_string(text) if text != "" else null
	return v if v is Dictionary else {}


static func load_builtin() -> Dictionary:
	var f := FileAccess.open(BUILTIN, FileAccess.READ)
	return _parse(f.get_as_text()) if f else {}


## Installed updates only: {"modules": {type: info + "local": {vid: path}, "previous": info|null}}.
static func load_installed() -> Dictionary:
	if OS.has_feature("web") and WebStorage.has_item(WEB_KEY):
		var w := _parse(WebStorage.get_item(WEB_KEY))
		if not w.is_empty():
			return w
	if FileAccess.file_exists(LOCAL_PATH):
		var f := FileAccess.open(LOCAL_PATH, FileAccess.READ)
		if f:
			return _parse(f.get_as_text())
	return {"modules": {}}


static func save_installed(man: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOCAL_DIR))
	var f := FileAccess.open(LOCAL_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(man, "\t"))
		f.close()
	if OS.has_feature("web"):
		WebStorage.set_item(WEB_KEY, JSON.stringify(man))


## Built-in manifest overlaid by installed updates (what this client runs).
static func effective() -> Dictionary:
	var out := load_builtin()
	if not out.has("modules"):
		out["modules"] = {}
	var inst: Dictionary = load_installed().get("modules", {})
	for t in inst:
		var info: Dictionary = (inst[t] as Dictionary).duplicate(true)
		info.erase("local")
		info.erase("previous")
		(out["modules"] as Dictionary)[t] = info
	return out


## Types whose version, active variant or files differ, and that the remote
## has at a HIGHER version (a server never downgrades a client).
static func diff(local: Dictionary, remote: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var lm: Dictionary = local.get("modules", {})
	var rm: Dictionary = remote.get("modules", {})
	for t in rm:
		var a: Dictionary = lm.get(t, {})
		var b: Dictionary = rm[t]
		if int(b.get("version", 0)) > int(a.get("version", 0)):
			out.append(str(t))
	out.sort()
	return out


## Files of `type` that actually changed (sha differs) - only these download.
static func changed_files(type: String, local: Dictionary, remote: Dictionary) -> PackedStringArray:
	var a: Dictionary = ((local.get("modules", {}) as Dictionary).get(type, {}) as Dictionary).get("files", {})
	var b: Dictionary = ((remote.get("modules", {}) as Dictionary).get(type, {}) as Dictionary).get("files", {})
	var out := PackedStringArray()
	for vid in b:
		if str((a.get(vid, {}) as Dictionary).get("sha256", "")) != str((b[vid] as Dictionary).get("sha256", "")):
			out.append(str(vid))
	out.sort()
	return out


static func allowed(type: String, st: LiveUpdatesStyle = null) -> bool:
	if st == null:
		st = style()
	if st == null or not st.enabled:
		return false
	if type in st.blocked_types:
		return false
	return "*" in st.allowed_types or type in st.allowed_types


## Accepts only a plain module Resource: a gd_resource header, ext_resources
## under res://modules/<type>/ or res://assets/, no sub_resources / nodes /
## embedded scripts. Returns "" when rejected.
static func sanitize_tres(text: String, type: String) -> String:
	if not text.begins_with("[gd_resource"):
		return ""
	for bad in ["[sub_resource", "[node ", "GDScript", "source_code", "script/source", "PackedScene"]:
		if text.find(bad) >= 0:
			return ""
	var has_script := false
	for line in text.split("\n"):
		if line.begins_with("[ext_resource"):
			var i := line.find('path="')
			if i < 0:
				return ""
			var p := line.substr(i + 6, line.find('"', i + 6) - i - 6)
			if p.begins_with("res://modules/%s/" % type) and p.ends_with(".gd"):
				has_script = true
			elif not p.begins_with("res://assets/"):
				return ""
	return text if has_script else ""


static func _file_path(type: String, vid: String, version: int) -> String:
	return "%s/%s/%s.v%d.tres" % [LOCAL_DIR, type, vid, version]


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	if OS.has_feature("web"):
		WebStorage.set_item(WEB_FILE_PREFIX + path.md5_text(), Marshalls.raw_to_base64(bytes))
	return true


## Makes sure a persisted file exists in user:// (web: restored from localStorage).
static func _ensure_file(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	if OS.has_feature("web"):
		var b64 := WebStorage.get_item(WEB_FILE_PREFIX + path.md5_text())
		if b64 != "":
			var bytes := Marshalls.base64_to_raw(b64)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()
				return true
	return false


static func _remove(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if OS.has_feature("web"):
		WebStorage.remove_item(WEB_FILE_PREFIX + path.md5_text())


## Loads a module file and checks it is an AssetModule of `type` that validates.
static func check_module(path: String, type: String) -> String:
	var mod := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AssetModule
	if mod == null:
		return "does not load as an AssetModule"
	if mod.type != type:
		return "type is '%s', expected '%s'" % [mod.type, type]
	var missing := mod.validate()
	if not missing.is_empty():
		return "missing assets: %s" % ", ".join(missing)
	return ""


## History entries: {"kind": updated|rejected|rolled_back, "type", "version", "detail", "en"}.
static func _log(line: String, entry: Dictionary = {}) -> void:
	entry["en"] = line
	history.append(entry)
	if history.size() > 40:
		history.pop_front()
	print("ModuleManifest: " + line)


## Installs one module type. `info` is the remote modules[type] entry and
## `bodies` the downloaded files {vid: PackedByteArray} (only changed ones;
## unchanged variants keep their current file). Returns {"ok", "error", "swapped"}.
## Nothing is swapped unless every file passes - the old version stays active.
static func install(type: String, info: Dictionary, bodies: Dictionary, st: LiveUpdatesStyle = null) -> Dictionary:
	if st == null:
		st = style()
	var fail := func(msg: String, written: Array) -> Dictionary:
		for p in written:
			_remove(p)
		_log("update %s v%d REJECTED (%s) - kept the current version" % [type, int(info.get("version", 0)), msg],
			{"kind": "rejected", "type": type, "version": int(info.get("version", 0)), "detail": msg})
		return {"ok": false, "error": msg, "swapped": []}
	if not allowed(type, st):
		return fail.call("type not allowed", [])
	var reg := _registry()
	if reg == null:
		return fail.call("no AssetRegistry", [])
	var version := int(info.get("version", 0))
	var files: Dictionary = info.get("files", {})
	var installed := load_installed()
	var mods: Dictionary = installed.get("modules", {})
	var prev_entry: Dictionary = mods.get(type, {})
	var prev_local: Dictionary = prev_entry.get("local", {})
	var new_local := {}
	var written: Array = []
	for vid: String in files:
		var meta: Dictionary = files[vid]
		if bodies.has(vid):
			var body: PackedByteArray = bodies[vid]
			if body.size() > st.max_file_bytes:
				return fail.call("%s too large" % vid, written)
			if sha256_hex(body) != str(meta.get("sha256", "")):
				return fail.call("%s sha256 mismatch" % vid, written)
			if sanitize_tres(body.get_string_from_utf8(), type) == "":
				return fail.call("%s rejected by the sanitizer" % vid, written)
			var dest := _file_path(type, vid, version)
			if not _write_bytes(dest, body):
				return fail.call("cannot write %s" % dest, written)
			written.append(dest)
			var err := check_module(dest, type)
			if err != "":
				return fail.call("%s %s" % [vid, err], written)
			new_local[vid] = dest
		elif prev_local.has(vid):
			new_local[vid] = prev_local[vid]
		else:
			new_local[vid] = str(meta.get("path", ""))  # unchanged built-in file
			if not ResourceLoader.exists(new_local[vid]):
				return fail.call("%s has no body and no local copy" % vid, written)
	var swapped: Array = []
	for vid: String in new_local:
		if not reg.call("register_variant", type, vid, new_local[vid]):
			return fail.call("registry refused %s" % vid, written)
		swapped.append(vid)
	var active := str(info.get("active", ""))
	if active != "" and new_local.has(active):
		reg.call("set_active", type, active)
	var entry := info.duplicate(true)
	entry["local"] = new_local
	var prev_copy := prev_entry.duplicate(true)
	prev_copy.erase("previous")
	entry["previous"] = prev_copy if not prev_copy.is_empty() else null
	mods[type] = entry
	installed["modules"] = mods
	save_installed(installed)
	_log("updated %s to v%d (%s)" % [type, version, ", ".join(PackedStringArray(swapped))],
		{"kind": "updated", "type": type, "version": version, "detail": ", ".join(PackedStringArray(swapped))})
	return {"ok": true, "error": "", "swapped": swapped}


## Back to the previous installed version of `type` (or the built-in one).
static func rollback(type: String, reason: String = "") -> bool:
	var reg := _registry()
	if reg == null:
		return false
	var installed := load_installed()
	var mods: Dictionary = installed.get("modules", {})
	var entry: Dictionary = mods.get(type, {})
	var prev: Variant = entry.get("previous", null)
	var target: Dictionary
	if prev is Dictionary and not (prev as Dictionary).is_empty():
		target = prev
		mods[type] = target
	else:
		target = ((load_builtin().get("modules", {}) as Dictionary).get(type, {}) as Dictionary).duplicate(true)
		mods.erase(type)
		var loc := {}
		for vid in target.get("files", {}):
			loc[vid] = str(target["files"][vid].get("path", ""))
		target["local"] = loc
	var loc2: Dictionary = target.get("local", {})
	for vid: String in loc2:
		reg.call("register_variant", type, vid, str(loc2[vid]))
	if str(target.get("active", "")) != "":
		reg.call("set_active", type, str(target["active"]))
	installed["modules"] = mods
	save_installed(installed)
	_log("rolled back %s to v%d%s" % [type, int(target.get("version", 1)), (" (" + reason + ")") if reason != "" else ""],
		{"kind": "rolled_back", "type": type, "version": int(target.get("version", 1)), "detail": reason})
	return true


## Loads every previously downloaded module at startup. A module that no
## longer loads is rolled back (previous version or built-in). Returns the
## number of types applied.
static func apply_persisted() -> int:
	var reg := _registry()
	if reg == null:
		return 0
	var installed := load_installed()
	var n := 0
	for t: String in (installed.get("modules", {}) as Dictionary).keys():
		var entry: Dictionary = installed["modules"][t]
		var ok := true
		var loc: Dictionary = entry.get("local", {})
		for vid: String in loc:
			var p := str(loc[vid])
			if p.begins_with("user://") and (not _ensure_file(p) or check_module(p, t) != ""):
				ok = false
				break
		if not ok:
			rollback(t, "stored update failed to load")
			continue
		for vid: String in loc:
			reg.call("register_variant", t, vid, str(loc[vid]))
		if str(entry.get("active", "")) != "":
			reg.call("set_active", t, str(entry["active"]))
		n += 1
	return n


## Forget every downloaded update (tests / "reset updates" button).
static func clear_installed() -> void:
	var installed := load_installed()
	for t in installed.get("modules", {}):
		for vid in (installed["modules"][t] as Dictionary).get("local", {}):
			var p := str(installed["modules"][t]["local"][vid])
			if p.begins_with("user://"):
				_remove(p)
	save_installed({"modules": {}})
