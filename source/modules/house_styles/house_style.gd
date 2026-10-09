class_name HouseStyle
extends AssetModule
## A house style (collection type "house_styles": every style is used in town).
## Exterior cladding + roof shape and a matching interior palette/furniture.
## Consumers: Building (exterior), InteriorBuilder (interior).

@export_enum("wooden", "stone", "modern") var kind: String = "wooden"
@export var wall_color: Color = Color(0.66, 0.48, 0.3)
@export var joint_color: Color = Color(0.3, 0.2, 0.12)
## 0 siding, 1 stone, 2 panels (assets/shaders/house_cladding.gdshader).
@export var pattern: int = 0
@export var roof_color: Color = Color(0.45, 0.25, 0.18)
@export_enum("gable", "flat") var roof_type: String = "gable"
@export var trim_color: Color = Color(0.92, 0.88, 0.8)
@export var chimney: bool = true
@export var interior_wall: Color = Color(0.85, 0.75, 0.6)
@export var interior_floor: Color = Color(0.45, 0.3, 0.18)
## InteriorBuilder._home options merged over the theme defaults.
@export var furniture: Dictionary = {}

static var _materials: Dictionary = {}


func wall_material() -> ShaderMaterial:
	if _materials.has(id):
		return _materials[id]
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/house_cladding.gdshader")
	m.set_shader_parameter(&"base_color", wall_color)
	m.set_shader_parameter(&"joint_color", joint_color)
	m.set_shader_parameter(&"pattern", pattern)
	_materials[id] = m
	return m


## The style for a layout building: its "house_style" key, else homes cycle
## through all registered styles (the farmhouse is wooden).
## v5a live swap: "" = the usual mix of every style; otherwise every home
## (except the farmhouse) uses this style id. Set via set_town_style().
static var town_style: String = ""


## Live-swaps every home to one house style ("" = mixed) and rebuilds the
## homes in place (Building listens to "house_styles" module_changed).
static func set_town_style(id: String) -> void:
	town_style = id
	var loop := Engine.get_main_loop() as SceneTree
	var reg := loop.root.get_node_or_null(^"AssetRegistry") if loop else null
	if reg:
		var all := Modules.all("house_styles")
		reg.emit_signal(&"module_changed", "house_styles", all[0] if not all.is_empty() else null)


static func for_layout(b: Dictionary) -> HouseStyle:
	if str(b.get("kind", "")) != "home":
		return null
	var all := Modules.all("house_styles")
	if all.is_empty():
		return null
	var want := str(b.get("house_style", "wooden" if b.get("id") == "farmhouse" else town_style))
	if want != "":
		for s in all:
			if s.id == want:
				return s as HouseStyle
	var ids: Array[String] = []
	for h in TownLayout.BUILDINGS:
		if str(h["kind"]) == "home" and h["id"] != "farmhouse":
			ids.append(str(h["id"]))
	var i := maxi(ids.find(str(b.get("id", ""))), 0)
	var names: Array[String] = []
	for s in all:
		names.append(s.id)
	names.sort()
	var pick := names[i % names.size()]
	for s in all:
		if s.id == pick:
			return s as HouseStyle
	return all[0] as HouseStyle
