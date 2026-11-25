@tool
extends EditorPlugin

# The Meta (Facebook) SDK in Android exports, so Meta app-promotion ads can
# see installs and app opens. The SDK does NOT start by itself at process
# start: FacebookInitProvider (which calls sdkInitialize on the main thread
# during cold start, including file reads) is removed, and auto-init,
# auto-logging and advertiser-id collection are all off in the manifest.
# The game starts it through the EggAnalytics plugin (setMeta) only while
# analytics are allowed -- consent in the UK/EEA/Switzerland, the Settings
# switch everywhere (scripts/meta/analytics.gd sync_meta). setMeta waits
# until after the next frame and does the SDK work on a background thread.
# Once that finishes it still logs App Install and App Launch.
# Level 10 and the first lesson are standard events from that same plugin
# (logMetaEvent -> AppEventsLogger). They wait in a queue until that init
# finishes, and only while setMeta(true) is in force.
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
		# Auto-init, auto-log and advertiser-id collection stay off until
		# setMeta(true). AutoInitEnabled alone does not stop FacebookInitProvider
		# from calling sdkInitialize on the main thread at process start (file
		# reads, gatekeepers). tools:node="remove" drops that provider; the
		# app manifest declares xmlns:tools. ${applicationId} is the merger
		# placeholder, the same one facebook-core uses, so the two match.
		return "\n".join([
			'<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="fb%s" />' % _app_id(),
			'<meta-data android:name="com.facebook.sdk.ClientToken" android:value="%s" />' % _client_token(),
			'<meta-data android:name="com.facebook.sdk.AutoInitEnabled" android:value="false" />',
			'<meta-data android:name="com.facebook.sdk.AutoLogAppEventsEnabled" android:value="false" />',
			'<meta-data android:name="com.facebook.sdk.AdvertiserIDCollectionEnabled" android:value="false" />',
			'<provider android:name="com.facebook.internal.FacebookInitProvider" android:authorities="${applicationId}.FacebookInitProvider" tools:node="remove" />',
		])
