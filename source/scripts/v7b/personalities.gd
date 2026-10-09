class_name Personalities
extends RefCounted
## v7b "personalities" module: each resident's character (calm, hot-tempered,
## generous, stingy, cheerful, shy). Used by Conflicts (temper + what they
## say), the haggle panel and NPC-to-NPC trades (Chatter), and passengers'
## tips. Everything degrades gracefully when the module is missing.


static func style() -> PersonalityStyle:
	return Modules.style("personalities") as PersonalityStyle


static func trait_id(r: Dictionary) -> String:
	var st := style()
	if st == null:
		return ""
	var nm := Population.full_name(r)
	if st.people.has(nm):
		return str(st.people[nm])
	# Not listed: a stable pick from the name.
	var ids: Array = st.traits.keys()
	if ids.is_empty():
		return st.default_trait
	return str(ids[absi(nm.hash()) % ids.size()]) if nm != "" else st.default_trait


static func trait_of(r: Dictionary) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	return st.traits.get(trait_id(r), st.traits.get(st.default_trait, {}))


static func trait_name(r: Dictionary) -> String:
	var t := trait_of(r)
	return Lang.tt(str(t.get("fa", "")), str(t.get("en", ""))) if not t.is_empty() else ""


static func value(r: Dictionary, key: String, fallback: float) -> float:
	var t := trait_of(r)
	return float(t.get(key, fallback)) if not t.is_empty() else fallback


static func temper(r: Dictionary) -> float:
	return value(r, "temper", 0.3)


static func lines(r: Dictionary, kind: String) -> Array:
	return trait_of(r).get(kind, [])


## ---------------------------------------------------------------- haggling
## The price a resident first offers for an item you sell them.
static func opening_offer(r: Dictionary, fair: int) -> int:
	var h := value(r, "haggle", 0.4)
	return maxi(1, int(round(fair * (1.0 - 0.3 * h))))


## The most they would pay (generous people pay above the fair price).
static func max_price(r: Dictionary, fair: int) -> int:
	var g := value(r, "generosity", 0.5)
	var h := value(r, "haggle", 0.4)
	return maxi(1, int(round(fair * (1.0 + 0.3 * g - 0.12 * h))))


## Answer to an asking price: {"result": accept|counter|refuse, "price", "line"}.
## `round` = how many times you already asked for more.
static func respond(r: Dictionary, fair: int, asking: int, round_n: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var mx := max_price(r, fair)
	var patience := int(value(r, "patience", 2))
	if asking <= mx:
		return {"result": "accept", "price": asking, "line": V7bKit.line(lines(r, "accept"), {}, rng)}
	if round_n >= patience:
		return {"result": "refuse", "price": 0, "line": V7bKit.line(lines(r, "refuse"), {}, rng)}
	var counter := int(round((mx + opening_offer(r, fair)) * 0.5)) if round_n == 0 else mx
	counter = clampi(counter, 1, asking - 1)
	return {"result": "counter", "price": counter, "line": V7bKit.line(lines(r, "counter"), {"price": V7bKit.num(counter)}, rng)}


## Two residents trade: a deal happens unless both are tight-fisted / short-tempered.
static func npc_deal(seller: Dictionary, buyer: Dictionary, rng: RandomNumberGenerator) -> bool:
	var tight := value(seller, "haggle", 0.4) + value(buyer, "haggle", 0.4)
	var hot := maxf(temper(seller), temper(buyer))
	return rng.randf() > tight * 0.45 + hot * 0.25
