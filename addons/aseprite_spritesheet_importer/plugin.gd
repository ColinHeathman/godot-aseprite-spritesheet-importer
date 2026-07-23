@tool
extends EditorPlugin

const AsepriteImportPlugin = preload("res://addons/aseprite_spritesheet_importer/import_plugin.gd")
const AsepritePluginConfig = preload("res://addons/aseprite_spritesheet_importer/plugin_config.gd")
const AsepriteExecutable = preload("res://addons/aseprite_spritesheet_importer/executable.gd")

# (PROOF OF CONCEPT)
# we set the settings to "application/config/name" to follow godot Project Settings practice [https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#description]
const SETTING_SPRITEFRAME_DIR = "aseprite_importer/defaults/spriteframe_directory"
const SETTING_ATLAS_DIR = "aseprite_importer/defaults/atlas_directory"

var importer: AsepriteImportPlugin
var config: AsepritePluginConfig
var executable: AsepriteExecutable

func _enter_tree() -> void:
	# (PROOF OF CONCEPT) 
	# this creates project settings for spriteframe/atlas dir default when the plugin is activated
	_setup_project_settings()

	# Configuration
	config = AsepritePluginConfig.new()
	config.editor_settings = EditorInterface.get_editor_settings()
	config.setup_editor_settings()

	# Executable
	executable = AsepriteExecutable.new()
	executable.config = config

	# Importer
	importer = AsepriteImportPlugin.new()
	importer.editor = self.get_editor_interface()
	importer.executable = executable
	add_import_plugin(importer)

func _exit_tree() -> void:
	remove_import_plugin(importer)

# (PROOF OF CONCEPT) 
# function that adds project settings defaults for spriteframe/atlas directory and allows the user to set them
func _setup_project_settings() -> void:
	_add_project_setting(SETTING_SPRITEFRAME_DIR, "", TYPE_STRING, PROPERTY_HINT_DIR)
	_add_project_setting(SETTING_ATLAS_DIR, "", TYPE_STRING, PROPERTY_HINT_DIR)

# (PROOF OF CONCEPT)
# function that takes in a values to setup a project setting directory entry and saves it
func _add_project_setting(setting_name: String, default_value: Variant, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	var is_new: bool = not ProjectSettings.has_setting(setting_name)
	if is_new:
		ProjectSettings.set_setting(setting_name, default_value)

	ProjectSettings.set_initial_value(setting_name, default_value)

	var property_info: Dictionary = {
		"name": setting_name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}

	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_as_basic(setting_name, true)
	
	# Save only when creating the setting for the first time
	if is_new:
		ProjectSettings.save()
