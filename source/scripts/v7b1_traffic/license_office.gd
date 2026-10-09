class_name LicenseOffice
extends Node3D
## v7b.1 traffic desk in the police station (driving_license module): the left
## desk becomes "راهنمایی و رانندگی - گواهینامه". E opens the LicensePanel:
## read the Persian rules booklet, take the quiz (fee to the city fund), see
## your licence, offence points and impounded cars. F3 opens it anywhere
## (status + booklet; the test itself only at the desk).

var panel: LicensePanel
var spot: ActionSpot
var building: Building


func style() -> LicenseStyle:
	return Modules.style("driving_license") as LicenseStyle


func _ready() -> void:
	_attach.call_deferred()


func _attach() -> void:
	for n in get_tree().get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b and b.layout_id == "police":
			building = b
			break
	if building == null:
		return
	var desk := Node3D.new()
	desk.name = "TrafficDesk"
	desk.position = Vector3(-building.size.x * 0.25, Building.FOUNDATION_HEIGHT, -building.size.z * 0.5 + 0.12)
	building.add_child(desk)
	# Wall sign above the desk + a small rules stand on the counter.
	V7aKit.box(desk, Vector3(1.9, 0.42, 0.04), Vector3(0, 2.25, 0.02), TrafficKit.mat(Color(0.1, 0.32, 0.62), 0.5))
	var l := TrafficKit.label(desk, "راهنمایی و رانندگی - گواهینامه", "Traffic office - licences", Vector3(0, 2.25, 0.05), 0.0, 0.0024, 48, Color.WHITE)
	l.name = "DeskSign"
	V7aKit.box(desk, Vector3(0.3, 0.22, 0.04), Vector3(0.45, 1.0, 1.0), TrafficKit.mat(Color(0.95, 0.95, 0.9), 0.6))
	spot = ActionSpot.make(building, Vector3(-building.size.x * 0.25, Building.FOUNDATION_HEIGHT, -building.size.z * 0.5 + 2.6), 1.2,
		func() -> String: return Lang.tt("دفتر گواهینامه - کتابچه و امتحان", "licence desk - booklet & test"),
		func(_w: Node3D) -> void: open(true))
	spot.name = "LicenseDeskSpot"


func open(at_desk: bool) -> void:
	if panel:
		panel.open(at_desk)


## Desk position (tests / shots).
func desk_world() -> Vector3:
	return spot.global_position if spot else Vector3.ZERO
