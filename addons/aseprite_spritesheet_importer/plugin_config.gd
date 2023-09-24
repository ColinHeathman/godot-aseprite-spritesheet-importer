@tool
class_name AsepritePluginConfig
extends RefCounted

const command_key = "aseprite/general/command_path"
const command_default_value = "aseprite"

var editor_settings: EditorSettings

func setup_editor_settings() -> void:
	if not self.editor_settings.has_setting(command_key):
		self.editor_settings.set_initial_value(command_key, command_default_value, false)
		self.editor_settings.add_property_info({
			"name": command_key,
			"type": TYPE_STRING,
			"hint": "Path to aseprite executable",
		})

func get_aseprite_cmd() -> String:
	if self.editor_settings.has_setting(command_key):
		return self.editor_settings.get(command_key)
	else:
		return command_default_value
