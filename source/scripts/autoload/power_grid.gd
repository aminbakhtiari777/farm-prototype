extends Node
## Central electricity state (autoload "PowerGrid"). Homes, windows and porch
## lamps listen to power_changed. Cutting power at any BreakerBox turns the
## electric lights off; homes use candles / lanterns / firelight instead.
## Street lamps stay on (they're on a separate circuit in this small town).

signal power_changed(on: bool)

var power_on: bool = true


func set_power(on: bool) -> void:
	if on == power_on:
		return
	power_on = on
	power_changed.emit(power_on)
	GameEvents.notification_requested.emit("Power restored" if power_on else "Power cut - homes switch to candles")


func toggle() -> void:
	set_power(not power_on)


func is_on() -> bool:
	return power_on
