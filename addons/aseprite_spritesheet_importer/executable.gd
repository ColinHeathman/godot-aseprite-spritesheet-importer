@tool
class_name AsepriteExecutable
extends RefCounted

var config: AsepritePluginConfig

class Options:
	var all_layers: bool
	var flatten_layer_groups: bool
	var split_layers: bool
	var spritesheet_path: String
	var datafile_path: String
	var flattened_path: String

func export_spritesheet(source_file: String, aseprite_options: Options) -> Array:
	# Export from Aseprite
	var absolute_source_file: String = ProjectSettings.globalize_path(source_file)
	var absolute_spritesheet_path: String = ProjectSettings.globalize_path(aseprite_options.spritesheet_path)
	var absolute_datafile_path: String = ProjectSettings.globalize_path(aseprite_options.datafile_path)
	var absolute_flattened_path: String = ProjectSettings.globalize_path(aseprite_options.flattened_path)
	
	# Export .ase file with flattened layer groups
	if aseprite_options.flatten_layer_groups:
		var err = export_flattened_groups(absolute_source_file, absolute_flattened_path, aseprite_options)
		if err != OK:
			DirAccess.remove_absolute(aseprite_options.flattened_path)
			return [err, null]
	
	# Aseprite arguments
	var args = ["--batch", "--list-layers", "--list-tags", "--list-slices"] 

	if aseprite_options.all_layers:
		args += ["--all-layers"]

	if aseprite_options.split_layers:
		args += ["--split-layers"]

	args += ["--sheet", absolute_spritesheet_path]
	args += ["--data", absolute_datafile_path]
	
	if aseprite_options.flatten_layer_groups:
		args += [absolute_flattened_path]
	else:
		args += [absolute_source_file]
	
	# Execute Aseprite and capture stdout, stderr
	var output: Array = []
	var exit_code = OS.execute(self.config.get_aseprite_cmd(), args, output, true)
	if aseprite_options.flatten_layer_groups:
		DirAccess.remove_absolute(aseprite_options.flattened_path)
	if exit_code != OK:
		print("Failed to export spritesheet\n", output[0])
		return [ERR_SCRIPT_FAILED, null]
	
	# Load spritesheet data
	var data = JSON.parse_string(FileAccess.get_file_as_string(aseprite_options.datafile_path))
	return [OK, data]

func export_flattened_groups(absolute_source_file: String, absolute_flattened_path: String, aseprite_options: Options) -> Error:
	# Aseprite arguments
	var args = ["--batch"]
	if aseprite_options.all_layers:
		args += ["--script-param", "delete_invisible=false"]
	else:
		args += ["--script-param", "delete_invisible=true"]
	args += [absolute_source_file]
	var script_dir = self.get_script().get_path().rsplit("/", true, 1)[0]
	args += ["--script", ProjectSettings.globalize_path("%s/flatten_layer_groups.lua" % script_dir)]
	args += ["--save-as", absolute_flattened_path]

	# Execute Aseprite and capture stdout, stderr
	var output: Array = []
	var exit_code = OS.execute(self.config.get_aseprite_cmd(), args, output, true)
	if exit_code != OK:
		print("Failed to flatten layer groups\n", output[0])
		return ERR_SCRIPT_FAILED
	return OK
