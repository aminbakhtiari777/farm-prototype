class_name LoadingScreen
extends Control
## Loading screen with a progress bar + Persian/English tips.
## Progress source (first that applies):
##   1. a threaded ResourceLoader request (Boot scene in native builds),
##   2. the perf worker's streamer: any node in group "world_streamer" exposing
##      load_progress() -> float (0..1) (nearby chunks / resource packs),
##   3. a short warm-up (first frames compile shaders / settle the town).

signal finished
signal retry_requested

const TIPS := [
	["با E با مردم حرف بزن؛ هر کس شخصیت و داستان خودش را دارد.", "Press E to talk to people — everyone has their own story."],
	["قبل از خرید ماشین، آزمون قوانین راهنمایی و رانندگی را بده.", "Pass the traffic-rules quiz before buying a car."],
	["سر چراغ قرمز حدود ۵ ثانیه بایست، وگرنه دوربین عکس می‌گیرد.", "Stop about 5 s at red lights or the camera fines you."],
	["غذای سالم و خواب کافی، انرژی کشاورزت را بالا نگه می‌دارد.", "Healthy food and enough sleep keep your farmer strong."],
	["F5 ذخیره، F9 بارگذاری.", "F5 saves, F9 loads."],
	["با دوستانت آنلاین بازی کن: میزبان کد ۶ حرفی می‌گیرد.", "Play online: the host gets a 6-letter room code."],
	["محصول هر فصل فرق دارد؛ به تقویم مزرعه نگاه کن.", "Each season grows different crops — check the calendar."],
	["پول جریمه‌ها و مالیات صرف پارک و چراغ‌های شهر می‌شود.", "Fines and taxes pay for the town's parks and lights."],
]

var progress: float = 0.0
var running: bool = false
var threaded_path: String = ""
var min_secs: float = 1.4
var _t: float = 0.0
var _tip_t: float = 0.0
var _tip_i: int = 0
var _bar: ProgressBar
var _pct: Label
var _tip: Label
var _title: Label
var _retry: Button
var source: String = "warmup"
var waiting_for_assets: bool = false
var asset_keys: Array = []


func T(fa: String, en: String) -> String:
	return Lang.tt(fa, en)


func _ready() -> void:
	name = "Loading"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.1, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := VBoxContainer.new()
	v.name = "Box"
	v.custom_minimum_size = Vector2(320, 0)
	v.add_theme_constant_override(&"separation", 14)
	c.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 30)
	_title.add_theme_color_override(&"font_color", Color(1, 0.92, 0.6))
	v.add_child(_title)
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.8, 0.4)
	fill.set_corner_radius_all(10)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.18, 0.22, 0.18)
	back.set_corner_radius_all(10)
	_bar.add_theme_stylebox_override(&"fill", fill)
	_bar.add_theme_stylebox_override(&"background", back)
	v.add_child(_bar)
	_pct = Label.new()
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.add_theme_font_size_override(&"font_size", 15)
	v.add_child(_pct)
	_tip = Label.new()
	_tip.name = "Tip"
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_font_size_override(&"font_size", 17)
	_tip.add_theme_color_override(&"font_color", Color(0.85, 0.92, 0.8))
	v.add_child(_tip)
	_retry = Button.new()
	_retry.text = T("تلاش دوباره", "Retry")
	_retry.custom_minimum_size = Vector2(0, 44)
	_retry.visible = false
	_retry.pressed.connect(func() -> void: retry_requested.emit())
	v.add_child(_retry)
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)


func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	var box := find_child("Box", true, false) as Control
	if box:
		box.custom_minimum_size = Vector2(clampf(s.x * 0.8, 280.0, 640.0), 0)


func start(path: String = "") -> void:
	threaded_path = path
	progress = 0.0
	_t = 0.0
	_tip_i = randi() % TIPS.size()
	visible = true
	running = true
	_retry.visible = false
	_title.text = T("در حال آماده کردن شهر…", "Preparing the town…")
	_show_tip()
	_set_progress(0.0)
	set_process(true)


func _show_tip() -> void:
	var tip: Array = TIPS[_tip_i % TIPS.size()]
	_tip.text = T("نکته: " + str(tip[0]), "Tip: " + str(tip[1]))


func tip_text() -> String:
	return _tip.text


func _set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	_bar.value = progress * 100.0
	_pct.text = "%d%%" % int(round(progress * 100.0))


func fail(message: String) -> void:
	running = false
	set_process(false)
	_title.text = T("آماده‌سازی شهر ناموفق بود", "Town preparation failed")
	_tip.text = message
	_pct.text = T("اتصال اینترنت را بررسی کن.", "Check your connection.")
	_retry.visible = true


func _streamer_progress() -> float:
	for n in get_tree().get_nodes_in_group(&"world_streamer"):
		if n.has_method("load_progress"):
			return float(n.call("load_progress"))
	return -1.0


func _process(delta: float) -> void:
	if not running:
		return
	_t += delta
	_tip_t += delta
	if _tip_t > 3.5:
		_tip_t = 0.0
		_tip_i += 1
		_show_tip()
	var target := 0.0
	if waiting_for_assets:
		source = "assets"
		# Asset packs occupy the first 90%; the threaded scene finishes the rest.
		target = AssetPacks.load_progress(asset_keys) * 0.9
	elif threaded_path != "":
		source = "threaded"
		var arr := []
		var st := ResourceLoader.load_threaded_get_status(threaded_path, arr)
		target = float(arr[0]) if arr.size() > 0 else 0.0
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			target = 1.0
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			target = 1.0
	else:
		var sp := _streamer_progress()
		if sp >= 0.0:
			source = "streamer"
			target = minf(sp, _t / min_secs)
		else:
			source = "warmup"
			target = _t / min_secs
	if target > progress:
		_set_progress(minf(target, maxf(lerpf(progress, target, minf(1.0, delta * 8.0)), progress + delta * 0.02)))
	if target >= 1.0 and progress >= 0.999 and _t >= min_secs * 0.5:
		_set_progress(1.0)
		running = false
		set_process(false)
		finished.emit()
