class_name TopBar
extends PanelContainer
## Compact top bar: season + day + clock, weather icon, money, and buttons:
## Bag (inventory), Save, Connect (multiplayer - coming soon), Logout and the
## gear that opens Settings. Everything else lives in the Settings panel.

signal settings_pressed
signal bag_pressed
signal logout_pressed

var clock_label: Label
var weather_icon: WeatherIcon
var money_label: Label
var buttons: Dictionary = {}
## v6a: [text, tooltip] in English; shown through Lang.loc_ui (ui_text module).
const BUTTON_TEXT := {
	"bag": ["Bag", "Inventory (I)"],
	"save": ["Save", "Save the game (F5)"],
	"connect": ["Connect", "Multiplayer"],
	"logout": ["Logout", "Back to the title screen"],
	"settings": ["", "Settings & menu (Esc / O)"],
}


func _ready() -> void:
	name = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override(&"panel", UIKit.style(UIKit.DARK, 12, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	add_child(row)
	clock_label = UIKit.label(row, "Spring 1 · 08:00 AM", 19, Color(1, 0.93, 0.75))
	clock_label.custom_minimum_size.x = 205
	weather_icon = WeatherIcon.new()
	row.add_child(weather_icon)
	money_label = UIKit.label(row, "500 G", 19, UIKit.GOLD)
	money_label.custom_minimum_size.x = 80
	row.add_child(VSeparator.new())
	buttons["bag"] = UIKit.button(row, "Bag", func() -> void: bag_pressed.emit(), "Inventory (I)")
	buttons["save"] = UIKit.button(row, "Save", _on_save, "Save the game (F5)")
	buttons["connect"] = UIKit.button(row, "Connect", _on_connect, "Multiplayer")
	buttons["logout"] = UIKit.button(row, "Logout", func() -> void: logout_pressed.emit(), "Back to the title screen")
	buttons["settings"] = UIKit.button(row, "", func() -> void: settings_pressed.emit(), "Settings & menu (Esc / O)", 18)
	(buttons["settings"] as Button).icon = gear_icon()
	(buttons["settings"] as Button).name = "GearButton"
	resized.connect(_center)
	get_viewport().size_changed.connect(_center)
	_center.call_deferred()
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void: refresh())
	TimeManager.weather_changed.connect(func(_w: String) -> void: refresh())
	TimeManager.season_changed.connect(func(_s: int) -> void: refresh())
	TimeManager.day_started.connect(func(_d: int) -> void: refresh())
	Economy.money_changed.connect(func(_m: int) -> void: refresh())
	# v6a: labels follow the dialogue language (Persian by default).
	GameEvents.setting_changed.connect(func(_k: String, _v: Variant) -> void: refresh())
	refresh()


## Keep the bar centred at the top whatever its width.
func _center() -> void:
	var w := get_viewport_rect().size.x
	anchor_left = 0.0
	anchor_right = 0.0
	position = Vector2(roundf((w - size.x) * 0.5), 0.0)


func _on_save() -> void:
	var ok := SaveGame.save_game()
	GameEvents.notification_requested.emit(Lang.tt("بازی ذخیره شد", "Game saved") if ok else Lang.tt("ذخیره نشد: ", "Save failed: ") + SaveGame.last_error)


func _on_connect() -> void:
	GameEvents.notification_requested.emit(Lang.tt("بازی چندنفره به‌زودی!", "Multiplayer coming soon!"))


func refresh() -> void:
	clock_label.text = "%s · %s" % [Lang.date_text(), Lang.clock_text()]
	var h := TimeManager.hours_float()
	weather_icon.set_weather(TimeManager.weather_id, h < TimeManager.sunrise() or h > TimeManager.sunset())
	money_label.text = Lang.tt("%s سکه" % Lang.digits(str(Economy.money)), "%d G" % Economy.money)
	for k: String in BUTTON_TEXT:
		if buttons.has(k):
			var bt := buttons[k] as Button
			var pair: Array = BUTTON_TEXT[k]
			bt.text = Lang.loc_ui(str(pair[0]))
			bt.tooltip_text = Lang.loc_ui(str(pair[1]))


## Procedural gear icon (no icon font needed).
static func gear_icon(px: int = 22) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) * 0.5
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var r := d.length()
			var a := atan2(d.y, d.x)
			var tooth: float = 0.5 + 0.5 * signf(sin(a * 8.0))
			var outer: float = px * 0.36 + tooth * px * 0.1
			var on: bool = r < outer and r > px * 0.15
			img.set_pixel(x, y, Color(0.95, 0.92, 0.85, 1.0) if on else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
