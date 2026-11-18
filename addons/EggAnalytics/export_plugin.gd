@tool
extends EditorPlugin

# Firebase Analytics in exports; the game reaches it as the "EggAnalytics"
# singleton (scripts/meta/analytics.gd).
# - Android: the EggAnalytics AAR and the Firebase Analytics library it calls.
# - iOS: the EggAnalytics plugin (ios/plugins/egganalytics.gdip, built by
#   tools/ios-setup.sh from ios_plugins/egganalytics) calls Firebase by name, and
#   this adds Firebase itself to the Xcode project as a Swift package. Godot 4.8+
#   takes the package directly; on 4.7 a local package (egg_spm/) is written and
#   project.pbxproj is patched to use it, the way the AdMob addon does its own.
var export_plugin: EggAnalyticsExportPlugin


func _enter_tree():
	export_plugin = EggAnalyticsExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class EggAnalyticsExportPlugin extends EditorExportPlugin:
	const NAME := "EggAnalytics"
	## Firebase's Swift package; FirebaseAnalytics leaves out the advertising-ID
	## (IDFA) support, which would be the separate FirebaseAnalyticsIdentitySupport.
	const FIREBASE_URL := "https://github.com/firebase/firebase-ios-sdk.git"
	const FIREBASE_VERSION := "11.15.0"
	const FIREBASE_PRODUCTS := ["FirebaseAnalytics"]
	const SPM_DIR := "egg_spm"
	const SPM_NAME := "EggAnalyticsDeps"
	# Object ids for the pbxproj patch: 24 hex digits, unlike the AdMob addon's AD00...
	const REF_ID := "EE0000000000000000000001"
	const PRODUCT_ID := "EE0000000000000000000002"
	const BUILD_FILE_ID := "EE0000000000000000000003"

	var _ios_path := ""
	var _patched := false

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid or platform is EditorExportPlatformIOS

	func _get_android_libraries(platform, debug):
		var kind := "debug" if debug else "release"
		return PackedStringArray([NAME + "/bin/%s/%s-%s.aar" % [kind, NAME, kind]])

	func _get_android_dependencies(platform, debug):
		return PackedStringArray(["com.google.firebase:firebase-analytics:22.1.2"])

	func _get_name():
		return NAME

	func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
		_ios_path = ""
		_patched = false
		if not features.has("ios"):
			return
		if not FileAccess.file_exists("res://ios/plugins/egganalytics.gdip"):
			push_warning("EggAnalytics: ios/plugins/egganalytics.gdip is missing (run tools/ios-setup.sh); iOS builds will send nothing to Firebase")
		if has_method("add_apple_embedded_platform_spm_package"):
			call("add_apple_embedded_platform_spm_package", FIREBASE_URL, FIREBASE_VERSION, PackedStringArray(FIREBASE_PRODUCTS))
			return
		_ios_path = path

	func _end_generate_apple_embedded_project(path: String, _will_build_archive: bool) -> void:
		_add_package(path)

	func _export_end() -> void:
		if not _patched and _ios_path != "":
			_add_package(_ios_path)

	func _add_package(path: String) -> void:
		if _patched or _ios_path == "":
			return
		_patched = true
		var dir := path.get_base_dir()
		_write_package(dir)
		var pbx := dir.path_join(path.get_file().get_basename() + ".xcodeproj/project.pbxproj")
		if FileAccess.file_exists(pbx):
			_patch_pbxproj(pbx)
		else:
			push_warning("EggAnalytics: no project.pbxproj at %s; Firebase not added" % pbx)

	func _write_package(dir: String) -> void:
		var src := dir.path_join(SPM_DIR).path_join(SPM_NAME)
		DirAccess.make_dir_recursive_absolute(src)
		var products := ""
		for p: String in FIREBASE_PRODUCTS:
			products += '                .product(name: "%s", package: "firebase-ios-sdk"),\n' % p
		var manifest := """// swift-tools-version:5.9
// Written by addons/EggAnalytics/export_plugin.gd: Firebase for the EggAnalytics plugin.
import PackageDescription

let package = Package(
    name: "%s",
    platforms: [.iOS(.v15)],
    products: [.library(name: "%s", targets: ["%s"])],
    dependencies: [
        .package(url: "%s", exact: "%s"),
    ],
    targets: [
        .target(
            name: "%s",
            dependencies: [
%s            ],
            path: "%s"
        )
    ]
)
""" % [SPM_NAME, SPM_NAME, SPM_NAME, FIREBASE_URL, FIREBASE_VERSION, SPM_NAME, products, SPM_NAME]
		_store(dir.path_join(SPM_DIR).path_join("Package.swift"), manifest)
		_store(src.path_join("Dummy.swift"), "// Dummy: a package target needs a source file.\nimport Foundation\n\npublic struct %s {\n    public init() {}\n}\n" % SPM_NAME)

	func _store(file_path: String, text: String) -> void:
		var f := FileAccess.open(file_path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()

	## Adds the local package to the app target, as Xcode itself would. Works
	## whether or not the AdMob addon has patched the file first.
	func _patch_pbxproj(pbx: String) -> void:
		var c := FileAccess.get_file_as_string(pbx)
		if c.is_empty() or c.contains(REF_ID):
			return
		if not c.contains("/* Begin XCLocalSwiftPackageReference section */"):
			c = c.replace("/* End PBXGroup section */", "/* End PBXGroup section */\n\n/* Begin XCLocalSwiftPackageReference section */\n/* End XCLocalSwiftPackageReference section */")
		if not c.contains("/* Begin XCSwiftPackageProductDependency section */"):
			c = c.replace("/* End XCLocalSwiftPackageReference section */", "/* End XCLocalSwiftPackageReference section */\n\n/* Begin XCSwiftPackageProductDependency section */\n/* End XCSwiftPackageProductDependency section */")
		var ref := '%s /* XCLocalSwiftPackageReference "%s" */' % [REF_ID, SPM_DIR]
		c = c.replace("/* End XCLocalSwiftPackageReference section */",
			'\t\t%s = {\n\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = "%s";\n\t\t};\n/* End XCLocalSwiftPackageReference section */' % [ref, SPM_DIR])
		c = c.replace("/* End XCSwiftPackageProductDependency section */",
			'\t\t%s /* %s */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = %s;\n\t\t\tproductName = "%s";\n\t\t};\n/* End XCSwiftPackageProductDependency section */' % [PRODUCT_ID, SPM_NAME, ref, SPM_NAME])
		c = c.replace("/* Begin PBXBuildFile section */",
			"/* Begin PBXBuildFile section */\n\t\t%s /* %s in Frameworks */ = {isa = PBXBuildFile; productRef = %s /* %s */; };" % [BUILD_FILE_ID, SPM_NAME, PRODUCT_ID, SPM_NAME])
		if c.contains("$spm_packages"):
			# The template's placeholder sits inside packageReferences, so AdMob
			# (patching after this) still finds "packageReferences = (".
			c = c.replace("$spm_packages", ref + ",")
		elif c.contains("packageReferences = ("):
			c = c.replace("packageReferences = (", "packageReferences = (\n\t\t\t\t%s," % ref)
		else:
			c = c.replace("productRefGroup =", "packageReferences = (\n\t\t\t\t%s,\n\t\t\t);\n\t\t\tproductRefGroup =" % ref)
		if c.contains("packageProductDependencies = ("):
			c = c.replace("packageProductDependencies = (", "packageProductDependencies = (\n\t\t\t\t%s /* %s */," % [PRODUCT_ID, SPM_NAME])
		else:
			c = c.replace("buildRules = (", "packageProductDependencies = (\n\t\t\t\t%s /* %s */,\n\t\t\t);\n\t\t\tbuildRules = (" % [PRODUCT_ID, SPM_NAME])
		var phase := c.find("isa = PBXFrameworksBuildPhase;")
		if phase != -1:
			var files := c.find("files = (", phase)
			if files != -1:
				c = c.insert(files + 9, "\n\t\t\t\t%s /* %s in Frameworks */," % [BUILD_FILE_ID, SPM_NAME])
		_store(pbx, c)
		print("EggAnalytics: added Firebase %s (Swift package) to %s" % [FIREBASE_VERSION, pbx.get_file()])
