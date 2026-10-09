class_name NetMove
extends RefCounted
## v5d server-side movement check (module "netcode"). Clients predict their
## own movement (the real Player with collisions) and send each input step
## with the position it produced. The server accepts a step only if it is
## physically possible: horizontal distance <= max_speed * tolerance * dt and
## a bounded vertical step. Otherwise the server clamps the move toward the
## claim and the client reconciles to the server's answer.


## Returns the authoritative position after one client step.
static func validate(prev: Vector3, claimed: Vector3, dt: float, st: NetcodeStyle) -> Vector3:
	dt = clampf(dt, 0.0, 0.25)
	var max_h := st.max_speed * st.speed_tolerance * dt + 0.02
	var d := Vector2(claimed.x - prev.x, claimed.z - prev.z)
	var out := claimed
	if d.length() > max_h:
		d = d.normalized() * max_h
		out.x = prev.x + d.x
		out.z = prev.z + d.y
	out.y = clampf(claimed.y, prev.y - st.max_vertical_step, prev.y + st.max_vertical_step)
	return out


## Client reconciliation: given the server's position for input `ack` and the
## local positions recorded for later inputs, returns the correction offset
## to apply to the local player (Vector3.ZERO = prediction was right).
## `history` is [[seq, Vector3 claimed position], ...] (oldest first).
static func correction(server_pos: Vector3, ack: int, history: Array, st: NetcodeStyle) -> Vector3:
	var predicted := Vector3.INF
	for h in history:
		if int(h[0]) == ack:
			predicted = h[1]
			break
	if predicted == Vector3.INF:
		return Vector3.ZERO
	var err := server_pos - predicted
	err.y = 0.0
	return err if err.length() > st.reconcile_threshold else Vector3.ZERO
