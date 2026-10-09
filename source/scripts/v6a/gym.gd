class_name Gym
extends RefCounted
## v6a gym logic (gym module): one workout on a station = pay the fee (the
## player), spend stamina and time, gain fitness (Lifestyle). Townspeople
## train for free as part of their leisure (ScheduleController "workout").


static func style() -> GymStyle:
	return Modules.style("gym") as GymStyle


## Called when someone settles on a gym station (Seat.used).
static func workout(who: Node3D, eq: Dictionary) -> bool:
	if who == null or not who.is_in_group(&"player"):
		return false
	var gs := style()
	var fee := gs.fee if gs else 0
	if fee > 0 and Economy.money < fee:
		GameEvents.notification_requested.emit(Lang.tt("ورودیه‌ی باشگاه %s سکه است." % Lang.digits(str(fee)), "The gym fee is %d G." % fee))
		if who.has_method("stand_up"):
			who.call("stand_up")
		return false
	if fee > 0:
		Economy.add_money(-fee)
	if who.has_method("spend_stamina"):
		who.call("spend_stamina", float(eq.get("stamina", 10.0)))
	TimeManager.advance_minutes(float(eq.get("minutes", 20.0)))
	Lifestyle.add_fitness(float(eq.get("fitness", 4.0)))
	Needs.hunger = maxf(Needs.hunger - float(eq.get("stamina", 10.0)) * 0.4, 0.0)
	var pct := int(round(Lifestyle.fitness_ratio() * 100.0))
	GameEvents.notification_requested.emit(Lang.tt("%s - آمادگی بدنی %s٪" % [str(eq.get("fa", "ورزش")), Lang.digits(str(pct))],
		"%s - fitness %d%%" % [str(eq.get("en", "workout")).capitalize(), pct]))
	return true
