class_name PerfOverlay
extends CanvasLayer
## F7 performance overlay (Persian by default, English with the language
## toggle): fps, frame-time p50 / p95 / p99 (last 2 s), draw calls, objects,
## triangles, nodes, lights, sounds, animations, streaming cells, awake
## interiors, video memory and the graphics preset.

var panel: PanelContainer
var label: Label
var _times: PackedFloat32Array = PackedFloat32Array()
var _last_us: int = 0
var _timer: float = 0.0
var stats: Dictionary = {}


func _ready() -> void:
	name = "PerfOverlay"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"perf_overlay")
	panel = PanelContainer.new()
	panel.name = "PerfPanel"
	panel.theme = V6bWorld.ui_theme()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.78)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.position = Vector2(14, 120)
	label = Label.new()
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color", Color(0.85, 1.0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	panel.visible = false
	_last_us = Time.get_ticks_usec()


func toggle() -> void:
	panel.visible = not panel.visible
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F7:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_times.append((now - _last_us) / 1000.0)
	_last_us = now
	if _times.size() > 120:
		_times.remove_at(0)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	_collect()
	if panel.visible:
		_refresh()


func _pct(q: float) -> float:
	if _times.is_empty():
		return 0.0
	var a := _times.duplicate()
	a.sort()
	return a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)]


func _collect() -> void:
	var tree := get_tree()
	var ws := tree.get_first_node_in_group(&"world_streamer") as WorldStreamer
	var is_ := tree.get_first_node_in_group(&"interior_streamer") as InteriorStreamer
	var ab := tree.get_first_node_in_group(&"audio_budget") as AudioBudget
	var an := tree.get_first_node_in_group(&"anim_budget") as AnimBudget
	var lod := tree.get_first_node_in_group(&"auto_lod") as AutoLod
	stats = {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"p50": snappedf(_pct(0.5), 0.1), "p95": snappedf(_pct(0.95), 0.1), "p99": snappedf(_pct(0.99), 0.1),
		"draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"cells": ws.loaded_count() if ws else 0,
		"units_awake": ws.awake_units() if ws else 0, "units": ws.unit_count() if ws else 0,
		"interiors": is_.awake_interiors() if is_ else 0, "interiors_built": InteriorStreamer.built_count,
		"sounds": ab.playing_now if ab else 0, "sounds_paused": ab.paused_count() if ab else 0,
		"anims": an.running if an else 0, "anims_stopped": an.stopped if an else 0,
		"quality": (lod.current_style().id if lod and lod.current_style() else PerfQuality.style_id()),
		"setting": PerfQuality.key(),
	}


func _refresh() -> void:
	if stats.is_empty():
		_collect()
	var s := stats
	var fa := Lang.is_fa()
	var L := func(t: String) -> String: return Lang.loc_ui(t) if fa else t
	var lines := PackedStringArray([
		"%s  —  %s: %s" % [L.call("Performance"), L.call("Quality"), str(s["quality"]) + (" (auto)" if s["setting"] == "auto" else "")],
		"%s %d   %s p50/p95/p99 %.1f / %.1f / %.1f ms" % [L.call("FPS"), int(s["fps"]), L.call("Frame"), s["p50"], s["p95"], s["p99"]],
		"%s %d   %s %d   %s %dk" % [L.call("Draw calls"), s["draw_calls"], L.call("Objects"), s["objects"], L.call("Triangles"), int(s["primitives"]) / 1000],
		"%s %d   %s %.0f MB" % [L.call("Nodes"), s["nodes"], L.call("Video memory"), s["video_mb"]],
		"%s %d  (%d/%d)   %s %d (%d)" % [L.call("Cells loaded"), s["cells"], s["units_awake"], s["units"], L.call("Interiors awake"), s["interiors"], s["interiors_built"]],
		"%s %d (+%d ⏸)   %s %d (+%d ⏸)" % [L.call("Sounds playing"), s["sounds"], s["sounds_paused"], L.call("Animations running"), s["anims"], s["anims_stopped"]],
	])
	var txt := "\n".join(lines)
	label.text = Lang.digits(txt) if fa else txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
