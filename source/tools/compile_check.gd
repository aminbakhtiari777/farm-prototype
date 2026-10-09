extends SceneTree
## Compile check for the test gate: loads every GDScript under res:// and
## every module .tres, and fails (exit 1) if any does not compile / load.
## Usage: godot --headless --path . -s res://tools/compile_check.gd

var _bad: PackedStringArray = []
var _count := 0


func _initialize() -> void:
	_walk("res://")
	print("COMPILE CHECK: %d files, %d failed" % [_count, _bad.size()])
	for b in _bad:
		print("  failed: " + b)
	quit(1 if not _bad.is_empty() else 0)


func _walk(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or sub in ["devtmp", "addons"]:
			continue
		_walk(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		if f.ends_with(".gd"):
			_count += 1
			var res: Resource = ResourceLoader.load(path)
			var ok := false
			if res is GDScript:
				ok = (res as GDScript).can_instantiate()
			if not ok:
				_bad.append(path)
		elif f.ends_with(".tres") and dir.begins_with("res://modules"):
			_count += 1
			if ResourceLoader.load(path) == null:
				_bad.append(path)

