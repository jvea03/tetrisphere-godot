class_name TSStickerCards
extends RefCounted

static var _counted := {}   # "date|player" already counted toward sticker quests (this run)

## The sticker cards Home and the leaderboards share: the stickers other
## players sent (each with a Block), and a player's card from a board, where
## a sticker is sent and a name can be blocked or reported.


## Shows the stickers waiting (Online.take_received), if any. Returns the
## dialog, or an empty one if there were none.
static func show_received(parent: Control) -> Dictionary:
	var got: Array = Online.take_received()
	if got.is_empty():
		return {}
	var d := TSUI.dialog(parent, 600)
	var box: VBoxContainer = d["box"]
	box.add_child(TSUI.ribbon("You got a sticker!" if got.size() == 1 else "You got stickers!", TSUI.PINK, 38, 470.0))
	var faces: Array = []
	for g: Dictionary in got.slice(0, 5):
		var row := TSUI.hbox(12)
		var face := TSIcon.make("sticker", 84, 0, str(g["sticker"]))
		row.add_child(face)
		faces.append(face)
		var v := TSUI.vbox(2)
		v.add_child(TSUI.label(str(g["name"]), 26))
		v.add_child(TSUI.label("sent you \"%s\"" % TSStickers.sticker_name(str(g["sticker"])), 20, TSUI.MUTED))
		row.add_child(TSUI.expand(v))
		var block := TSUI.button("Block", TSUI.CARD, 18, Vector2(96, 48), 3)
		block.pressed.connect(func() -> void:
			_block(str(g["from"]))
			block.disabled = true
			block.text = "Blocked")
		row.add_child(block)
		box.add_child(row)
	if got.size() > 5:
		box.add_child(TSUI.label("...and %d more" % (got.size() - 5), 20, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := TSUI.button("Nice!", TSUI.GREEN, 28)
	ok.pressed.connect(func() -> void:
		TSUI.conceal(d["root"])
		d["root"].queue_free.call_deferred())
	box.add_child(ok)
	TSSfx.play("popper")
	TSUI.reveal(d["root"], d["panel"])
	# Each sticker slaps on in turn.
	for k in faces.size():
		var f: Control = faces[k]
		f.modulate.a = 0.0
		var t := f.create_tween()
		t.tween_interval(0.2 + 0.15 * k)
		t.tween_callback(func() -> void:
			f.pivot_offset = f.size * 0.5
			f.scale = Vector2(2.2, 2.2)
			f.rotation = -0.5)
		t.tween_property(f, "modulate:a", 1.0, 0.05)
		t.parallel().tween_property(f, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(f, "rotation", 0.12 * (1 if k % 2 == 0 else -1), 0.18)
		t.tween_callback(func() -> void: TSSfx.play("snap"))
	return d


## A rival's card from a board: their critter, name and stars; the stickers
## this player owns, one tap to send; Block and Report. `changed` runs after
## a block (the board hides them).
static func show_player(parent: Control, entry: Dictionary, changed: Callable) -> void:
	var d := TSUI.dialog(parent, 600)
	var box: VBoxContainer = d["box"]
	var top := TSUI.hbox(14)
	top.add_child(TSIcon.make("critter", 96, int(entry.get("avatar", 0))))
	var v := TSUI.vbox(2)
	var who := TSUI.label(str(entry["name"]), 32)
	who.clip_text = true
	v.add_child(who)
	var stars := TSUI.hbox(6)
	stars.add_child(TSIcon.make("star", 30))
	stars.add_child(TSUI.label(str(entry["stars"]), 26))
	v.add_child(stars)
	top.add_child(TSUI.expand(v))
	box.add_child(top)
	box.add_child(TSUI.label("Send a sticker", 26, TSUI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var status := TSUI.label("Tap one to send it.", 20, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var buttons: Array = []
	for id: String in TSStickers.owned():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 118)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, TSUI.sb(TSUI.CARD if st != "pressed" else TSUI.BUTTER, 22, 3, 2, 4))
		var ic := TSIcon.make("sticker", 96, 0, id)
		ic.position = Vector2(11, 11)
		ic.size = Vector2(96, 96)
		b.add_child(ic)
		buttons.append(b)
		b.pressed.connect(func() -> void:
			for other: Button in buttons:
				other.disabled = true
			status.text = "Sending..."
			Online.send_sticker(str(entry.get("uid", "")), id, func(ok: bool) -> void:
				if not is_instance_valid(status):
					return
				if ok:
					# Sticker quests (daily, weekly, the 7-day event) count each player once a
					# day, so tapping one player five times isn't five stickers sent.
					var key := "%s|%s" % [TSClock.date_string(), entry.get("uid", "")]
					if not _counted.has(key):
						_counted[key] = true
						TSProfile.record_quest_event("sticker")
					status.text = "Sent \"%s\" to %s!" % [TSStickers.sticker_name(id), entry["name"]]
					TSSfx.play("pop1")
				else:
					status.text = "Couldn't send it. Check your connection."
					for other: Button in buttons:
						other.disabled = false))
		grid.add_child(b)
	var center := CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	box.add_child(status)
	box.add_child(TSUI.label("More stickers come from the Battle Pass.", 18, TSUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var row := TSUI.hbox(12)
	var block := TSUI.expand(TSUI.button("Block", TSUI.CARD, 22, Vector2(0, 60), 4)) as Button
	block.pressed.connect(func() -> void:
		_block(str(entry.get("uid", "")))
		TSUI.conceal(d["root"])
		changed.call())
	row.add_child(block)
	var report := TSUI.expand(TSUI.button("Report Name", TSUI.CARD, 22, Vector2(0, 60), 4)) as Button
	report.pressed.connect(func() -> void:
		Online.report(str(entry.get("uid", "")), str(entry["name"]))
		report.disabled = true
		report.text = "Reported")
	row.add_child(report)
	box.add_child(row)
	var close := TSUI.button("Close", TSUI.PINK, 26)
	close.pressed.connect(func() -> void:
		TSUI.conceal(d["root"])
		d["root"].queue_free.call_deferred())
	box.add_child(close)
	TSUI.reveal(d["root"], d["panel"])


## Blocks a player: no more of their stickers, and off this phone's boards.
static func _block(player: String) -> void:
	if player != "" and not TSProfile.blocked_players.has(player):
		TSProfile.blocked_players.append(player)
		TSProfile.save()
