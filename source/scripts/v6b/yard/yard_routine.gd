class_name YardRoutine
extends Node3D
## v6b "yard_routine" module: a small daily checklist of farm-yard jobs
## (water the garden, tidy / stack the boxes, pen the sheep, dig in the yard).
## A compact list shows on the right while you are around the farm; finish
## all of them for a small daily bonus (money + stamina). Progress is saved
## (WorldMemory.routine) and starts fresh every morning.

var panel: PanelContainer
var _list: VBoxContainer
var _title: Label
var completed_days: int = 0
signal task_done(id: String)
signal all_done


func style() -> YardRoutineStyle:
	return Modules.style("yard_routine") as YardRoutineStyle


func _ready() -> void:
	add_to_group(&"yard_routine")
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	panel = PanelContainer.new()
	panel.name = "YardRoutinePanel"
	panel.theme = V6bWorld.ui_theme()   # Persian glyphs on the web too
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.12, 0.1, 0.08, 0.62), 8, 8))
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-250, -40)
	panel.custom_minimum_size = Vector2(236, 0)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	_title = UIKit.label(v, "", 15, Color(1.0, 0.9, 0.6))
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_list)
	TimeManager.day_started.connect(func(_d: int) -> void: _new_day())
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "all":
			_refresh())
	Settings.changed.connect(func(_k: String, _v: Variant) -> void: _refresh())
	_hook.call_deferred()
	_refresh()


func _hook() -> void:
	var plot := get_tree().get_first_node_in_group(&"farm_plot")
	if plot and plot.has_signal(&"watered_beds"):
		plot.connect(&"watered_beds", func(_n: int) -> void: mark("water"))
	var pu := get_tree().get_first_node_in_group(&"pushables") as Pushables
	if pu:
		pu.box_moved.connect(func(_i: int, _s: bool) -> void:
			if pu.tallest_stack() >= 2:
				mark("stack"))
	var hd := get_tree().get_first_node_in_group(&"herding") as Herding
	if hd:
		hd.penned.connect(func(_n: int) -> void: mark("herd"))
	var dg := get_tree().get_first_node_in_group(&"digging") as Digging
	if dg:
		dg.dug_hole.connect(func(p: Vector3, _f: String) -> void:
			if Vector2(p.x, p.z).length() < 40.0:
				mark("dig"))


func _today() -> Dictionary:
	if int(WorldMemory.routine.get("day", -1)) != TimeManager.day:
		WorldMemory.routine = {"day": TimeManager.day, "done": {}, "rewarded": false}
	return WorldMemory.routine


func _new_day() -> void:
	_today()
	_refresh()


func is_done(id: String) -> bool:
	return bool((_today().get("done", {}) as Dictionary).get(id, false))


func done_count() -> int:
	return (_today().get("done", {}) as Dictionary).size()


func mark(id: String) -> void:
	var st := style()
	if st == null or is_done(id):
		return
	var known := false
	for t: Dictionary in st.tasks:
		if str(t.get("id", "")) == id:
			known = true
	if not known:
		return
	var r := _today()
	(r["done"] as Dictionary)[id] = true
	WorldMemory.changed.emit("routine")
	task_done.emit(id)
	if done_count() >= st.tasks.size() and not bool(r.get("rewarded", false)):
		r["rewarded"] = true
		completed_days += 1
		Economy.add_money(st.reward)
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p:
			p.restore_stamina(st.stamina_bonus)
		GameEvents.notification_requested.emit(Lang.tt("کارهای حیاط امروز تمام شد! +%s سکه و انرژی" % Lang.digits(str(st.reward)), "Yard jobs done for today! +%d G and a stamina boost" % st.reward))
		all_done.emit()
	_refresh()


func _refresh() -> void:
	var st := style()
	if panel == null:
		return
	if st == null:
		panel.visible = false
		return
	for c in _list.get_children():
		c.queue_free()
	_title.text = Lang.tt("کارهای امروز حیاط (%s/%s)" % [Lang.digits(str(done_count())), Lang.digits(str(st.tasks.size()))], "Today's yard jobs (%d/%d)" % [done_count(), st.tasks.size()])
	for t: Dictionary in st.tasks:
		var ok := is_done(str(t.get("id", "")))
		var txt := str(t.get("fa" if Lang.is_fa() else "en", ""))
		UIKit.label(_list, "• " + txt + (Lang.tt(" (انجام شد)", " (done)") if ok else ""), 13, Color(0.6, 0.95, 0.6) if ok else Color(0.95, 0.93, 0.88))


func _process(_delta: float) -> void:
	if panel == null:
		return
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	var near_farm := p != null and Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(-8.0, 0.0)) < 40.0
	panel.visible = style() != null and near_farm and not GameEvents.ui_open
