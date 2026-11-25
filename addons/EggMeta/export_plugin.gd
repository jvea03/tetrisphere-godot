@tool
extends EditorPlugin

# The Meta (Facebook) SDK in Android exports, so Meta app-promotion ads can
# see installs and app opens. The SDK does NOT start by itself: the manifest
# turns auto-init and auto-logging off, and the game starts it through the
# EggAnalytics plugin (setMeta) only while analytics are allowed -- consent in
# the UK/EEA/Switzerland, the Settings switch everywhere (scripts/meta/analytics.gd
# sync_meta). Once started it logs App Install and App Launch by itself.
# Level 10 and the first lesson are standard events from that same plugin
# (logMetaEvent -> AppEventsLogger), and only while setMeta(true) is in force.
#
# The Meta app's IDs come from Project Settings: tetrisphere/meta_app_id and
# tetrisphere/meta_client_token (both shipped inside every app, not secrets).
# While either is empty, nothing is added and the build is as before.
var export_plugin: EggMetaExportPlugin


func _enter_tree():
	export_plugin = EggMetaExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class EggMetaExportPlugin extends EditorExportPlugin:
	const SDK := "com.facebook.android:facebook-core:19.0.1"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_name():
		return "EggMeta"

	func _app_id() -> String:
		return str(ProjectSettings.get_setting("tetrisphere/meta_app_id", "")).strip_edges()

	func _client_token() -> String:
		return str(ProjectSettings.get_setting("tetrisphere/meta_client_token", "")).strip_edges()

	func _ready_to_add() -> bool:
		return _app_id() != "" and _client_token() != ""

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if features.has("android") and not _ready_to_add():
			push_warning("EggMeta: tetrisphere/meta_app_id or meta_client_token is empty; the Meta SDK is left out of this build")

	func _get_android_dependencies(platform, debug):
		return PackedStringArray([SDK]) if _ready_to_add() else PackedStringArray()

	func _get_android_manifest_application_element_contents(platform, debug):
		if not _ready_to_add():
			return ""
		# A bare number would be read as an integer, which the SDK refuses: an
		# app id in the manifest goes in with an "fb" prefix, which it strips.
		return "\n".join([
			'<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="fb%s" />' % _app_id(),
			'<meta-data android:name="com.facebook.sdk.ClientToken" android:value="%s" />' % _client_token(),
			'<meta-data android:name="com.facebook.sdk.AutoInitEnabled" android:value="false" />',
			'<meta-data android:name="com.facebook.sdk.AutoLogAppEventsEnabled" android:value="false" />',
			'<meta-data android:name="com.facebook.sdk.AdvertiserIDCollectionEnabled" android:value="true" />',
		])
