@tool
class_name AsepritePlugin
extends EditorPlugin

var importer: AsepriteImportPlugin
var config: AsepritePluginConfig
var executable: AsepriteExecutable

func _enter_tree():

	# Configuration
	config = AsepritePluginConfig.new()
	config.editor_settings = self.get_editor_interface().get_editor_settings()
	config.setup_editor_settings()

	# Executable
	executable = AsepriteExecutable.new()
	executable.config = config

	# Importer
	importer = AsepriteImportPlugin.new()
	importer.editor = self.get_editor_interface()
	importer.executable = executable
	add_import_plugin(importer)

func _exit_tree():
	remove_import_plugin(importer)
