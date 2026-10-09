class_name EntrySettings
extends PanelContainer
## Settings screen from the entry menu: language, quality (Low/Medium/High,
## applied by the perf worker via Settings "quality"), volumes (master, music,
## adhan, bells), mouse sensitivity + invert Y (ControlInput reads
## camera_sensitivity / camera_invert_y), touch controls (auto/on/off) and the
## server address/port (written to user://server.cfg, never res://).

signal closed

var _rows: VBoxContainer
var lang_opt: OptionButton
var quality_opt: OptionButton
var touch_opt: OptionButton
var sliders: Dictionary = {}  ## key -> HSlider
var invert_chk: CheckBox
var host_edit: LineEdit
var port_edit: LineEdit
var tls_chk: CheckBox
var _status: Label
var _title: Label

const QUALITY := ["auto", "low", "medium", "high"]
const TOUCH := ["auto", "on", "off"]


func T(fa: String, en: String) -> String:
	return Lang.tt(fa, en)


func _ready() -> void:
	name = "EntrySettings"
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.1, 0.13, 0.1, 0.97), 16, 16))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_rows)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language" and visible:
			_build())


func open() -> void:
	visible = true
	_build()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_font_size_override(&"font_size", 16)
	return l


func _row(text: String, ctl: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	h.add_child(_label(text))
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctl)
	_rows.add_child(h)


func _slider(key: String, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.name = "S_" + key
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(160, 30)
	var v: Variant = Settings.get_value(key)
	s.value = float(v) if v != null else hi * 0.7
	s.value_changed.connect(func(x: float) -> void: Settings.set_value(key, x))
	sliders[key] = s
	return s


func _build() -> void:
	for c in _rows.get_children():
		c.queue_free()
	sliders.clear()
	_title = Label.new()
	_title.text = T("تنظیمات", "Settings")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 28)
	_rows.add_child(_title)
	lang_opt = OptionButton.new()
	lang_opt.add_item("فارسی")
	lang_opt.add_item("English")
	lang_opt.select(0 if Lang.is_fa() else 1)
	lang_opt.item_selected.connect(func(i: int) -> void: Settings.set_value("dialogue_language", "fa" if i == 0 else "en"))
	_row(T("زبان", "Language"), lang_opt)
	quality_opt = OptionButton.new()
	quality_opt.add_item(T("خودکار", "Auto"))
	quality_opt.add_item(T("کم (لپ‌تاپ / گوشی)", "Low (laptop / phone)"))
	quality_opt.add_item(T("متوسط", "Medium"))
	quality_opt.add_item(T("زیاد", "High"))
	quality_opt.select(maxi(0, QUALITY.find(str(Settings.get_value("quality")))))
	quality_opt.item_selected.connect(func(i: int) -> void:
		# Perf layer (auto_lod / world_streamer) applies the preset on Settings.changed.
		Settings.set_value("quality", QUALITY[i]))
	_row(T("کیفیت گرافیک", "Graphics quality"), quality_opt)
	_row(T("صدای کلی", "Master volume"), _slider("volume", 0.0, 1.0, 0.05))
	_row(T("موسیقی", "Music"), _slider("music_volume", 0.0, 1.0, 0.05))
	_row(T("اذان", "Adhan"), _slider("adhan_volume", 0.0, 1.0, 0.05))
	_row(T("ناقوس کلیسا", "Church bells"), _slider("bell_volume", 0.0, 1.0, 0.05))
	_row(T("حساسیت ماوس", "Mouse sensitivity"), _slider("camera_sensitivity", 0.2, 3.0, 0.05))
	invert_chk = CheckBox.new()
	invert_chk.text = T("معکوس عمودی", "Invert Y")
	invert_chk.button_pressed = bool(Settings.get_value("camera_invert_y"))
	invert_chk.toggled.connect(func(on: bool) -> void: Settings.set_value("camera_invert_y", on))
	_row(T("دوربین", "Camera"), invert_chk)
	touch_opt = OptionButton.new()
	touch_opt.add_item(T("خودکار", "Auto"))
	touch_opt.add_item(T("روشن", "On"))
	touch_opt.add_item(T("خاموش", "Off"))
	touch_opt.select(maxi(0, TOUCH.find(str(Settings.get_value("touch_controls")))))
	touch_opt.item_selected.connect(func(i: int) -> void: Settings.set_value("touch_controls", TOUCH[i]))
	_row(T("کنترل لمسی", "Touch controls"), touch_opt)
	var cfg := ServerConfig.load_config()
	host_edit = LineEdit.new()
	host_edit.placeholder_text = "YOUR_SERVER_HOST"
	host_edit.text = "" if cfg.is_placeholder() else cfg.host
	_row(T("آدرس سرور", "Server address"), host_edit)
	port_edit = LineEdit.new()
	port_edit.text = str(cfg.port)
	_row(T("پورت", "Port"), port_edit)
	tls_chk = CheckBox.new()
	tls_chk.text = "wss:// (TLS)"
	tls_chk.button_pressed = cfg.tls
	_row(T("امن", "Secure"), tls_chk)
	var save_btn := Button.new()
	save_btn.text = T("ذخیره‌ی سرور", "Save server")
	save_btn.custom_minimum_size = Vector2(0, 44)
	save_btn.pressed.connect(save_server)
	_rows.add_child(save_btn)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override(&"font_size", 13)
	_rows.add_child(_status)
	var back := Button.new()
	back.name = "Back"
	back.text = T("بازگشت", "Back")
	back.custom_minimum_size = Vector2(0, 46)
	back.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	_rows.add_child(back)


## Writes host/port/tls to user://server.cfg (per device). Returns OK.
func save_server() -> int:
	var cf := ConfigFile.new()
	cf.load(ServerConfig.USER_PATH)
	var h := host_edit.text.strip_edges()
	cf.set_value("server", "host", h if h != "" else ServerConfig.PLACEHOLDER_HOST)
	cf.set_value("server", "port", clampi(int(port_edit.text), 1, 65535) if port_edit.text.is_valid_int() else 9080)
	cf.set_value("server", "tls", tls_chk.button_pressed)
	var err := cf.save(ServerConfig.USER_PATH)
	GameBrand.reload()
	if _status:
		_status.text = T("ذخیره شد (user://server.cfg).", "Saved (user://server.cfg).") if err == OK else T("ذخیره نشد.", "Could not save.")
	return err
