@tool
class_name AsepritePluginConfig
extends RefCounted

const command_key = "aseprite/general/command_path"
const windows_command_default_value = "C:\\Program Files\\Aseprite\\Aseprite.exe"
const mac_os_command_default_value = "/Applications/Aseprite.app/Contents/MacOS/aseprite"
const command_default_value = "aseprite"

var editor_settings: EditorSettings

func setup_editor_settings() -> void:
	if not self.editor_settings.has_setting(command_key):
		self.editor_settings.set_setting(command_key, get_default_command())
		self.editor_settings.add_property_info({
			"name": command_key,
			"type": TYPE_STRING,
			"hint": "Path to aseprite executable",
		})

func get_aseprite_cmd() -> String:
	if self.editor_settings.has_setting(command_key):
		return self.editor_settings.get(command_key)
	else:
		return get_default_command()

func get_default_command() -> String:
	if OS.has_feature("windows"):
		return windows_command_default_value
	if OS.has_feature("macos"):
		return mac_os_command_default_value
	return command_default_value
