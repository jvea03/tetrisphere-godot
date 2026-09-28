class_name TSUI
extends RefCounted

## The menus' building blocks, in the hand-drawn style: cream paper cards with
## ink borders, chunky pastel buttons with a darker lip underneath, pill tabs,
## pop-up dialogs, the bottom nav bar, and the little bits of polish every
## screen shares (button squash and click, notes that float up out of a tab,
## dialogs that pop in). Everything is sized for the 720-wide portrait
## viewport and set in the device's handwriting font (TSToon.hand_font).

const INK := Color(0.27, 0.16, 0.19)
const MUTED := Color(0.45, 0.35, 0.38)   # secondary text: about 6:1 on paper (was 4.3:1)
const PAPER := Color(1.0, 0.96, 0.88)
const CARD := Color(1.0, 0.985, 0.95)
const PINK := Color(1.0, 0.62, 0.74)
const BUTTER := Color(1.0, 0.85, 0.45)
const MINT := Color(0.58, 0.87, 0.64)
const SKY := Color(0.60, 0.80, 1.0)
const LILAC := Color(0.80, 0.70, 0.98)
const PEACH := Color(1.0, 0.76, 0.60)
const CORAL := Color(1.0, 0.54, 0.58)
const GOLD := Color(1.0, 0.82, 0.30)
const GOLD_DARK := Color(0.93, 0.62, 0.16)
const GREEN := Color(0.56, 0.86, 0.54) # every "spend" and "go" button
const GREY := Color(0.86, 0.84, 0.84)
const RED_DOT := Color(1.0, 0.36, 0.42)

## Rarity colours: rims on collection tiles and the rarity pill.
const RARITY_COLORS := [Color(0.72, 0.72, 0.78), Color(0.52, 0.72, 1.0), Color(0.76, 0.56, 1.0), Color(1.0, 0.72, 0.24)]

const BORDER := 3
const WIDTH := 720.0

const HOW_TO_PLAY := "Tap the egg to aim your piece, double-tap to drop it. Drop a piece onto two or more of its own kind and the whole group pops. New pieces join as you go: the square, then the plus. Grey stones break when a piece beside them pops, or when you slide a piece into them (hold, then drag). A drop that matches nothing costs a heart. Dig a hole big enough and the little critter inside escapes!"


# -- styles and text -----------------------------------------------------------------

## A card or button face: fill, ink border, round corners, and `lip` px of
## thicker border along the bottom so it sits on the page like a sticker.
static func sb(bg: Color, radius := 22, border := BORDER, lip := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = INK
	s.set_border_width_all(border)
	s.border_width_bottom = border + lip
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6 + lip
	s.anti_aliasing = true
	return s


static func label(text: String, size := 26, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", TSToon.hand_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A label with a paper outline, for text set straight on a busy background.
static func outlined(l: Label, outline := PAPER, px := 8) -> Label:
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", px)
	return l


## A screen or dialog title: pink letters with a thick ink outline.
static func title(text: String, size := 44) -> Label:
	var l := label(text, size, PINK, HORIZONTAL_ALIGNMENT_CENTER)
	return outlined(l, INK, 12)


static func wrap(l: Label, width := 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l


# -- buttons ---------------------------------------------------------------------------

## A chunky pastel button: pressing it drops it onto its lip.
static func button(text: String, color := GREEN, font_size := 28, min_size := Vector2(0, 72), lip := 6) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", TSToon.hand_font())
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	restyle(b, color, lip)
	return b


static func restyle(b: Button, color: Color, lip := 6) -> void:
	var radius := int(minf(b.custom_minimum_size.y * 0.35, 26))
	b.add_theme_stylebox_override("normal", sb(color, radius, BORDER, lip, 18))
	b.add_theme_stylebox_override("hover", sb(color.lightened(0.08), radius, BORDER, lip, 18))
	var pressed := sb(color.darkened(0.06), radius, BORDER, maxi(lip - 4, 1), 18)
	pressed.content_margin_top += lip - maxi(lip - 4, 1)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", sb(GREY, radius, BORDER, lip, 18))


## A round (or square) button with an icon in it.
static func icon_button(icon: String, px := 84, color := CARD, idx := 0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	var radius := int(px * 0.32)
	b.add_theme_stylebox_override("normal", sb(color, radius, BORDER, 4, 4))
	b.add_theme_stylebox_override("hover", sb(color.lightened(0.06), radius, BORDER, 4, 4))
	b.add_theme_stylebox_override("pressed", sb(color.darkened(0.05), radius, BORDER, 1, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := TSIcon.make(icon, px * 0.7, idx)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = px * 0.13
	ic.offset_right = -px * 0.13
	ic.offset_top = px * 0.1
	ic.offset_bottom = -px * 0.16
	b.add_child(ic)
	b.set_meta("icon", ic)
	return b


## The round close button every dialog shares.
static func close_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var ic := TSIcon.make("close", 60)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	return b


# -- containers ---------------------------------------------------------------------------

static func card(color := CARD, radius := 26, pad := 18, lip := 4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, radius, BORDER, lip, pad))
	return p


static func pill(text: String, bg := BUTTER, size := 18, fg := INK) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, 99, 2, 0, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, fg, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.set_meta("label", l)
	return p


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.add_child(child)
	return c


static func spacer(px := 0.0, expand := false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(px, px)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.follow_focus = false
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


## A hand-drawn progress bar: ink-rimmed track, pastel fill.
static func bar(fill := GOLD, height := 26) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := sb(Color(1, 1, 1, 0.9), 99, 2, 0, 0)
	var fg := sb(fill, 99, 0, 0, 0)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


## A small red "something waiting" dot for a button's corner.
static func dot(parent: Control, px := 26.0) -> Panel:
	var d := Panel.new()
	var s := sb(RED_DOT, 99, 2, 0, 0)
	s.border_color = Color.WHITE
	d.add_theme_stylebox_override("panel", s)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.anchor_left = 1.0
	d.anchor_right = 1.0
	d.offset_left = -px * 0.8
	d.offset_right = px * 0.2
	d.offset_top = -px * 0.2
	d.offset_bottom = px * 0.8
	d.visible = false
	parent.add_child(d)
	return d


## A pill tab row. on_pick(index) runs on a tap; returns the row, with the
## buttons in its "buttons" meta and set_active via TSUI.style_tabs.
static func tabs(names: Array, on_pick: Callable, font_size := 24) -> PanelContainer:
	var wrap_panel := PanelContainer.new()
	wrap_panel.add_theme_stylebox_override("panel", sb(Color(1, 1, 1, 0.7), 99, 2, 0, 6))
	var row := hbox(6)
	wrap_panel.add_child(row)
	var buttons: Array = []
	for i in names.size():
		var b := Button.new()
		b.text = str(names[i])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", TSToon.hand_font())
		b.add_theme_font_size_override("font_size", font_size)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, INK)
		b.pressed.connect(func(): on_pick.call(i))
		row.add_child(b)
		buttons.append(b)
	wrap_panel.set_meta("buttons", buttons)
	style_tabs(wrap_panel, 0)
	return wrap_panel


static func style_tabs(tab_row: PanelContainer, active: int) -> void:
	var buttons: Array = tab_row.get_meta("buttons")
	for i in buttons.size():
		var b: Button = buttons[i]
		var on := i == active
		var face := sb(PINK if on else Color(1, 1, 1, 0.0), 99, BORDER if on else 0, 2 if on else 0, 14)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, face)


## The paper background for a 2D screen.
static func paper_rect() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = _PAPER_2D
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paper", PAPER)
	r.material = mat
	return r


const _PAPER_2D := """
shader_type canvas_item;
uniform vec4 paper : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 blush : source_color = vec4(1.0, 0.88, 0.89, 1.0);
uniform vec4 dots : source_color = vec4(0.99, 0.89, 0.89, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec3 col = mix(paper.rgb, blush.rgb, smoothstep(0.45, 1.0, UV.y));
	vec2 grid = FRAGCOORD.xy / 110.0;
	vec2 cell = floor(grid);
	vec2 centre = vec2(hash(cell), hash(cell + 7.0)) * 0.6 + 0.2;
	float r = 0.08 + 0.06 * hash(cell + 3.0);
	float m = (1.0 - smoothstep(r - 0.015, r, distance(fract(grid), centre))) * step(0.5, hash(cell + 11.0));
	col = mix(col, dots.rgb, m);
	col *= 1.0 - 0.04 * hash(floor(FRAGCOORD.xy / 2.0));
	COLOR = vec4(col, 1.0);
}
"""


# -- dialogs --------------------------------------------------------------------------------

## A pop-up: a dimmed backdrop and a centred card. Returns {root, panel, box}
## -- fill `box`; show with reveal(root, panel). Hidden until then.
static func dialog(parent: Control, width := 580.0, color := CARD) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 50
	root.visible = false
	var back := ColorRect.new()
	back.color = Color(INK, 0.45)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := card(color, 30, 26, 6)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var box := vbox(16)
	panel.add_child(box)
	parent.add_child(root)
	return {"root": root, "panel": panel, "box": box}


const REVEAL_SECONDS := 0.15


static func reveal(overlay: CanvasItem, panel: Control = null) -> void:
	if not is_instance_valid(overlay):
		return
	TSFX.finish_showers(overlay.get_tree())
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween().set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, REVEAL_SECONDS)
	if panel != null and is_instance_valid(panel):
		await overlay.get_tree().process_frame
		if not is_instance_valid(panel):
			return
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(0.9, 0.9)
		panel.create_tween().tween_property(panel, "scale", Vector2.ONE, REVEAL_SECONDS * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func conceal(overlay: CanvasItem) -> void:
	if not is_instance_valid(overlay) or not overlay.visible:
		return
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, REVEAL_SECONDS)
	tween.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.visible = false
			overlay.modulate.a = 1.0)


# -- polish ------------------------------------------------------------------------------

## Every button under `root` squashes on press, springs back with a little
## overshoot, and clicks. Safe to call again after a rebuild.
static func juice(root: Node) -> void:
	if root is BaseButton:
		_wire(root)
	for child in root.get_children():
		juice(child)


static func _wire(btn: BaseButton) -> void:
	if btn.has_meta("_juicy"):
		return
	btn.set_meta("_juicy", true)
	btn.button_down.connect(func(): _squash(btn, 0.93, false))
	btn.button_up.connect(func(): _squash(btn, 1.0, true))
	btn.tree_exiting.connect(func(): btn.scale = Vector2.ONE)
	if not btn.has_meta("silent"):
		btn.pressed.connect(func(): TSSfx.play("click"))


static func _squash(btn: BaseButton, target: float, overshoot: bool) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	btn.pivot_offset = btn.size / 2.0
	var step := btn.create_tween().tween_property(btn, "scale", Vector2(target, target), 0.16 if overshoot else 0.07)
	if overshoot:
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A little note that floats up out of `anchor` and fades: "Unlocks at level 5".
static func note(screen: Control, anchor: Control, text: String) -> void:
	if not is_instance_valid(screen) or not is_instance_valid(anchor):
		return
	var p := pill(text, CARD, 22)
	p.z_index = 100
	p.top_level = true
	screen.add_child(p)
	p.reset_size()
	var r := anchor.get_global_rect()
	var width := screen.get_viewport_rect().size.x
	p.global_position = Vector2(clampf(r.get_center().x - p.size.x * 0.5, 8.0, width - p.size.x - 8.0), r.position.y - p.size.y - 8.0)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", p.position.y - 28.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "modulate:a", 0.0, 0.6).set_delay(0.6)
	tw.chain().tween_callback(p.queue_free)


## A gentle breathe on a big button, to draw the eye (Home's PLAY).
static func breathe(c: Control, every := 3.2) -> void:
	var t := Timer.new()
	t.wait_time = every
	t.autostart = true
	c.add_child(t)
	t.timeout.connect(func():
		if not c.is_inside_tree() or (c is BaseButton and (c as BaseButton).is_pressed()):
			return
		c.pivot_offset = c.size / 2.0
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2(1.04, 1.04), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE))


## Safe-area insets in viewport units, for phones with a notch or cutout.
static func safe_top() -> float:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or not OS.has_feature("mobile"):
		return 0.0
	return maxf(float(DisplayServer.get_display_safe_area().position.y), 0.0) * WIDTH / float(win.x)


static func safe_bottom() -> float:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	return maxf(float(win.y - safe.end.y), 0.0) * WIDTH / float(win.x)


## "4h 12m" / "2d 5h" / "3:05".
static func fmt_duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	var d := seconds / 86400
	@warning_ignore("integer_division")
	var h := (seconds % 86400) / 3600
	@warning_ignore("integer_division")
	var m := (seconds % 3600) / 60
	if d > 0:
		return "%dd %dh" % [d, h]
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%d:%02d" % [m, seconds % 60]
