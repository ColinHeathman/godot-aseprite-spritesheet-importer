@tool
extends EditorPlugin

const AsepriteImportPlugin = preload("res://addons/aseprite_spritesheet_importer/import_plugin.gd")
const AsepritePluginConfig = preload("res://addons/aseprite_spritesheet_importer/plugin_config.gd")
const AsepriteExecutable = preload("res://addons/aseprite_spritesheet_importer/executable.gd")

var importer: AsepriteImportPlugin
var config: AsepritePluginConfig
var executable: AsepriteExecutable

func _enter_tree() -> void:

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
