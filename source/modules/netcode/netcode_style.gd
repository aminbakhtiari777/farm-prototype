class_name NetcodeStyle
extends AssetModule
## v5d multiplayer transport + movement netcode (module "netcode").
## Consumers: Net (client + server), NetServer, RemoteAvatars.
## The game is single-player and offline by default; online is opt-in
## (Settings "online_enabled" + "server_url", or ?server=wss://... on the web).

## Default port of the headless server (the VPS puts nginx/TLS in front of it).
@export var port: int = 8910
## Server URL the opt-in uses when the player has not typed one ("" = none: the
## published build never connects anywhere on its own).
@export var default_server_url: String = ""
## Snapshots per second the server broadcasts / inputs per second a client sends.
@export var tick_hz: float = 15.0
## Remote players are drawn this far in the past (s) and interpolated.
@export var interp_delay: float = 0.12
## Server-side movement check: max horizontal speed (m/s) * tolerance.
@export var max_speed: float = 5.4
@export var speed_tolerance: float = 1.35
## Max vertical step per input (m) - jumps and slopes.
@export var max_vertical_step: float = 3.0
## Client reconciliation: predicted vs. server position error (m) that triggers a correction.
@export var reconcile_threshold: float = 0.35
## Errors above this snap immediately; smaller ones are blended over ~0.2 s.
@export var snap_threshold: float = 3.0
## Reconnect back-off (s): first try, doubling up to the max.
@export var reconnect_min: float = 2.0
@export var reconnect_max: float = 20.0
## WebSocket buffers (bytes) - saves and module files travel on the same socket.
@export var buffer_bytes: int = 8388608
## How often the server sends the shared clock (s).
@export var clock_every: float = 5.0
