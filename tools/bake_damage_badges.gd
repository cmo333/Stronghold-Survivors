extends SceneTree

## Bakes the damage-badge chroma key that main.gd used to redo on every load.
##
##   godot --headless --path . --script tools/bake_damage_badges.gd
##
## `_prepare_damage_badges()` walked all six 1024x1024 badges pixel by pixel in
## GDScript to knock the grey background out: 6.3 million interpreted
## get_pixel/set_pixel calls, measured at 4427.8 ms, paid on every scene load and
## every restart. It is a pure function of the art, so it belongs offline.
##
## Deliberately run inside Godot rather than as a Python tool alongside the other
## art scripts. The rule reads a pixel's RGB to decide its alpha -- including for
## pixels whose alpha is already zero -- and the texture importer has
## process/fix_alpha_border=true, which rewrites RGB underneath transparent
## pixels. So the imported image and the PNG on disk disagree exactly where this
## rule is most sensitive (measured: 2079 differing samples, all at alpha 0), and
## keying the file instead of the imported texture silently changes the result.
## Loading through load() here means the input is the same image the game was
## keying, so the output is the same image the game was drawing.

const NAMES := [
	"normal_small", "normal_large",
	"dot_small", "dot_large",
	"crit_small", "crit_large",
]
const SRC := "res://assets/ui_damage/%s.png"
const DST := "res://assets/ui_damage/%s_keyed.png"

func _initialize() -> void:
	_run()

# Transcribed from main.gd's _load_damage_badge() as it stood.
func _key(src: Image) -> Image:
	var img := Image.new()
	img.copy_from(src)
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			var max_c: float = max(c.r, max(c.g, c.b))
			var min_c: float = min(c.r, min(c.g, c.b))
			var chroma: float = max_c - min_c
			if chroma < 0.11 and max_c > 0.18 and max_c < 0.96:
				c.a = 0.0
			else:
				c.a = max(c.a, clampf((chroma - 0.06) / 0.45, 0.0, 1.0))
			img.set_pixel(x, y, c)
	return img

func _run() -> void:
	await process_frame
	var failed := 0
	for n in NAMES:
		var path: String = SRC % n
		var tex := load(path) as Texture2D
		if tex == null:
			print("MISSING source: ", path)
			failed += 1
			continue
		var t0 := Time.get_ticks_usec()
		var keyed := _key(tex.get_image())
		var out: String = (DST % n).replace("res://", "")
		var err := keyed.save_png(out)
		var opaque := 0
		for y in range(0, keyed.get_height(), 4):
			for x in range(0, keyed.get_width(), 4):
				if keyed.get_pixel(x, y).a > 0.0:
					opaque += 1
		var sampled: int = (keyed.get_height() / 4) * (keyed.get_width() / 4)
		print("%-14s keyed in %6.1f ms -> %s  err=%d  %.1f%% survives" % [
			n, (Time.get_ticks_usec() - t0) / 1000.0, out, err,
			100.0 * float(opaque) / float(sampled)])
		if err != OK:
			failed += 1
	print("FAILED: ", failed)
	quit()
