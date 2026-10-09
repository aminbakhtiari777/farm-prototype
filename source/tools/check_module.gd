extends SceneTree
## v5d: checks one module file the way clients will (sanitizer + load as an
## AssetModule of the right type + validate). Used by tools/push_module.py.
## Usage: godot --headless --path . -s res://tools/check_module.gd -- <type> <abs path>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("CHECK MODULE: usage <type> <path>")
		quit(2)
		return
	var type := args[0]
	var path := args[1]
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		print("CHECK MODULE FAIL: cannot read %s" % path)
		quit(1)
		return
	if ModuleManifest.sanitize_tres(bytes.get_string_from_utf8(), type) == "":
		print("CHECK MODULE FAIL: rejected by the sanitizer (sub-resources, scripts or paths outside res://modules/%s/)" % type)
		quit(1)
		return
	var tmp := "user://check_module/%s/%s" % [type, path.get_file()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(tmp.get_base_dir()))
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var err := ModuleManifest.check_module(tmp, type)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	if err != "":
		print("CHECK MODULE FAIL: " + err)
		quit(1)
		return
	print("CHECK MODULE OK: %s (%s, %d bytes, sha256 %s)" % [path, type, bytes.size(), ModuleManifest.sha256_hex(bytes)])
	quit(0)
