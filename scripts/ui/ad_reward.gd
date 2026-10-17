class_name TSAdReward
extends RefCounted

## A rewarded ad behind one button: the win card's double coins, a chest's or a
## build's half hour off, the mine's and the login reward's doubling.
##
## watch() plays the ad and, once it is earned, calls grant() (the reward
## itself, banked even if the screen has gone) and then shown() (the button's
## screen catching up, skipped if it has gone). With Remove Ads there is no
## video: the reward is granted at once. While the ad runs the button is
## disabled and says so; an ad that doesn't finish gives the button back.


## The button's text: "Watch Ad · <what>", or "Free · <what>" with Remove Ads.
static func text(what: String) -> String:
	return ("Free  ·  %s" if TSProfile.no_ads else "Watch Ad  ·  %s") % what


## host: the screen a "didn't finish" note shows over.
static func watch(host: Control, button: Button, grant: Callable, shown: Callable = Callable()) -> void:
	if TSProfile.no_ads:
		grant.call()
		if shown.is_valid():
			shown.call()
		return
	var ads: Node = button.get_node("/root/Ads")
	if ads.is_busy():
		return
	var idle := button.text
	button.disabled = true
	button.text = "Ad playing..." if ads.simulated else "Loading ad..."
	ads.rewarded_result.connect(func(earned: bool) -> void:
		if earned:
			grant.call()
		if not is_instance_valid(button) or not button.is_inside_tree():
			return
		if earned:
			if shown.is_valid():
				shown.call()
			return
		button.disabled = false
		button.text = idle
		TSUI.note(host, button, "The ad didn't finish -- no reward this time."), CONNECT_ONE_SHOT)
	ads.show_rewarded()
