class_name TSFX
extends RefCounted

## The money moments (Duckdoku's RewardFX): a coin shower from where coins
## were earned into the wallet, sparkle bursts, confetti, "+N" pops and
## counting labels, plus the medal plates behind podium ranks.

const POP_SECONDS := 0.9
const COUNT_SECONDS := 0.5
const COL_GAIN := Color(0.86, 0.56, 0.12)
const COL_SPEND := Color(0.92, 0.36, 0.40)
const SHOWER_GROUP := "coin_shower"
const SHOWER_COINS := 8


static func pop_coin_change(screen_root: Control, anchor: Control, amount: int) -> void:
	if amount == 0 or not is_instance_valid(screen_root) or not is_instance_valid(anchor):
		return
	var lbl := TSUI.outlined(TSUI.label(("+" if amount > 0 else "") + TSProfile.fmt_coins(amount), 26, COL_GAIN if amount > 0 else COL_SPEND), TSUI.PAPER, 6)
	lbl.z_index = 100
	lbl.top_level = true
	screen_root.add_child(lbl)
	lbl.reset_size()
	var r := anchor.get_global_rect()
	var w := screen_root.get_viewport_rect().size.x
	var x := r.end.x + 6.0
	if x + lbl.size.x > w - 6.0:
		x = r.position.x - lbl.size.x - 6.0
	lbl.global_position = Vector2(x, r.position.y)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 36.0, POP_SECONDS).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 0.0, POP_SECONDS * 0.6).set_delay(POP_SECONDS * 0.4)
	tw.chain().tween_callback(lbl.queue_free)


static func count_label(label: Label, from_value: int, to_value: int, duration := COUNT_SECONDS) -> void:
	if not is_instance_valid(label):
		return
	if from_value == to_value:
		label.text = TSProfile.fmt_coins(to_value)
		return
	label.text = TSProfile.fmt_coins(from_value)
	label.create_tween().tween_method(func(v: float):
		if is_instance_valid(label):
			label.text = TSProfile.fmt_coins(int(round(v))), float(from_value), float(to_value), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


const MEDAL_COLORS := [Color(1.0, 0.82, 0.3), Color(0.84, 0.86, 0.9), Color(0.92, 0.66, 0.46)]

## A gold / silver / bronze disc behind a podium rank; past third, the bare label.
static func medal_plate(rank: int, rank_label: Control) -> Control:
	if rank < 1 or rank > MEDAL_COLORS.size():
		return rank_label
	var medal := PanelContainer.new()
	medal.add_theme_stylebox_override("panel", TSUI.sb(MEDAL_COLORS[rank - 1], 99, 3, 2, 0))
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.add_child(rank_label)
	return medal


static func sparkle_burst(screen_root: Control, anchor: Control) -> void:
	if is_instance_valid(anchor):
		sparkle_burst_at(screen_root, anchor.get_global_rect())


static func sparkle_burst_at(screen_root: Control, rect: Rect2) -> void:
	if not is_instance_valid(screen_root):
		return
	var centre := rect.get_center()
	var reach := maxf(rect.size.x, rect.size.y) * 0.75 + 20.0
	var colors := [Color(1.0, 0.86, 0.36), Color(1, 1, 1), Color(1.0, 0.66, 0.78)]
	for i in 12:
		var star := TSIcon.make("star", 1)
		star.tint = colors[i % colors.size()]
		var s := randf_range(18.0, 34.0)
		star.size = Vector2(s, s)
		star.pivot_offset = star.size / 2.0
		star.z_index = 100
		star.top_level = true
		screen_root.add_child(star)
		var a := TAU * float(i) / 12.0 + randf_range(-0.25, 0.25)
		star.global_position = centre + Vector2(cos(a), sin(a)) * rect.size.x * 0.15 - star.size / 2.0
		star.scale = Vector2(0.2, 0.2)
		var target := centre + Vector2(cos(a), sin(a)) * randf_range(reach * 0.7, reach) - star.size / 2.0
		var tw := star.create_tween().set_parallel(true)
		tw.tween_property(star, "global_position", target, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "rotation", randf_range(-PI, PI), 0.75)
		tw.tween_property(star, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "scale", Vector2(0.1, 0.1), 0.38).set_delay(0.37)
		tw.tween_property(star, "modulate:a", 0.0, 0.3).set_delay(0.45)
		tw.chain().tween_callback(star.queue_free)


## Paper confetti bursting up from two points and fluttering down.
static func confetti(screen_root: Control) -> void:
	if not is_instance_valid(screen_root):
		return
	var area := screen_root.get_viewport_rect().size
	var colors := [TSUI.PINK, TSUI.BUTTER, TSUI.MINT, TSUI.SKY, TSUI.LILAC, Color.WHITE]
	for i in 46:
		var piece := ColorRect.new()
		piece.color = colors[i % colors.size()]
		piece.size = Vector2(randf_range(10.0, 16.0), randf_range(14.0, 24.0))
		piece.pivot_offset = piece.size / 2.0
		piece.top_level = true
		piece.z_index = 90
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_root.add_child(piece)
		var origin := Vector2(area.x * (0.18 if i % 2 == 0 else 0.82), area.y * 0.2)
		var out := randf_range(-1.0, 1.0) * area.x * 0.45
		var peak := randf_range(90.0, 250.0)
		var fall := area.y * randf_range(0.45, 0.75)
		var sway := randf_range(14.0, 36.0)
		var turns := randf_range(2.0, 5.0) * (1.0 if randf() < 0.5 else -1.0)
		var path := func(p: float) -> void:
			var rise := minf(p / 0.18, 1.0)
			var y := -peak * (1.0 - pow(1.0 - rise, 2.0)) + fall * pow(maxf(p - 0.18, 0.0) / 0.82, 1.3)
			var x := out * (1.0 - pow(1.0 - p, 2.0)) + sin(p * TAU * 2.0 + float(i)) * sway * p
			piece.global_position = origin + Vector2(x, y) - piece.size / 2.0
			piece.rotation = p * TAU * turns
			piece.scale.y = absf(cos(p * TAU * turns * 0.7)) * 0.8 + 0.2
			piece.modulate.a = 1.0 - maxf(p - 0.75, 0.0) / 0.25
		path.call(0.0)
		var t := piece.create_tween()
		t.tween_interval(randf_range(0.0, 0.12))
		t.tween_method(path, 0.0, 1.0, randf_range(1.6, 2.4))
		t.tween_callback(piece.queue_free)


## The coin reward: stars burst where the coins came from, a big "+N" rises,
## coins fly to the wallet, and the wallet counts up as they land.
static func coin_shower(screen_root: Control, from: Rect2, wallet_coin: Control, wallet_label: Label, from_coins: int, to_coins: int) -> void:
	if not is_instance_valid(screen_root) or to_coins <= from_coins:
		if is_instance_valid(wallet_label):
			count_label(wallet_label, from_coins, to_coins)
		return
	TSSfx.play("coin")
	sparkle_burst_at(screen_root, from)
	_rise_amount(screen_root, from.get_center(), "+%s" % TSProfile.fmt_coins(to_coins - from_coins))
	var land := wallet_coin.get_global_rect().get_center()
	var finish := func() -> void:
		if is_instance_valid(wallet_label):
			wallet_label.text = TSProfile.fmt_coins(to_coins)
	if is_instance_valid(wallet_label):
		wallet_label.text = TSProfile.fmt_coins(from_coins)
	for i in SHOWER_COINS:
		var coin := TSIcon.make("coin", 34)
		coin.size = Vector2(34, 34)
		coin.top_level = true
		coin.z_index = 99
		coin.add_to_group(SHOWER_GROUP)
		coin.set_meta("finish", finish)
		screen_root.add_child(coin)
		coin.global_position = from.get_center() + Vector2(randf_range(-30, 30), randf_range(-24, 24)) - coin.size / 2.0
		var t := coin.create_tween()
		t.tween_interval(0.3 + i * 0.05)
		t.tween_property(coin, "global_position", land - coin.size / 2.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(coin.queue_free)
		if i == 0:
			t.tween_callback(func():
				TSHaptics.light()
				count_label(wallet_label, from_coins, to_coins, COUNT_SECONDS + SHOWER_COINS * 0.05))
		t.tween_callback(func(): _kick(wallet_coin))


## Lands every shower still in flight at once (a pop-up is opening over it).
static func finish_showers(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(SHOWER_GROUP):
		if node.has_meta("finish"):
			(node.get_meta("finish") as Callable).call()
		node.queue_free()


static func _rise_amount(screen_root: Control, centre: Vector2, text: String) -> void:
	var lbl := TSUI.outlined(TSUI.label(text, 60, TSUI.GOLD), TSUI.INK, 12)
	lbl.add_to_group(SHOWER_GROUP)
	lbl.top_level = true
	lbl.z_index = 100
	screen_root.add_child(lbl)
	lbl.reset_size()
	lbl.global_position = centre - lbl.size / 2.0
	lbl.pivot_offset = lbl.size / 2.0
	lbl.scale = Vector2(0.4, 0.4)
	var t := lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "global_position:y", lbl.global_position.y - 100.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.75)
	t.chain().tween_callback(lbl.queue_free)


static func _kick(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(1.2, 1.2)
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.12)
