class_name PriceBoard
extends Node3D
## v5c market-prices board at the market entrance (module "price_board").
## Lists today's prices of the board goods with the change since yesterday
## (red = up, green = down, "!" = shortage); E opens the full PricesPanel.

var _rows: Array[Label3D] = []
var _title: Label3D
var _dirty: bool = true
var zone: Interactable


func _ready() -> void:
	add_to_group(&"price_board")
	_build()
	Market.prices_changed.connect(func() -> void: _dirty = true)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			_dirty = true)
	Modules.on_swap("price_board", self, func(_m: AssetModule) -> void: _build())


func style() -> PriceBoardStyle:
	return Modules.style("price_board") as PriceBoardStyle


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_rows.clear()
	var st := style()
	if st == null:
		return
	position = Vector3(st.position.x, Terrain.height_at(st.position.x, st.position.y), st.position.y)
	rotation.y = deg_to_rad(st.yaw_deg)
	var bw := 3.0
	var bh := 1.9
	var base_y := 1.0
	for sx in [-bw * 0.5 - 0.06, bw * 0.5 + 0.06]:
		FarmAnimal.box(self, Vector3(0.12, base_y + bh + 0.2, 0.12), Vector3(sx, (base_y + bh + 0.2) * 0.5, 0), st.frame_color)
	FarmAnimal.box(self, Vector3(bw + 0.24, bh + 0.2, 0.08), Vector3(0, base_y + bh * 0.5, -0.02), st.frame_color)
	var face := FarmAnimal.box(self, Vector3(bw, bh, 0.04), Vector3(0, base_y + bh * 0.5, 0.03), st.bg_color)
	face.name = "Face"
	FarmAnimal.box(self, Vector3(bw + 0.5, 0.12, 0.3), Vector3(0, base_y + bh + 0.16, 0.05), st.frame_color.darkened(0.2))
	_title = _label(Vector3(0, base_y + bh - 0.17, 0.06), 46, st.ink_color)
	var rows := st.board_rows
	for i in rows:
		var l := _label(Vector3(0, base_y + bh - 0.42 - i * 0.18, 0.06), 29, st.ink_color)
		_rows.append(l)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(bw + 0.4, base_y + bh, 0.3)
	cs.shape = bx
	body.position = Vector3(0, (base_y + bh) * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	zone = Interactable.new()
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.position = Vector3(0, 0.9, 1.0)
	var zs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.8
	zs.shape = sp
	zone.add_child(zs)
	add_child(zone)
	zone.interacted.connect(func(_who: Node3D) -> void: GameEvents.ui_panel_requested.emit("prices"))
	_dirty = true


func _label(pos: Vector3, size: int, c: Color) -> Label3D:
	var l := Label3D.new()
	Lang.setup_label3d(l, size)
	l.pixel_size = 0.0042
	l.outline_size = 0
	l.modulate = c
	l.position = pos
	l.width = 680.0
	add_child(l)
	return l


func _process(_delta: float) -> void:
	if _dirty and is_inside_tree():
		_dirty = false
		refresh()


func lines() -> PackedStringArray:
	var out := PackedStringArray()
	var st := style()
	if st == null:
		return out
	for id in st.items:
		if GameData.item(id).is_empty() or not Market.is_tracked(id):
			continue
		var ch := Market.change_pct(id)
		var short := Market.is_shortage(id)
		var trend := ("کمبود!" if Lang.is_fa() else "SHORT!") if short else Market.trend_text(ch, false)
		if Lang.is_fa():
			out.append("%s  %s سکه  %s" % [Market.local_name(id), Lang.digits(str(Market.buy_price(id))), trend])
		else:
			out.append("%s  %d G  %s" % [Market.local_name(id), Market.buy_price(id), trend])
	return out


func refresh() -> void:
	var st := style()
	if st == null or _title == null:
		return
	zone.set_action_text("دیدن تابلوی قیمت‌ها" if Lang.is_fa() else "read the market prices board")
	_title.text = st.title_fa if Lang.is_fa() else st.title_en
	var ls := lines()
	var ids: Array = []
	for id in st.items:
		if not GameData.item(id).is_empty() and Market.is_tracked(id):
			ids.append(id)
	for i in _rows.size():
		var l := _rows[i]
		if i < ls.size():
			l.text = ls[i]
			var id: String = ids[i]
			var ch := Market.change_pct(id)
			l.modulate = st.shortage_color if Market.is_shortage(id) else (st.up_color if ch > 0 else (st.down_color if ch < 0 else st.ink_color))
		else:
			l.text = ""
