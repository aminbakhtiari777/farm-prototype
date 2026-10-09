class_name Lang
extends RefCounted
## v5b language + font helpers. Dialogue language is Settings
## "dialogue_language" ("fa" = Persian, default; "en" = English toggle in
## Settings). Fonts come from the "fonts" module (FontStyle, Vazirmatn by
## default): `ui_font()` is the default game font with the Persian font as a
## fallback (so English UI keeps its look and Persian shapes right-to-left),
## `bubble_font()` is the Persian font itself (speech bubbles, card, dialogue).

const FA_DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

static var _ui_font: FontVariation
static var _bubble_font: Font
static var _font_id: String = ""


static func code() -> String:
	var v := str(Settings.get_value("dialogue_language")) if Settings else "fa"
	return "en" if v == "en" else "fa"


static func is_fa() -> bool:
	return code() == "fa"


static func style() -> FontStyle:
	return Modules.style("fonts") as FontStyle


static func _refresh() -> void:
	var st := style()
	var sid := st.id if st else ""
	if _ui_font != null and sid == _font_id:
		return
	_font_id = sid
	var reg: Font = load(st.regular_path) as Font if st else null
	var bold: Font = load(st.bold_path) as Font if st else null
	if _ui_font == null:
		_ui_font = FontVariation.new()
	_ui_font.base_font = ThemeDB.fallback_font
	_ui_font.fallbacks = [reg] if reg else []
	_bubble_font = (bold if st and st.bold_bubbles and bold else reg)


## Default UI font + Persian fallback (HUD theme).
static func ui_font() -> Font:
	_refresh()
	return _ui_font


## Persian-capable font for bubbles, card and dialogue (Latin included).
static func bubble_font() -> Font:
	_refresh()
	return _bubble_font if _bubble_font else ThemeDB.fallback_font


static func bold_font() -> Font:
	var st := style()
	var f: Font = load(st.bold_path) as Font if st else null
	return f if f else bubble_font()


## Picks the current language from {"fa": x, "en": y} (x / y may be arrays:
## a random element is returned) - falls back to English.
static func pick(table: Variant, rng: RandomNumberGenerator = null) -> String:
	if table is String:
		return table
	if not (table is Dictionary):
		return ""
	var d: Dictionary = table
	var v: Variant = d.get(code(), d.get("en", ""))
	if v is Array or v is PackedStringArray:
		var a: Array = Array(v)
		if a.is_empty():
			return ""
		var i := rng.randi() % a.size() if rng else randi() % a.size()
		return str(a[i])
	return str(v)


## Persian digits in Persian mode ("08:00" -> "۰۸:۰۰").
static func digits(text: String) -> String:
	if not is_fa():
		return text
	var out := ""
	for ch in text:
		var c := ch.unicode_at(0)
		out += FA_DIGITS[c - 48] if c >= 48 and c <= 57 else ch
	return out


static func hour_text(h: float) -> String:
	var hh := int(floor(h)) % 24
	var mm := int(round((h - floor(h)) * 60.0)) % 60
	return digits("%02d:%02d" % [hh, mm])


## Fills {key} placeholders.
static func fill(text: String, values: Dictionary) -> String:
	var out := text
	for k in values:
		out = out.replace("{%s}" % k, str(values[k]))
	return out


## Applies the Persian-capable font to a Label3D (speech bubble / tag).
static func setup_label3d(l: Label3D, size: int = -1) -> void:
	var st := style()
	l.font = bubble_font()
	if size > 0:
		l.font_size = size
	elif st:
		l.font_size = st.bubble_size
		l.outline_size = st.bubble_outline
	l.text_direction = TextServer.DIRECTION_AUTO
	l.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT


## True when every glyph of `text` exists in the bubble font (no tofu boxes).
static func renders(text: String, font: Font = null) -> bool:
	var f := font if font else bubble_font()
	var ts := TextServerManager.get_primary_interface()
	var rid := ts.create_shaped_text()
	ts.shaped_text_add_string(rid, text, f.get_rids(), 32)
	ts.shaped_text_shape(rid)
	var ok := true
	for g: Dictionary in ts.shaped_text_get_glyphs(rid):
		var ch := text.substr(int(g.get("start", 0)), 1)
		var cp := ch.unicode_at(0) if ch != "" else 32
		var invisible := cp in [0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2066, 0x2067, 0x2068, 0x2069]
		if int(g.get("index", 0)) == 0 and ch.strip_edges() != "" and not invisible:
			ok = false
			break
	ts.free_rid(rid)
	return ok


## Inferred direction of a shaped text (RTL for Persian).
## v5c: "Press E to ..." in the language of the action text (Persian verbs get a
## Persian sentence; older English verbs keep the English one).
static func prompt(key_name: String, action: String) -> String:
	if is_rtl_text(action):
		return "برای %s، کلید %s را بزن" % [action, key_name]
	return "Press %s to %s" % [key_name, action]


static func is_rtl_text(text: String) -> bool:
	var ts := TextServerManager.get_primary_interface()
	var rid := ts.create_shaped_text()
	ts.shaped_text_add_string(rid, text, bubble_font().get_rids(), 32)
	ts.shaped_text_shape(rid)
	var rtl := ts.shaped_text_get_inferred_direction(rid) == TextServer.DIRECTION_RTL
	ts.free_rid(rid)
	return rtl


## Right-to-left UI for Persian: mirrors the layout of `inner` (a container
## INSIDE a positioned panel, so the panel itself keeps its screen anchors)
## and forces RTL paragraphs on every Label / Button (a line that starts with
## "[x]" or "E:" would otherwise be detected as left-to-right).
static func apply_dir(inner: Control) -> void:
	var rtl := is_fa()
	inner.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_INHERITED
	var dir := Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_AUTO
	for n in inner.find_children("*", "Label", true, false):
		(n as Label).text_direction = dir
	for n in inner.find_children("*", "Button", true, false):
		(n as Button).text_direction = dir


# ------------------------------------------------------------------ v6a UI text
## Translation table module ("ui_text": UiTextStyle, English -> Persian).
static func ui_text() -> UiTextStyle:
	return Modules.style("ui_text") as UiTextStyle


## A fixed UI string in the current language (English key -> Persian from the
## ui_text module; English, or `fa` when given, otherwise).
static func t(en: String, fa: String = "") -> String:
	if not is_fa():
		return en
	if fa != "":
		return fa
	var st := ui_text()
	if st and st.phrases.has(en):
		return str(st.phrases[en])
	return en


## Two-language literal: fa in Persian mode, en otherwise.
static func tt(fa: String, en: String) -> String:
	return fa if is_fa() else en


## Localizes an English action phrase ("open the door", "sit on the bench") for
## prompts. Persian phrases and unknown English pass through unchanged.
static func loc(action: String) -> String:
	if not is_fa() or action == "" or is_rtl_text(action):
		return action
	var st := ui_text()
	if st == null:
		return action
	if st.phrases.has(action):
		return str(st.phrases[action])
	for pre: String in st.prefixes:
		if action.begins_with(pre):
			var rest := action.substr(pre.length())
			var word := str(st.words.get(rest.to_lower(), rest))
			return str(st.prefixes[pre]).replace("{x}", word)
	return action


## v6a: UI labels like "Sound: On (M)" or "Save slot: x (empty)" - whole
## phrase first, else "label: value (key)" piece by piece (ui_text module).
static func loc_ui(text: String) -> String:
	if not is_fa() or text == "" or is_rtl_text(text):
		return text
	var st := ui_text()
	if st == null:
		return text
	if st.phrases.has(text):
		return str(st.phrases[text])
	var key := ""
	var body := text
	var k := body.rfind(" (")
	if k > 0 and body.ends_with(")"):
		key = body.substr(k)
		body = body.substr(0, k)
		var inner := key.substr(2, key.length() - 3)
		if st.phrases.has(inner):
			key = " (%s)" % str(st.phrases[inner])
	if st.phrases.has(body):
		return str(st.phrases[body]) + key
	var c := body.find(": ")
	if c > 0:
		var left := body.substr(0, c)
		var right := body.substr(c + 2)
		return "%s: %s%s" % [str(st.phrases.get(left, left)), str(st.phrases.get(right, right)), key]
	return loc(body) + key


## Season name in the current language.
static func season_name(index: int = -1) -> String:
	var i := TimeManager.season_index() if index < 0 else index
	var en := str(GameData.season(i).get("name", "Spring"))
	return t(en)


## Top-bar date ("Spring 3" / "بهار ۳").
static func date_text() -> String:
	if not is_fa():
		return TimeManager.date_text()
	return "%s %s" % [season_name(), digits(str(TimeManager.day_of_season()))]


## Clock ("08:30 AM" / "۰۸:۳۰ صبح").
static func clock_text() -> String:
	if not is_fa():
		return TimeManager.clock_text()
	var h := TimeManager.hour()
	var part := "بامداد" if h < 5 else ("صبح" if h < 12 else ("ظهر" if h < 14 else ("عصر" if h < 19 else "شب")))
	return "%s %s" % [digits("%02d:%02d" % [h, TimeManager.minute()]), part]
