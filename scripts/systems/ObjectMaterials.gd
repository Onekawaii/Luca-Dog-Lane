extends RefCounted

static var textures: Dictionary = {}
const SOURCE_IDS := {"wood":"Wood066", "stone":"Rock035", "grass":"Grass005", "fabric":"Fabric030", "brick":"Bricks005", "metal":"Metal049A"}

# Deterministic, seamless material studies; no network/runtime asset dependency.
static func make(kind: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = texture(kind)
	if SOURCE_IDS.has(kind):
		var prefix := "res://assets/materials/%s_1K-JPG_" % SOURCE_IDS[kind]
		if ResourceLoader.exists(prefix + "NormalGL.jpg"):
			mat.normal_enabled = true
			mat.normal_texture = load(prefix + "NormalGL.jpg")
			mat.normal_scale = 0.5
		if ResourceLoader.exists(prefix + "Roughness.jpg"):
			mat.roughness_texture = load(prefix + "Roughness.jpg")
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 0.9
	if kind == "metal":
		mat.metallic = 0.82
		mat.roughness = 0.38
	return mat

static func texture(kind: String) -> Texture2D:
	if textures.has(kind):
		return textures[kind]
	if SOURCE_IDS.has(kind):
		var path := "res://assets/materials/%s_1K-JPG_Color.jpg" % SOURCE_IDS[kind]
		if ResourceLoader.exists(path):
			var imported: Texture2D = load(path)
			textures[kind] = imported
			return imported
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 6060
	noise.frequency = 0.1
	for y in range(128):
		for x in range(128):
			var n := noise.get_noise_2d(x, y)
			var value := 0.78 + n * 0.22
			match kind:
				"wood": value = 0.73 + sin(float(x) * 0.45 + n * 2.0 + sin(y * 0.07)) * 0.13 + n * 0.10
				"fur": value = 0.68 + sin(x * 0.16 + sin(y * 0.08) * 1.4) * 0.20 + n * 0.12
				"fabric": value = 0.72 + (0.10 if (x + y) % 3 == 0 else 0.0) + n * 0.06
				"brick": value = 0.45 if y % 32 < 3 or (x + (16 if y / 32 % 2 == 0 else 0)) % 64 < 3 else 0.80 + n * 0.14
				"metal": value = 0.84 + n * 0.08 + sin(y * 2.0) * 0.025
				"grass": value = 0.66 + n * 0.22 + sin(x * 1.8 + y * 0.21) * 0.07
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	textures[kind] = result
	return result


static func map_texture(kind: String, map_name: String) -> Texture2D:
	var key := kind + ":" + map_name
	if textures.has(key):
		return textures[key]
	if SOURCE_IDS.has(kind):
		var path := "res://assets/materials/%s_1K-JPG_%s.jpg" % [SOURCE_IDS[kind], map_name]
		if ResourceLoader.exists(path):
			textures[key] = load(path)
			return textures[key]
	var fallback := Image.create(1, 1, false, Image.FORMAT_RGB8)
	fallback.fill(Color(0.5, 0.5, 1.0) if map_name == "NormalGL" else Color(0.94, 0.94, 0.94))
	var result := ImageTexture.create_from_image(fallback)
	textures[key] = result
	return result
