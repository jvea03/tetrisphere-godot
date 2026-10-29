@tool
extends EditorPlugin

# Puts the EggAnalytics AAR, and the Firebase Analytics library it calls, into Android
# exports; the game reaches it as the "EggAnalytics" singleton (scripts/meta/analytics.gd).
var export_plugin: EggAnalyticsExportPlugin


func _enter_tree():
	export_plugin = EggAnalyticsExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class EggAnalyticsExportPlugin extends EditorExportPlugin:
	const NAME := "EggAnalytics"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug):
		var kind := "debug" if debug else "release"
		return PackedStringArray([NAME + "/bin/%s/%s-%s.aar" % [kind, NAME, kind]])

	func _get_android_dependencies(platform, debug):
		return PackedStringArray(["com.google.firebase:firebase-analytics:22.1.2"])

	func _get_name():
		return NAME
