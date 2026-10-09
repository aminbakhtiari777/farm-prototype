class_name FireTruckStyle
extends AssetModule
## v7b.1 real red fire truck (cab, ladder, hose reels, light bar, 'آتش‌نشانی
## ۱۲۵') plus a positional siren that sounds around town while responding.
## Consumer: FireSiren (FireService).

@export var name_fa: String = ""
@export var enabled: bool = true
@export var siren_enabled: bool = true
## wail / hi_lo
@export var siren_kind: String = "wail"
## s per loop
@export var siren_period: float = 2.4
## AudioStreamPlayer3D unit_size
@export var unit_size: float = 14.0
## m
@export var max_distance: float = 170.0
@export var volume_db: float = -2.0
@export var light_colors: Array = []
