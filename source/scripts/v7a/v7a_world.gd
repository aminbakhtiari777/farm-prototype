class_name V7aWorld
extends Node3D
## v7a world features (first half of v7), each its own swappable module:
##   backstories  - Backstories (static; NPC card + dialogue hooks)
##   kids         - KidsPlay: play, bikes round the square, chats, mischief
##   conflicts    - Conflicts: street arguments, calmed by you or the police
##   possession   - Possession: play as a townsperson (F2), 1 demolish, 2 fire
##   fire         - FireService: station, truck, crew, spread, rebuild
##   outages      - Outages: storm cuts, earthquakes, repair crew
##   city_fund    - CityFund: fines -> fund -> public works + doctor subsidy

var kids: KidsPlay
var conflicts: Conflicts
var possession: Possession
var fire: FireService
var outages: Outages
var fund: CityFund


func _ready() -> void:
	fire = _add(FireService.new(), "FireService")
	kids = _add(KidsPlay.new(), "KidsPlay")
	conflicts = _add(Conflicts.new(), "Conflicts")
	possession = _add(Possession.new(), "Possession")
	outages = _add(Outages.new(), "Outages")
	fund = _add(CityFund.new(), "CityFund")


func _add(n: Node, nm: String) -> Node:
	n.name = nm
	add_child(n)
	return n
