class_name WeatherTextures
extends RefCounted
## v7b.1 tiny procedural particle textures + materials (no image files, a few KB
## of VRAM): soft round snowflake (radial gradient), rain streak (soft line that
## fades at both ends), petal and leaf silhouettes. All alpha-blended so no
## particle is ever drawn as a hard square (the v4 bug: untextured opaque quads).

static var _cache: Dictionary = {}


## Soft round flake: bright core, smooth radial falloff to fully transparent edges.
static func flake() -> ImageTexture:
	if _cache.has("flake"):
		return _cache["flake"]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var r := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)  # smoothstep falloff
			a = clampf(a * 1.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["flake"] = t
	return t


## Rain streak: thin soft line (x falloff), fades in at the top, strongest near the bottom.
static func streak() -> ImageTexture:
	if _cache.has("streak"):
		return _cache["streak"]
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)  # 0 top .. 1 bottom
		var along := smoothstep(0.0, 0.7, v) * (1.0 - smoothstep(0.88, 1.0, v))
		for x in w:
			var u := absf((x + 0.5) / float(w) * 2.0 - 1.0)
			var across := 1.0 - u * u
			img.set_pixel(x, y, Color(1, 1, 1, clampf(across * along, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["streak"] = t
	return t


## Petal: soft oval with a pointed base (tinted by the particle colour).
static func petal() -> ImageTexture:
	if _cache.has("petal"):
		return _cache["petal"]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
			var widen := 0.55 + 0.35 * (1.0 - p.y) * 0.5  # wider at the top
			var d := Vector2(p.x / widen, p.y).length()
			var a := clampf((1.0 - d) * 4.0, 0.0, 1.0)
			var shade := 0.85 + 0.15 * (1.0 - absf(p.x))
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["petal"] = t
	return t


## Leaf: pointed ellipse with a darker midrib.
static func leaf() -> ImageTexture:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
			var half_w := 0.55 * (1.0 - p.y * p.y)  # pointed at both ends
			var a := clampf((half_w - absf(p.x)) * 10.0, 0.0, 1.0)
			var rib := 1.0 - 0.3 * clampf(1.0 - absf(p.x) * 14.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(rib, rib, rib, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["leaf"] = t
	return t


## Alpha-blended unshaded particle material (vertex colour = per-particle tint).
static func particle_material(tex: Texture2D, billboard: bool, shaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.disable_receive_shadows = true
	m.roughness = 0.9
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	return m


## Billboard quad with a soft texture (snow flakes, splashes).
static func soft_quad(size: float, tex: Texture2D, billboard: bool = true, shaded: bool = false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_material(tex, billboard, shaded)
	return q


## Rain streak mesh: two crossed vertical quads (visible from any side; the
## particle's Y axis follows its velocity via CPUParticles3D.particle_flag_align_y,
## so the streaks lean with the wind).
static func streak_mesh(width: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hl := length * 0.5
	for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var a: Vector3 = axis * hw
		var verts := [Vector3(0, hl, 0) - a, Vector3(0, hl, 0) + a, Vector3(0, -hl, 0) + a, Vector3(0, -hl, 0) - a]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(verts[i])
	var mesh := st.commit()
	var m := particle_material(streak(), false)
	mesh.surface_set_material(0, m)
	return mesh
