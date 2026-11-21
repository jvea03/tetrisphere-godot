@tool
extends EditorPlugin

# The game is locked to portrait, and Android takes screenOrientation="portrait"
# to mean the device must have a portrait screen
# (android.hardware.screen.portrait, required). Play then hides the game from
# devices it thinks can't do portrait -- Chromebooks, Google Play Games on PC,
# some tablets -- and warns about it. Declaring the feature as not required
# keeps the orientation lock and lets those devices install it.
var export_plugin: EggManifestExportPlugin


func _enter_tree():
	export_plugin = EggManifestExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class EggManifestExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(platform, debug):
		return '<uses-feature android:name="android.hardware.screen.portrait" android:required="false" />'

	func _get_name():
		return "EggManifest"
