class_name RealClockStyle
extends AssetModule
## v6a real clock: game time can follow the device clock (Settings "real_clock",
## or always with mode "always"). The moon then uses the real lunar phase.
## Consumers: TimeManager (real_clock flag), NightSky, SettingsPanel.

@export var name_fa: String = ""
## "optional" = off until switched on in Settings, "always" = forced on.
@export var mode: String = "optional"
@export var real_moon: bool = true
