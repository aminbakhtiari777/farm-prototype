class_name QrEncoder
extends RefCounted
## Small self-written QR Code encoder (byte mode, ECC level M, versions 1-10,
## automatic mask by penalty). No plugin, no network. Verified module-for-module
## against the Python `qrcode` library (all 8 masks) - see platform smoke.
## encode(text) -> {"version", "mask", "size", "modules": Array[PackedByteArray]} (1 = dark)

const ECC_M := [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26]
const BLK_M := [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5]
const FORMAT_M := 0

var _m: Array = []  ## rows of PackedByteArray (0/1)
var _f: Array = []  ## function-module flags
var _size: int = 0


static func raw_modules(v: int) -> int:
	var r := (16 * v + 128) * v + 64
	if v >= 2:
		var n := v / 7 + 2
		r -= (25 * n - 10) * n - 55
		if v >= 7:
			r -= 36
	return r


static func data_codewords(v: int) -> int:
	return raw_modules(v) / 8 - int(ECC_M[v]) * int(BLK_M[v])


static func gmul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF


static func rs_divisor(deg: int) -> Array:
	var r: Array = []
	r.resize(deg)
	r.fill(0)
	r[deg - 1] = 1
	var root := 1
	for _i in deg:
		for j in deg:
			r[j] = gmul(int(r[j]), root)
			if j + 1 < deg:
				r[j] = int(r[j]) ^ int(r[j + 1])
		root = gmul(root, 2)
	return r


static func rs_remainder(data: Array, div: Array) -> Array:
	var r: Array = []
	r.resize(div.size())
	r.fill(0)
	for b in data:
		var f := int(b) ^ int(r.pop_front())
		r.append(0)
		for i in r.size():
			r[i] = int(r[i]) ^ gmul(int(div[i]), f)
	return r


static func alignment_positions(v: int) -> Array:
	if v == 1:
		return []
	var n := v / 7 + 2
	var size := v * 4 + 17
	var step := (v * 8 + n * 3 + 5) / (n * 4 - 4) * 2
	var res: Array = []
	var pos := size - 7
	for _i in n - 1:
		res.insert(0, pos)
		pos -= step
	res.insert(0, 6)
	return res


## Returns {} if the text is too long for version 10-M (~213 bytes).
static func encode(text: String, force_mask: int = -1) -> Dictionary:
	var q := QrEncoder.new()
	return q._encode(text, force_mask)


func _encode(text: String, force_mask: int) -> Dictionary:
	var data := text.to_utf8_buffer()
	var ver := 0
	for v in range(1, 11):
		var need := 4 + (8 if v < 10 else 16) + 8 * data.size()
		if need <= data_codewords(v) * 8:
			ver = v
			break
	if ver == 0:
		return {}
	var bits: Array = []
	var app := func(val: int, n: int) -> void:
		for i in range(n - 1, -1, -1):
			bits.append((val >> i) & 1)
	app.call(4, 4)
	app.call(data.size(), 8 if ver < 10 else 16)
	for b in data:
		app.call(b, 8)
	var cap := data_codewords(ver) * 8
	app.call(0, mini(4, cap - bits.size()))
	app.call(0, (8 - bits.size() % 8) % 8)
	var pad := 0xEC
	while bits.size() < cap:
		app.call(pad, 8)
		pad ^= 0xEC ^ 0x11
	var cws: Array = []
	for i in range(0, bits.size(), 8):
		var c := 0
		for k in 8:
			c = (c << 1) | int(bits[i + k])
		cws.append(c)
	var nb := int(BLK_M[ver])
	var ecl := int(ECC_M[ver])
	var raw := raw_modules(ver) / 8
	var nshort := nb - raw % nb
	var shortlen := raw / nb
	var div := rs_divisor(ecl)
	var blocks: Array = []
	var k2 := 0
	for i in nb:
		var dl := shortlen - ecl + (0 if i < nshort else 1)
		var dat: Array = cws.slice(k2, k2 + dl)
		k2 += dl
		var ec := rs_remainder(dat, div)
		if i < nshort:
			dat.append(0)
		blocks.append(dat + ec)
	var final: Array = []
	for i in (blocks[0] as Array).size():
		for j in blocks.size():
			if i != shortlen - ecl or j >= nshort:
				final.append(blocks[j][i])
	_size = ver * 4 + 17
	_m.clear()
	_f.clear()
	for _y in _size:
		var row := PackedByteArray()
		row.resize(_size)
		row.fill(0)
		_m.append(row)
		var frow := PackedByteArray()
		frow.resize(_size)
		frow.fill(0)
		_f.append(frow)
	for i in _size:
		_setf(6, i, i % 2 == 0)
		_setf(i, 6, i % 2 == 0)
	for c in [Vector2i(3, 3), Vector2i(_size - 4, 3), Vector2i(3, _size - 4)]:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var d := maxi(absi(dx), absi(dy))
				var x: int = c.x + dx
				var y: int = c.y + dy
				if x >= 0 and x < _size and y >= 0 and y < _size:
					_setf(x, y, d != 2 and d != 4)
	var ap := alignment_positions(ver)
	var na := ap.size()
	for i in na:
		for j in na:
			if (i == 0 and j == 0) or (i == 0 and j == na - 1) or (i == na - 1 and j == 0):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					_setf(int(ap[i]) + dx, int(ap[j]) + dy, maxi(absi(dx), absi(dy)) != 1)
	_draw_format(0)
	if ver >= 7:
		var r := ver
		for _i in 12:
			r = (r << 1) ^ ((r >> 11) * 0x1F25)
		var vb := (ver << 12) | r
		for i in 18:
			var bt := ((vb >> i) & 1) != 0
			var a := _size - 11 + i % 3
			var cc := i / 3
			_setf(a, cc, bt)
			_setf(cc, a, bt)
	var bi := 0
	var right := _size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in _size:
			for j in 2:
				var x := right - j
				var up := ((right + 1) & 2) == 0
				var y := _size - 1 - vert if up else vert
				if _f[y][x] == 0 and bi < final.size() * 8:
					_m[y][x] = (int(final[bi >> 3]) >> (7 - (bi & 7))) & 1
					bi += 1
		right -= 2
	var mask := force_mask
	if mask < 0:
		var best := -1
		var best_pen := 1 << 30
		for m in 8:
			_apply(m)
			_draw_format(m)
			var pen := _penalty()
			if pen < best_pen:
				best_pen = pen
				best = m
			_apply(m)
		mask = best
	_apply(mask)
	_draw_format(mask)
	return {"version": ver, "mask": mask, "size": _size, "modules": _m}


func _setf(x: int, y: int, dark: bool) -> void:
	_m[y][x] = 1 if dark else 0
	_f[y][x] = 1


func _draw_format(msk: int) -> void:
	var d := (FORMAT_M << 3) | msk
	var r := d
	for _i in 10:
		r = (r << 1) ^ ((r >> 9) * 0x537)
	var b := ((d << 10) | r) ^ 0x5412
	for i in 6:
		_setf(8, i, ((b >> i) & 1) != 0)
	_setf(8, 7, ((b >> 6) & 1) != 0)
	_setf(8, 8, ((b >> 7) & 1) != 0)
	_setf(7, 8, ((b >> 8) & 1) != 0)
	for i in range(9, 15):
		_setf(14 - i, 8, ((b >> i) & 1) != 0)
	for i in 8:
		_setf(_size - 1 - i, 8, ((b >> i) & 1) != 0)
	for i in range(8, 15):
		_setf(8, _size - 15 + i, ((b >> i) & 1) != 0)
	_setf(8, _size - 8, true)


func _cond(msk: int, x: int, y: int) -> bool:
	match msk:
		0: return (x + y) % 2 == 0
		1: return y % 2 == 0
		2: return x % 3 == 0
		3: return (x + y) % 3 == 0
		4: return (x / 3 + y / 2) % 2 == 0
		5: return x * y % 2 + x * y % 3 == 0
		6: return (x * y % 2 + x * y % 3) % 2 == 0
		_: return ((x + y) % 2 + x * y % 3) % 2 == 0


func _apply(msk: int) -> void:
	for y in _size:
		for x in _size:
			if _f[y][x] == 0 and _cond(msk, x, y):
				_m[y][x] = 1 - int(_m[y][x])


func _penalty() -> int:
	var p := 0
	for horiz in [true, false]:
		for a in _size:
			var run := 1
			for b in range(1, _size):
				var cur: int = _m[a][b] if horiz else _m[b][a]
				var prev: int = _m[a][b - 1] if horiz else _m[b - 1][a]
				if cur == prev:
					run += 1
				else:
					if run >= 5:
						p += run - 2
					run = 1
			if run >= 5:
				p += run - 2
	for y in _size - 1:
		for x in _size - 1:
			var c: int = _m[y][x]
			if c == _m[y][x + 1] and c == _m[y + 1][x] and c == _m[y + 1][x + 1]:
				p += 3
	var dark := 0
	for y in _size:
		for x in _size:
			dark += int(_m[y][x])
	var tot := _size * _size
	var k3 := (absi(dark * 20 - tot * 10) + tot - 1) / tot - 1
	return p + k3 * 10


## Matrix as rows of "0"/"1" strings (tests).
static func to_strings(res: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for row in res.get("modules", []):
		var s := ""
		for v in row:
			s += "1" if v else "0"
		out.append(s)
	return out


## Render to an ImageTexture (quiet zone 4, `scale` px per module).
static func to_texture(res: Dictionary, scale: int = 6) -> ImageTexture:
	var n := int(res.get("size", 0))
	if n == 0:
		return null
	var border := 4
	var px := (n + border * 2) * scale
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var rows: Array = res["modules"]
	for y in n:
		for x in n:
			if int(rows[y][x]) == 1:
				img.fill_rect(Rect2i((x + border) * scale, (y + border) * scale, scale, scale), Color.BLACK)
	return ImageTexture.create_from_image(img)
