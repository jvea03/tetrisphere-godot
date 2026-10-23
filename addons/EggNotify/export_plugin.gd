@tool
extends EditorPlugin

# Puts the EggNotify AAR into Android exports; the game reaches it as the
# "EggNotify" singleton (scripts/meta/notify.gd).
var export_plugin: EggNotifyExportPlugin


func _enter_tree():
	export_plugin = EggNotifyExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class EggNotifyExportPlugin extends EditorExportPlugin:
	const NAME := "EggNotify"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug):
		var kind := "debug" if debug else "release"
		return PackedStringArray([NAME + "/bin/%s/%s-%s.aar" % [kind, NAME, kind]])

	func _get_name():
		return NAME
