class_name ControlsHelp
extends RefCounted
## v7b.1: the "Mouse & Touch" tab of the F1 Controls menu (Persian by default,
## English with the language toggle): desktop mouse, touch and keyboard rows
## for walking, looking, driving, the cockpit camera and playing as a resident.

const ROWS := [
	# [fa action, en action, fa desktop, en desktop, fa touch, en touch]
	["راه رفتن (نسبت به دوربین)", "Walk (relative to the camera)", "W A S D / جهت‌ها", "W A S D / arrows", "دسته‌ی چپ", "Left stick"],
	["نگاه / چرخاندن دوربین و شخصیت", "Look / turn camera + character", "ماوس (اول روی بازی کلیک کن)", "Mouse (click the game first)", "دسته‌ی راست", "Right stick"],
	["آزاد کردن ماوس", "Free the cursor", "Esc (هر پنلی هم آزادش می‌کند)", "Esc (any panel frees it too)", "-", "-"],
	["چرخش دوربین با صفحه‌کلید", "Orbit with the keyboard", "Z / C · PageUp / PageDown · کلیک راست و کشیدن", "Z / C · PageUp / PageDown · right-drag", "-", "-"],
	["دویدن / پرش", "Sprint / jump", "Shift / فاصله", "Shift / Space", "دکمه‌ی «دو» / «پرش»", "Run / Jump buttons"],
	["تعامل، سوار و پیاده شدن", "Interact, get in / out of a car", "E", "E", "دکمه‌ی E / سوار / پیاده", "E / Get in / Exit button"],
	["رانندگی: گاز و ترمز", "Driving: gas / brake", "W / S", "W / S", "دسته‌ی چپ بالا / پایین", "Left stick up / down"],
	["رانندگی: فرمان", "Driving: steer", "ماوس چپ و راست (یا A / D)", "Mouse left / right (or A / D)", "دسته‌ی راست (یا دسته‌ی چپ) چپ و راست", "Right (or left) stick left / right"],
	["ترمز دستی / بوق / چراغ", "Handbrake / horn / lights", "فاصله / R / H", "Space / R / H", "ترمز / بوق / چراغ", "Brake / Horn / Lights"],
	["دوربین داخل ماشین", "Cockpit camera", "V یا C (ماوس دور و بر را نگاه می‌کند، A / D فرمان)", "V or C (mouse looks around, A / D steer)", "دکمه‌ی دوربین", "Camera button"],
	["بازی در نقش شهروند", "Play as a townsperson", "F2 (همین کنترل‌ها برای او هم کار می‌کند)", "F2 (same controls for them)", "دکمه‌ی «نقش» / «بازگشت»", "Play as / Return button"],
	["در نقش شهروند: کندن / تخریب / آتش", "As a resident: dig / demolish / fire", "R / 1 / 2 (اول تأیید می‌خواهد)", "R / 1 / 2 (asks first)", "کندن / تخریب / آتش", "Dig / Demolish / Fire buttons"],
	["منو / راهنما", "Menu / help", "Esc / F1", "Esc / F1", "منو / ؟", "Menu / ?"],
]


static func build_tab(tabs: TabContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "MouseTouch"
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, Lang.tt("ماوس و لمس", "Mouse & Touch"))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 6)
	scroll.add_child(v)
	var grid := GridContainer.new()
	grid.name = "Rows"
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 6)
	v.add_child(grid)
	var fa := Lang.is_fa()
	for h in [["کار", "Action"], ["رایانه (ماوس و صفحه‌کلید)", "Computer (mouse + keyboard)"], ["گوشی (لمسی)", "Phone (touch)"]]:
		UIKit.label(grid, h[0] if fa else h[1], 15, Color(0.45, 0.28, 0.12))
	for r in ROWS:
		var l := UIKit.label(grid, r[0] if fa else r[1], 16, UIKit.INK)
		l.custom_minimum_size.x = 250
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var k := UIKit.label(grid, r[2] if fa else r[3], 16, Color(0.1, 0.25, 0.45))
		k.custom_minimum_size.x = 270
		k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var t := UIKit.label(grid, r[4] if fa else r[5], 16, Color(0.2, 0.4, 0.2))
		t.custom_minimum_size.x = 200
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var n := UIKit.label(v, Lang.tt("کنترل‌ها مثل GTA: روی رایانه با یک کلیک ماوس گرفته می‌شود و دوربین را می‌چرخاند؛ راه رفتن همیشه نسبت به دوربین است. روی گوشی دو دسته‌ی نیمه‌شفاف هر جا انگشتت را بگذاری ظاهر می‌شوند و هر دو با هم کار می‌کنند. حساسیت ماوس، معکوس عمودی و کنترل لمسی در تنظیمات (Esc) است. نشانگر دنده: A خودکار، عدد = دنده‌ی دستی، R عقب، N خلاص.",
		"GTA-style controls: on a computer one click captures the mouse and it turns the camera; walking is always relative to the camera. On a phone two semi-transparent sticks appear wherever your thumbs land and both work at once. Mouse sensitivity, invert Y and touch controls are in Settings (Esc). Gear indicator: A automatic, a number = manual gear, R reverse, N neutral."), 14, Color(0.35, 0.28, 0.2))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 760
	return scroll
