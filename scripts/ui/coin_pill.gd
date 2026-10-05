class_name TSCoinPill
extends PanelContainer

## The wallet: a cream pill with a coin and the player's total (Duckdoku's
## CoinWallet). receive() plays the coin shower into it; spend() counts down.
## Optionally a button to the Shop (Home's coin bar is).

var coin: TSIcon
var label: Label


func _init(tappable := false) -> void:
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", TSUI.sb(TSUI.CARD, 99, 3, 3, 10))
	var row := TSUI.hbox(8)
	add_child(row)
	coin = TSIcon.make("coin", 40)
	row.add_child(coin)
	label = TSUI.label("0", 28)
	label.custom_minimum_size.x = 96
	row.add_child(label)
	if tappable:
		var plus := TSIcon.make("plus", 34)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(plus)
	sync()


func sync() -> void:
	label.text = TSProfile.fmt_wallet(TSProfile.coin_count)


func receive(from: Rect2, before: int, after: int) -> void:
	var scene := get_tree().current_scene as Control
	if scene == null:
		scene = get_parent() as Control
	TSFX.coin_shower(scene, from, coin, label, before, after)


func spend(before: int, after: int) -> void:
	TSFX.count_label(label, before, after)
	TSFX.pop_coin_change(get_tree().current_scene as Control, label, after - before)
