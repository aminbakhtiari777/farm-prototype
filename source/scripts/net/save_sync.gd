class_name SaveSync
extends RefCounted
## v5d save sync rules (module "save_sync"). A save snapshot (SaveGame) is
## split into field groups. Every group carries the time it last changed
## (unix seconds), so an offline session and the server copy can be merged:
##   * player groups (money, farm, player, needs...): the newest group wins
##     ("latest_per_group"), or the server's copy for "server_wins".
##   * world groups (clock, market): the server's copy wins whenever it has one.
## A synced save is {"data": <snapshot>, "stamps": {group: unix}, "guest": id}.

const META_KEYS := ["version", "saved_at"]


static func style() -> SaveSyncStyle:
	return Modules.style("save_sync") as SaveSyncStyle


static func groups_of(data: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in data:
		if not (str(k) in META_KEYS):
			out.append(str(k))
	out.sort()
	return out


static func is_world_group(group: String, st: SaveSyncStyle = null) -> bool:
	if st == null:
		st = style()
	return st != null and group in st.world_groups


## Stable hash of one group (JSON with sorted keys).
static func group_hash(value: Variant) -> String:
	return JSON.stringify(value, "", true).sha256_text()


## Updates `stamps` for every group whose content changed since `hashes`
## (both dictionaries are modified in place). Returns the changed groups.
static func restamp(data: Dictionary, stamps: Dictionary, hashes: Dictionary, now: float) -> PackedStringArray:
	var changed := PackedStringArray()
	for g in groups_of(data):
		var h := group_hash(data[g])
		if str(hashes.get(g, "")) != h:
			hashes[g] = h
			stamps[g] = now
			changed.append(g)
	return changed


## Merges a local and a server synced save. Returns
## {"data": merged snapshot, "stamps": merged stamps, "from": {group: "local"|"server"}}.
static func merge(local: Dictionary, server: Dictionary, st: SaveSyncStyle = null) -> Dictionary:
	if st == null:
		st = style()
	var ld: Dictionary = local.get("data", {})
	var sd: Dictionary = server.get("data", {})
	var ls: Dictionary = local.get("stamps", {})
	var ss: Dictionary = server.get("stamps", {})
	var out := {}
	var stamps := {}
	var from := {}
	var all := {}
	for g in groups_of(ld):
		all[g] = true
	for g in groups_of(sd):
		all[g] = true
	var server_wins_all := st != null and st.player_rule == "server_wins"
	for g: String in all:
		var in_l := ld.has(g)
		var in_s := sd.has(g)
		var pick_server: bool
		if not in_l:
			pick_server = true
		elif not in_s:
			pick_server = false
		elif is_world_group(g, st) or server_wins_all:
			pick_server = true
		else:
			# Newest group wins; a tie keeps the server's copy (it is shared truth).
			pick_server = float(ss.get(g, 0.0)) >= float(ls.get(g, 0.0))
		out[g] = (sd[g] if pick_server else ld[g])
		stamps[g] = float(ss.get(g, 0.0)) if pick_server else float(ls.get(g, 0.0))
		from[g] = "server" if pick_server else "local"
	for k in META_KEYS:
		if sd.has(k) or ld.has(k):
			out[k] = ld.get(k, sd.get(k)) if ld.has(k) else sd.get(k)
	return {"data": out, "stamps": stamps, "from": from}


## Newest stamp in a synced save (0 if none).
static func newest(synced: Dictionary) -> float:
	var n := 0.0
	var s: Dictionary = synced.get("stamps", {})
	for g in s:
		n = maxf(n, float(s[g]))
	return n


static func pack(synced: Dictionary) -> PackedByteArray:
	return JSON.stringify(synced).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)


static func unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var raw := bytes.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var v: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return v if v is Dictionary else {}
