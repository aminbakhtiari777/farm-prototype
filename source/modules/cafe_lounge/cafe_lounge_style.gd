class_name CafeLoungeStyle
extends AssetModule
## v7b.1 classy cafe: the v7b terrace gets polished stone tiles, cushioned
## seats, table linen + candles, a pergola with warm pendant lights and potted
## plants; next to it an indoor cafe-lounge (walk in) that becomes a disco at
## night: dance floor with coloured tiles + moving lights, DJ booth (the v7b DJ
## post) and a bar (the v7b bartender / menu), positional music, and a crowd of
## residents dancing. Dress code: stylish and modest (jackets / long sleeves,
## long trousers or skirts) - never revealing. The v7b tipsy limit and fights
## still apply. Consumers: CafeLounge, TerraceCafe (decor).

@export var name_fa: String = ""
## indoor lounge centre
@export var hall_pos: Vector2 = Vector2(-37.0, -23.0)
## deg; door faces +z local
@export var hall_yaw: float = 90.0
@export var hall_size: Vector3 = Vector3(12.0, 3.8, 10.0)
@export var wall: Color = Color(0.2, 0.17, 0.2)
## brass trim
@export var trim: Color = Color(0.78, 0.62, 0.3)
## cafe-lounge
@export var open_hours: Vector2 = Vector2(16.0, 24.0)
## dance floor + DJ
@export var disco_hours: Vector2 = Vector2(20.0, 24.0)
## people inside at disco time
@export var crowd: int = 12
## Colors of the floor tiles / lights
@export var dance_colors: Array = []
@export var music: PackedStringArray = PackedStringArray()
@export var music_db: float = -3.0
## allowed top styles (modest)
@export var dress_tops: PackedStringArray = PackedStringArray()
## top style residents change into for the evening
@export var dress_up: String = "jacket"
@export var terrace_decor: bool = true
## false = a calm jazz lounge
@export var disco: bool = true
## {en, fa}
@export var name: Dictionary = {}
