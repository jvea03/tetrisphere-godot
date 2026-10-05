# Cuts the critter sticker sheets in art/critter_sheets/ (art/ is kept out of
# the build) into one 256 x 256 transparent PNG per sticker,
# icons/critters/NNN.png, numbered sheet by sheet, row by row, left to right.
# The sheets are transparent around their stickers: each solid island is a
# sticker, with its soft edge and shadow kept and its neighbors cut away.
# Prints each sticker's body color for profile.gd.
# Run with:
#   Godot.exe --headless --path . --script res://tools/cut_critters.gd
extends SceneTree

const SHEETS := "res://art/critter_sheets"
const OUT := "res://icons/critters"
const SIZE := 256
const PAD := 4
const MIN_AREA := 6000   # specks and stray sparkles are smaller
const TALL := 520        # taller than any one sticker
const SOLID := 200       # alpha: anything fainter is the background (or a shadow)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var files := []
	for f in DirAccess.get_files_at(SHEETS):
		if f.ends_with(".webp") or f.ends_with(".png"):
			files.append(f)
	files.sort()
	var n := 0
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SHEETS + "/" + f))
		img.convert(Image.FORMAT_RGBA8)
		for s in _cut(img):
			s["image"].save_png(ProjectSettings.globalize_path("%s/%03d.png" % [OUT, n]))
			print("%03d  %s  %s  %s" % [n, f, s["rect"], s["color"].to_html(false)])
			n += 1
	print("%d stickers" % n)
	quit(0)


func _cut(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	# 0 unseen, 1 background, 2+ a sticker's label
	var lab := PackedInt32Array()
	lab.resize(w * h)
	var q := PackedInt32Array()
	for x in w:
		q.append(x)
		q.append((h - 1) * w + x)
	for y in h:
		q.append(y * w)
		q.append(y * w + w - 1)
	var head := 0
	while head < q.size():
		var p := q[head]
		head += 1
		if lab[p] != 0 or not _clear(px, p):
			continue
		lab[p] = 1
		var x := p % w
		if x > 0: q.append(p - 1)
		if x < w - 1: q.append(p + 1)
		if p >= w: q.append(p - w)
		if p < w * (h - 1): q.append(p + w)
	# label what's left
	var comps := []
	var next := 2
	for start in w * h:
		if lab[start] != 0:
			continue
		var r := Rect2i(start % w, start / w, 1, 1)
		var area := 0
		q = PackedInt32Array([start])
		lab[start] = next
		head = 0
		while head < q.size():
			var p := q[head]
			head += 1
			area += 1
			var x := p % w
			var y := p / w
			r = r.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
			for nb in [p - 1 if x > 0 else -1, p + 1 if x < w - 1 else -1, p - w, p + w]:
				if nb >= 0 and nb < w * h and lab[nb] == 0:
					lab[nb] = next
					q.append(nb)
		if area >= MIN_AREA and r.size.y > TALL:
			# two stickers touching, one over the other: part them at the
			# thinnest row through their middle
			var cut := r.position.y + r.size.y / 2
			var thinnest := w
			for y in range(r.position.y + r.size.y * 3 / 10, r.position.y + r.size.y * 7 / 10):
				var row := 0
				for x in range(r.position.x, r.end.x):
					row += int(lab[y * w + x] == next)
				if row < thinnest:
					thinnest = row
					cut = y
			for y in range(cut, r.end.y):
				for x in range(r.position.x, r.end.x):
					if lab[y * w + x] == next:
						lab[y * w + x] = next + 1
			comps.append({"label": next, "rect": Rect2i(r.position.x, r.position.y, r.size.x, cut - r.position.y)})
			comps.append({"label": next + 1, "rect": Rect2i(r.position.x, cut, r.size.x, r.end.y - cut)})
			next += 1
		elif area >= MIN_AREA:
			comps.append({"label": next, "rect": r})
		next += 1
	# reading order: rows by center height, then left to right
	comps.sort_custom(func(a, b): return a["rect"].get_center().y < b["rect"].get_center().y)
	var rows := []
	for c in comps:
		if rows.is_empty() or c["rect"].get_center().y - rows[-1][0]["rect"].get_center().y > 120:
			rows.append([])
		rows[-1].append(c)
	var out := []
	for row in rows:
		row.sort_custom(func(a, b): return a["rect"].get_center().x < b["rect"].get_center().x)
		for c in row:
			out.append(_sticker(img, lab, c["label"], c["rect"].grow(PAD).intersection(Rect2i(0, 0, w, h))))
	return out


func _clear(px: PackedByteArray, p: int) -> bool:
	return px[p * 4 + 3] < SOLID


func _sticker(img: Image, lab: PackedInt32Array, label: int, r: Rect2i) -> Dictionary:
	var w := img.get_width()
	# hug the sticker's own pixels (a split one's rect is the pair's width)
	var tight := Rect2i()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if lab[y * w + x] == label:
				tight = Rect2i(x, y, 1, 1) if tight.size == Vector2i.ZERO else tight.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	r = tight.grow(PAD).intersection(Rect2i(0, 0, w, img.get_height()))
	var crop := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	# its body color: the commonest color (ink aside) low in the middle,
	# under any hat
	var body := Rect2i(r.position + Vector2i(r.size.x / 4, r.size.y * 2 / 5), Vector2i(r.size.x / 2, r.size.y / 2))
	var buckets := {}
	for y in r.size.y:
		for x in r.size.x:
			var sx := r.position.x + x
			var sy := r.position.y + y
			var c := img.get_pixel(sx, sy)
			var l := lab[sy * w + sx]
			if l == label or l == 1:
				crop.set_pixel(x, y, c)
				if l == label and c.v > 0.3 and body.has_point(Vector2i(sx, sy)):
					var key := Vector3i(int(c.r * 15.99), int(c.g * 15.99), int(c.b * 15.99))
					if not buckets.has(key):
						buckets[key] = [0, Vector3.ZERO]
					buckets[key][0] += 1
					buckets[key][1] += Vector3(c.r, c.g, c.b)
			else:
				crop.set_pixel(x, y, Color(1, 1, 1, 0))
	var k := float(SIZE - 2 * PAD) / maxf(r.size.x, r.size.y)
	crop.resize(maxi(1, roundi(r.size.x * k)), maxi(1, roundi(r.size.y * k)), Image.INTERPOLATE_LANCZOS)
	var square := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	square.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), (Vector2i(SIZE, SIZE) - crop.get_size()) / 2)
	var best := [1, Vector3.ONE]
	for b in buckets.values():
		if b[0] > best[0]:
			best = b
	var avg: Vector3 = best[1] / float(best[0])
	return {"image": square, "rect": r, "color": Color(avg.x, avg.y, avg.z)}
