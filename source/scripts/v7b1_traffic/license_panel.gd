class_name LicensePanel
extends PanelContainer
## v7b.1 licence panel: status (licence, offence points, impounded cars), the
## Persian rules booklet (pages from the driving_license module) and the quiz.
## Persian by default, English with the language toggle.

var _title: Label
var _body: Label
var _list: VBoxContainer
var _status: Label
var mode: String = "status"     ## status / book / quiz / result
var page: int = 0
var at_desk: bool = false
var questions: Array = []
var answers: Array = []
var q_index: int = 0
var last_score: int = -1


func style() -> LicenseStyle:
	return Modules.style("driving_license") as LicenseStyle


func _ready() -> void:
	name = "LicensePanel"
	theme = V6bWorld.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.09, 0.11, 0.15, 0.96), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(680, 500)
	offset_left = -340
	offset_right = 340
	offset_top = -250
	offset_bottom = 250
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title = UIKit.label(v, "", 24, UIKit.GOLD)
	_body = UIKit.label(v, "", 16, Color(0.92, 0.95, 1.0))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(620, 0)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 5)
	v.add_child(_list)
	_status = UIKit.label(v, "", 15, Color(0.85, 1.0, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.button(v, Lang.tt("بستن", "Close"), close, "", 16)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language" and visible:
			refresh())


func open(desk: bool = false) -> void:
	at_desk = desk
	mode = "status"
	visible = true
	GameEvents.open_modal("license")
	_status.text = ""
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("license")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func _t(d: Variant) -> String:
	if d is Dictionary:
		return str((d as Dictionary).get("fa" if Lang.is_fa() else "en", (d as Dictionary).get("en", "")))
	return str(d)


func status_text() -> String:
	var lic := TrafficState.license
	var s := ""
	match lic:
		"valid":
			s = Lang.tt("گواهینامه: معتبر", "Licence: valid")
		"confiscated":
			s = Lang.tt("گواهینامه: توقیف شده - %s روز مانده%s" % [Lang.digits(str(TrafficState.days_left())), " (امتحان دوباره قبول شد)" if TrafficState.retest_passed else ""],
				"Licence: confiscated - %d day(s) left%s" % [TrafficState.days_left(), " (re-test passed)" if TrafficState.retest_passed else ""])
		_:
			s = Lang.tt("گواهینامه: نداری. کتابچه را بخوان و در اداره‌ی پلیس امتحان بده.", "Licence: none. Read the booklet and take the test at the police station.")
	var rs := TrafficKit.rules()
	var cap := rs.offences_to_confiscate if rs else 2
	s += "\n" + Lang.tt("نمره‌ی منفی: %s از %s" % [Lang.digits(str(TrafficState.offence_count())), Lang.digits(str(cap))],
		"Offence points: %d of %d" % [TrafficState.offence_count(), cap])
	if not TrafficState.impounded.is_empty():
		s += "\n" + Lang.tt("ماشین در پارکینگ توقیف: %s" % Lang.digits(str(TrafficState.impounded.size())), "Cars in the impound lot: %d" % TrafficState.impounded.size())
	return s


func refresh() -> void:
	Lang.apply_dir(get_child(0) as Control)
	V7bKit.clear_children(_list)
	var st := style()
	if st == null:
		_body.text = "-"
		return
	match mode:
		"status":
			_title.text = Lang.tt("گواهینامه‌ی رانندگی", "Driving licence")
			_body.text = status_text()
			_btn(Lang.tt("خواندن کتابچه‌ی قوانین", "Read the rules booklet"), func() -> void:
				mode = "book"
				page = 0
				refresh())
			var can := TrafficState.can_take_test()
			var b := _btn(Lang.tt("شروع امتحان - %s سکه" % Lang.digits(str(st.test_fee)), "Start the test - %d G" % st.test_fee), start_quiz)
			b.disabled = not (at_desk and can)
			if not at_desk:
				b.tooltip_text = Lang.tt("امتحان فقط در اداره‌ی پلیس", "Test only at the police station")
				_status.text = Lang.tt("امتحان را فقط پشت میز راهنمایی و رانندگی در اداره‌ی پلیس می‌شود داد.", "The test is taken at the traffic desk in the police station.")
			elif not can:
				_status.text = Lang.tt("الان نمی‌توانی امتحان بدهی.", "You can't take the test right now.")
		"book":
			var pg: Dictionary = st.pages[clampi(page, 0, st.pages.size() - 1)] if not st.pages.is_empty() else {}
			_title.text = Lang.tt("کتابچه‌ی قوانین - صفحه‌ی %s از %s" % [Lang.digits(str(page + 1)), Lang.digits(str(st.pages.size()))],
				"Rules booklet - page %d of %d" % [page + 1, st.pages.size()])
			var lines: PackedStringArray = [_t(pg.get("title", ""))]
			for ln: Variant in pg.get("lines", []):
				lines.append("• " + _t(ln))
			_body.text = "\n".join(lines)
			var row := HBoxContainer.new()
			_list.add_child(row)
			var prev := UIKit.button(row, Lang.tt("قبلی", "Previous"), func() -> void:
				page = maxi(page - 1, 0)
				refresh(), "", 15)
			prev.disabled = page <= 0
			var nxt := UIKit.button(row, Lang.tt("بعدی", "Next"), func() -> void:
				page = mini(page + 1, st.pages.size() - 1)
				refresh(), "", 15)
			nxt.disabled = page >= st.pages.size() - 1
			UIKit.button(row, Lang.tt("بازگشت", "Back"), func() -> void:
				mode = "status"
				refresh(), "", 15)
		"quiz":
			var q: Dictionary = questions[q_index]
			_title.text = Lang.tt("امتحان - سؤال %s از %s" % [Lang.digits(str(q_index + 1)), Lang.digits(str(questions.size()))],
				"Test - question %d of %d" % [q_index + 1, questions.size()])
			_body.text = _t(q.get("q", ""))
			var opts: Array = q.get("options", [])
			for i in opts.size():
				_btn("%s) %s" % [Lang.digits(str(i + 1)), _t(opts[i])], answer.bind(i))
		"result":
			var passed := last_score >= st.pass_mark
			_title.text = Lang.tt("نتیجه‌ی امتحان", "Test result")
			_body.text = Lang.tt("%s از %s درست. %s" % [Lang.digits(str(last_score)), Lang.digits(str(questions.size())), "قبول شدی! گواهینامه صادر شد." if passed else "قبول نشدی. کتابچه را دوباره بخوان و باز امتحان بده."],
				"%d of %d correct. %s" % [last_score, questions.size(), "Passed! Your licence is issued." if passed else "Not passed. Read the booklet again and retry."])
			_body.text += "\n\n" + status_text()
			_btn(Lang.tt("بازگشت", "Back"), func() -> void:
				mode = "status"
				refresh())
	for b in _list.get_children():
		if b is Button:
			(b as Button).alignment = HORIZONTAL_ALIGNMENT_RIGHT if Lang.is_fa() else HORIZONTAL_ALIGNMENT_LEFT


func _btn(txt: String, fn: Callable) -> Button:
	return UIKit.button(_list, txt, fn, "", 16)


## Starts a quiz (charges the fee). Returns false when not allowed / no money.
func start_quiz() -> bool:
	var st := style()
	if st == null or not TrafficState.can_take_test():
		return false
	if Economy.money < st.test_fee:
		_status.text = Lang.tt("پول کافی نداری.", "Not enough money.")
		return false
	Economy.add_money(-st.test_fee)
	CityState.add_income("license_test", st.test_fee, "Driving test fee", "هزینه‌ی امتحان رانندگی")
	TrafficState.stat("quiz_taken")
	var pool := st.questions.duplicate()
	pool.shuffle()
	questions = pool.slice(0, mini(st.quiz_count, pool.size()))
	answers.clear()
	q_index = 0
	mode = "quiz"
	_status.text = ""
	refresh()
	return true


func answer(i: int) -> void:
	if mode != "quiz":
		return
	answers.append(i)
	q_index += 1
	if q_index >= questions.size():
		finish()
	else:
		refresh()


func finish() -> void:
	var st := style()
	last_score = 0
	for k in questions.size():
		if k < answers.size() and int(answers[k]) == int((questions[k] as Dictionary).get("answer", -1)):
			last_score += 1
	if st and last_score >= st.pass_mark:
		TrafficState.grant(true)
	mode = "result"
	refresh()


## Tests: the right answer for the current question.
func correct_answer() -> int:
	return int((questions[q_index] as Dictionary).get("answer", 0)) if mode == "quiz" and q_index < questions.size() else -1
