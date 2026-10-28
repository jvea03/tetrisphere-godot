@tool
extends EditorPlugin

# Puts the EggReview AAR, and the Play Review library it calls, into Android
# exports; the game reaches it as the "EggReview" singleton (scripts/screens/home.gd).
var export_plugin: EggReviewExportPlugin


func _enter_tree():
	export_plugin = EggReviewExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class EggReviewExportPlugin extends EditorExportPlugin:
	const NAME := "EggReview"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug):
		var kind := "debug" if debug else "release"
		return PackedStringArray([NAME + "/bin/%s/%s-%s.aar" % [kind, NAME, kind]])

	func _get_android_dependencies(platform, debug):
		return PackedStringArray(["com.google.android.play:review:2.0.2"])

	func _get_name():
		return NAME
