class_name V7bKit
extends RefCounted
## Shared helpers for the v7b modules: clearing scattered trees under a new
## structure, small chatter bubbles (with the resident's voice), text tables
## ({en, fa} picks with placeholders), a standing UI panel style, and simple
## signs. Geometry helpers come from V7aKit.


## Hides scattered trees / grass inside `rect` (xz) and disables their
## collision - new structures (terrace, garage, kiosk) are built on top.
static func clear_trees(tree: SceneTree, rect: Rect2) -> int:
	var scene := tree.current_scene
	if scene == null:
		return 0
	var nature := scene.get_node_or_null(^"Nature")
	if nature == null:
		return 0
	var n := 0
	for c in nature.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi and mmi.multimesh:
			var mm := mmi.multimesh
			for i in mm.instance_count:
				var xf := mm.get_instance_transform(i)
				var o := mmi.global_transform * xf.origin
				if rect.has_point(Vector2(o.x, o.z)) and xf.basis.get_scale().x > 0.001:
					mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
					n += 1
	var body := nature.get_node_or_null(^"TreeCollision")
	if body:
		for s in body.get_children():
			var cs := s as CollisionShape3D
			if cs and rect.has_point(Vector2(cs.global_position.x, cs.global_position.z)):
				cs.disabled = true
	return n


## A small, unobtrusive speech bubble above a resident (separate from the
## main dialogue bubble) + voice blips. Used by chatter, cafe, passengers.
static func say_small(bot: Node3D, text: String, seconds: float = 3.6, font: int = 34) -> Label3D:
	if bot == null or not is_instance_valid(bot) or text == "":
		return null
	var l := bot.get_node_or_null(^"ChatBubble") as Label3D
	if l == null:
		l = Label3D.new()
		l.name = "ChatBubble"
		Lang.setup_label3d(l, font)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.0042
		l.outline_size = 10
		l.outline_modulate = Color(0.08, 0.08, 0.1, 0.85)
		l.modulate = Color(1.0, 0.98, 0.9)
		l.no_depth_test = false
		l.width = 520.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector3(0, 2.35, 0)
		bot.add_child(l)
	l.font_size = font
	l.text = text
	l.visible = true
	l.set_meta(&"t", seconds)
	var tw: Tween = l.get_meta(&"tween") as Tween if l.has_meta(&"tween") else null
	if tw and tw.is_valid():
		tw.kill()
	tw = l.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(func() -> void: l.visible = false)
	l.set_meta(&"tween", tw)
	if bot is TownspersonBot and not (bot as TownspersonBot).hidden_inside and bot.is_inside_tree():
		var vb := VoiceBlips.instance(bot.get_tree())
		if vb:
			vb.speak(bot, text)
	return l


static func small_text(bot: Node3D) -> String:
	var l := bot.get_node_or_null(^"ChatBubble") as Label3D if bot else null
	return l.text if l and l.visible else ""


## Picks an {en, fa} entry and fills {placeholders}.
static func line(table: Variant, values: Dictionary = {}, rng: RandomNumberGenerator = null) -> String:
	# v7b tables are [{en, fa}, ...]; older ones {fa: [...], en: [...]} or a String.
	if table is Array:
		var a: Array = table
		if a.is_empty():
			return ""
		var e: Variant = a[rng.randi() % a.size() if rng else randi() % a.size()]
		if e is Dictionary:
			var pair := both(e, values)
			return str(pair[1]) if Lang.is_fa() else str(pair[0])
		table = str(e)
	var t := Lang.pick(table, rng)
	for k in values:
		t = t.replace("{%s}" % k, str(values[k]))
	return t


## Both languages of one {en, fa} entry with placeholders filled (chat log).
static func both(entry: Dictionary, values: Dictionary = {}) -> Array:
	var en := str(entry.get("en", ""))
	var fa := str(entry.get("fa", ""))
	for k in values:
		var v: Variant = values[k]
		en = en.replace("{%s}" % k, str(v))
		fa = fa.replace("{%s}" % k, Lang.digits(str(v)) if v is int else str(v))
	return [en, fa]


static func num(v: int) -> String:
	return Lang.digits(str(v)) if Lang.is_fa() else str(v)


## A standing sign (board on two posts) with a Persian / English label.
static func sign(parent: Node3D, pos: Vector3, yaw: float, fa: String, en: String, color: Color, width: float = 2.6) -> Label3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	var post := V7aKit.mat(Color(0.25, 0.22, 0.2))
	for sx in [-width * 0.42, width * 0.42]:
		V7aKit.box(holder, Vector3(0.08, 2.2, 0.08), Vector3(sx, 1.1, 0), post)
	V7aKit.box(holder, Vector3(width, 0.7, 0.08), Vector3(0, 1.95, 0), color)
	var l := Label3D.new()
	Lang.setup_label3d(l, 64)
	l.pixel_size = 0.0055
	l.outline_size = 8
	l.modulate = Color(1, 1, 1)
	l.position = Vector3(0, 1.95, 0.06)
	l.text = Lang.tt(fa, en)
	l.set_meta(&"fa", fa)
	l.set_meta(&"en", en)
	l.add_to_group(&"v7b_signs")
	holder.add_child(l)
	return l


static func refresh_signs(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(&"v7b_signs"):
		var l := n as Label3D
		if l:
			l.text = Lang.tt(str(l.get_meta(&"fa", "")), str(l.get_meta(&"en", "")))


static func player(tree: SceneTree) -> Player:
	return tree.get_first_node_in_group(&"player") as Player


## A centered panel on its own CanvasLayer, themed with the Persian fallback font.
static func panel(parent: Node, nm: String, size: Vector2, bg: Color = Color(0.1, 0.12, 0.15, 0.95)) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = nm
	p.theme = V6bWorld.ui_theme()
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override(&"panel", UIKit.style(bg, 14, 18, true))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = size
	p.offset_left = -size.x * 0.5
	p.offset_right = size.x * 0.5
	p.offset_top = -size.y * 0.5
	p.offset_bottom = size.y * 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(p)
	return p


static func clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## The controller to hand a bot back to after a scripted v7b moment.
static func original_of(sc: V7aKit.ScriptController) -> BotController:
	var o: BotController = sc.original
	while o is V7aKit.ScriptController and (o as V7aKit.ScriptController).original:
		if o is Possession.PossessController:
			break
		o = (o as V7aKit.ScriptController).original
	return o if o else V7aKit.ScriptController.new()
