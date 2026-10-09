class_name Newspaper
extends Node3D
## v7b "newspaper" module: a newsstand by the square sells the daily paper
## (E). Every morning a new issue is composed from what REALLY happened since
## the last issue (CityState counters + fines ledger + public works,
## WorldMemory reports, TownLife cafe fights / rides / camps / trades) plus
## the market's biggest price movers and a weather line. Read it with 4.
## Issues store both languages, so the language toggle works on old papers.

var panel: NewspaperPanel
var root: Node3D
var stand_spot: ActionSpot
var bought: int = 0
var _sign: Label3D


func style() -> NewspaperStyle:
	return Modules.style("newspaper") as NewspaperStyle


func _ready() -> void:
	rebuild()
	Modules.on_swap("newspaper", self, func(_m: Resource) -> void: rebuild())
	TimeManager.day_started.connect(func(_d: int) -> void: compose())


func rebuild() -> void:
	if root:
		root.queue_free()
		root = null
	var st := style()
	if st == null:
		return
	root = Node3D.new()
	root.name = "Newsstand"
	root.position = V7aKit.ground(st.stand_pos.x, st.stand_pos.y)
	add_child(root)
	var green := V7aKit.mat(Color(0.12, 0.38, 0.26))
	V7aKit.box(root, Vector3(1.8, 1.1, 1.0), Vector3(0, 0.55, 0), green)
	V7aKit.box(root, Vector3(1.9, 0.08, 1.1), Vector3(0, 1.12, 0), V7aKit.mat(Color(0.85, 0.82, 0.72)))
	V7aKit.box(root, Vector3(0.08, 1.2, 0.08), Vector3(-0.85, 1.7, -0.45), green)
	V7aKit.box(root, Vector3(0.08, 1.2, 0.08), Vector3(0.85, 1.7, -0.45), green)
	var aw := V7aKit.box(root, Vector3(2.2, 0.08, 1.5), Vector3(0, 2.35, 0.1), V7aKit.mat(Color(0.85, 0.2, 0.15)))
	aw.rotation.x = -0.18
	# Stacks of papers and a rack.
	for k in 3:
		V7aKit.box(root, Vector3(0.42, 0.06 + k * 0.03, 0.3), Vector3(-0.55 + k * 0.55, 1.18, 0.15), V7aKit.mat(Color(0.93, 0.92, 0.86)), false)
	V7aKit.box(root, Vector3(1.6, 0.9, 0.05), Vector3(0, 1.75, -0.45), V7aKit.mat(Color(0.9, 0.88, 0.8)))
	var body := StaticBody3D.new()
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 1.1, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.55, 0)
	body.add_child(cs)
	_sign = V7bKit.sign(root, Vector3(0, 2.1, -0.38), 0.0, st.paper_fa, st.paper_en, Color(0.12, 0.38, 0.26), 1.7)
	stand_spot = ActionSpot.make(root, Vector3(0, 0, 1.0), 1.7, _spot_text, func(_w: Node3D) -> void: buy())
	stand_spot.name = "NewsstandSpot"


func _spot_text() -> String:
	var st := style()
	var t := Lang.loc_ui("buy today's newspaper")
	if st and st.price > 0:
		t += " (%s %s)" % [V7bKit.num(st.price), Lang.tt("سکه", "G")]
	return t


# ------------------------------------------------------------------ issues
func issue_for(day: int) -> Dictionary:
	for p: Dictionary in TownLife.papers:
		if int(p.get("day", -1)) == day:
			return p
	return {}


func latest() -> Dictionary:
	return TownLife.papers[-1] if not TownLife.papers.is_empty() else {}


func _counts() -> Dictionary:
	return {"fires": CityState.fires, "outages": CityState.outages, "quakes": CityState.quakes,
		"arguments": CityState.arguments, "calmed": CityState.calmed, "reports": WorldMemory.reports.size(),
		"cafe_fights": int(TownLife.cafe.get("fights", 0)), "rides": int(TownLife.rides.get("delivered", 0)),
		"camps": int(TownLife.camps.get("trips", 0)), "trades": int(TownLife.trades.get("player", 0)) + int(TownLife.trades.get("npc", 0)),
		"ledger_day": TimeManager.day}


func _item(items: Array, kind: String, vals: Dictionary) -> void:
	var st := style()
	var e: Dictionary = st.templates.get(kind, {})
	if e.is_empty():
		return
	var en := str(e.get("en", ""))
	var fa := str(e.get("fa", ""))
	for k in vals:
		var v: Variant = vals[k]
		if v is Array:   # [en, fa]
			en = en.replace("{%s}" % k, str(v[0]))
			fa = fa.replace("{%s}" % k, str(v[1]))
		else:
			en = en.replace("{%s}" % k, str(v))
			fa = fa.replace("{%s}" % k, Lang.digits(str(v)) if (v is int or v is float) else str(v))
	items.append({"kind": kind, "en": en, "fa": fa})


static func _fa_item_name(id: String) -> String:
	var it := GameData.item(id)
	if str(it.get("name_fa", "")) != "":
		return str(it["name_fa"])
	var ms := Market.style()
	if ms and ms.item_names_fa.has(id):
		return str(ms.item_names_fa[id])
	return GameData.item_name(id)


## Biggest market movers as [en, fa] (empty if the market was flat).
func market_line() -> Array:
	var moves: Array = []
	for id in Market.history.keys():
		var ch := Market.change_pct(str(id))
		if ch != 0:
			moves.append([absi(ch), str(id), ch])
	if moves.is_empty():
		return []
	moves.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var en: PackedStringArray = []
	var fa: PackedStringArray = []
	for m: Array in moves.slice(0, 3):
		var ch := int(m[2])
		en.append("%s %+d%%" % [GameData.item_name(str(m[1])), ch])
		fa.append("%s %s٪ %s" % [_fa_item_name(str(m[1])), Lang.digits(str(absi(ch))), "گران‌تر" if ch > 0 else "ارزان‌تر"])
	return [", ".join(en), "، ".join(fa)]


## Compose the issue for today (from what happened since the last issue).
## force = recompose today's issue (tests / late news).
func compose(force: bool = false) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	var today := TimeManager.day
	var have := issue_for(today)
	if not have.is_empty() and not force:
		return have
	var base: Dictionary = latest().get("counts", {})
	if not have.is_empty():
		base = have.get("base", {})
		TownLife.papers.erase(have)
	var now := _counts()
	var d := func(k: String) -> int: return maxi(int(now.get(k, 0)) - int(base.get(k, 0)), 0)
	var since := int(base.get("ledger_day", today - 1))
	var items: Array = []
	if d.call("fires") > 0:
		_item(items, "fire", {"n": d.call("fires")})
	if d.call("quakes") > 0:
		_item(items, "quake", {})
	if d.call("outages") > 0:
		_item(items, "outage", {"n": d.call("outages")})
	if d.call("arguments") > 0:
		_item(items, "argument", {"n": d.call("arguments"), "calmed": d.call("calmed")})
	if d.call("cafe_fights") > 0:
		_item(items, "cafe_fight", {"n": d.call("cafe_fights")})
	var fines := 0
	for e: Dictionary in CityState.ledger:
		var k := str(e.get("kind", ""))
		if int(e.get("day", 0)) < since or k in ["tax", "project", "doctor", "income", "repair"] or int(e.get("amount", 0)) <= 0:
			continue
		if fines < 2:
			_item(items, "fine", {"what": [str(e.get("en", k)), str(e.get("fa", k))], "amount": int(e.get("amount", 0))})
		fines += 1
	var cs := CityState.style()
	for id in CityState.projects:
		var p: Dictionary = CityState.projects[id]
		var stt := str(p.get("state", ""))
		if int(p.get("start", -99)) >= since or (stt == "done" and int(p.get("done_day", -99)) >= since):
			var nm := [str(id), str(id)]
			if cs:
				for pp: Dictionary in cs.projects:
					if str(pp.get("id", "")) == str(id):
						nm = [str(pp.get("en", id)), str(pp.get("fa", id))]
			_item(items, "project", {"what": nm, "state": ["done", "تمام شد"] if stt == "done" else ["under construction", "در حال ساخت"]})
	if d.call("reports") > 0:
		_item(items, "report", {"n": d.call("reports")})
	if d.call("rides") > 0:
		_item(items, "rides", {"n": d.call("rides")})
	if d.call("camps") > 0:
		var spot := str(TownLife.camps.get("spot", ""))
		var nm2 := ["the countryside", "طبیعت"]
		var camp_st := Modules.style("camping") as CampingStyle
		if camp_st:
			for s: Dictionary in camp_st.spots:
				if str(s.get("id", "")) == spot:
					nm2 = [str(s.get("en", spot)), str(s.get("fa", spot))]
		_item(items, "camp", {"what": nm2})
	if d.call("trades") > 0:
		_item(items, "trade", {"n": d.call("trades")})
	# v7b.1 traffic: camera catches, impounds, new cars (TrafficState).
	items.append_array(TrafficState.news_items(since))
	var news_n := items.size()
	# Room for the market + fund lines at the end.
	items = items.slice(0, maxi(st.max_items - 2, 1))
	var ml := market_line()
	if not ml.is_empty():
		_item(items, "market", {"what": ml})
	_item(items, "fund", {"amount": CityState.fund})
	var wx: Dictionary = st.weather.get(TimeManager.weather_id, {})
	var issue := {"day": today, "items": items, "quiet": news_n == 0, "weather": {"en": str(wx.get("en", "")), "fa": str(wx.get("fa", ""))},
		"counts": now, "base": base, "date_en": TimeManager.date_text()}
	TownLife.papers.append(issue)
	while TownLife.papers.size() > st.archive:
		TownLife.papers.pop_front()
	TownLife.changed.emit("papers")
	return issue


## E at the newsstand: pay and read today's paper.
func buy() -> bool:
	var st := style()
	if st == null:
		return false
	if TownLife.paper_day != TimeManager.day:
		if Economy.money < st.price:
			GameEvents.notification_requested.emit(Lang.tt("پول کافی برای روزنامه نداری.", "Not enough money for the paper."))
			return false
		Economy.add_money(-st.price)
		TownLife.paper_day = TimeManager.day
		bought += 1
		if st.price > 0:
			CityState.add_income("tax", 1, "Newsstand tax", "مالیات دکه")
	compose()
	if panel:
		panel.open_issue(issue_for(TimeManager.day))
	return true


## Key 4: read today's paper if bought, else the latest one you have.
func read() -> bool:
	if TownLife.paper_day == TimeManager.day:
		compose()
		panel.open_issue(issue_for(TimeManager.day))
		return true
	var st := style()
	if st and st.price == 0:
		return buy()
	if TownLife.paper_day >= 0 and not latest().is_empty():
		var last := issue_for(TownLife.paper_day)
		panel.open_issue(last if not last.is_empty() else latest())
		GameEvents.notification_requested.emit(Lang.tt("این روزنامه‌ی قدیمی است - روزنامه‌ی امروز را از دکه کنار میدان بخر.", "That's an old paper - buy today's at the newsstand by the square."))
		return true
	GameEvents.notification_requested.emit(Lang.tt("روزنامه را از دکه‌ی کنار میدان بخر (E).", "Buy the paper at the newsstand by the square (E)."))
	return false
