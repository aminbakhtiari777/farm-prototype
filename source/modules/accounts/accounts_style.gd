class_name AccountsStyle
extends AssetModule
## v5d player identity (module "accounts"): a guest ID + random token kept
## locally (localStorage on the web). The server keys saves by guest ID and
## checks the token. NOT real authentication - see docs/SERVER_SETUP.md.
## Consumers: Net, NetServer.

@export var guest_prefix: String = "guest-"
@export var name_min: int = 2
@export var name_max: int = 16
@export var default_names: PackedStringArray = PackedStringArray(["کشاورز", "مهمان"])
## Max simultaneous players on one server.
@export var max_players: int = 32
