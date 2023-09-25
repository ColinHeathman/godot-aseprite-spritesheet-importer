@tool
class_name AsepriteImporter
extends RefCounted

var editor: EditorInterface
var source_file: String
var save_path: String
var save_extension: String
var source_file_folder: String
var source_file_basename: String
var source_file_no_ext: String
var textures_folder: String
var texture_path: String
var import_options: Dictionary
var aseprite_options: AsepriteExecutable.Options
var executable: AsepriteExecutable
var import_plugin: EditorImportPlugin
var atex: AtlasTexture
var spritesheet_texture: Texture2D
var spritesheet_data: Dictionary

@warning_ignore("shadowed_variable")
func use_editor(editor: EditorInterface) -> void:
	self.editor = editor

@warning_ignore("shadowed_variable")
func use_source_file(source_file: String, save_path: String, save_extension: String) -> void:
	self.source_file = source_file
	self.save_path = save_path
	self.save_extension = save_extension
	self.source_file_folder = source_file.rsplit("/", true, 1)[0]
	self.source_file_basename = source_file.rsplit("/", true, 1)[1]
	self.source_file_no_ext = source_file_basename.rsplit(".", true, 1)[0]
	self.textures_folder = "%s/textures" % source_file_folder

@warning_ignore("shadowed_variable")
func use_import_options(import_options: Dictionary) -> void:
	self.import_options = import_options
	var opts = AsepriteExecutable.Options.new()
	opts.all_layers = import_options.export_hidden_layers
	opts.split_layers = import_options.split_layers
	opts.flatten_layer_groups = import_options.flatten_layer_groups
	opts.spritesheet_path = "%s/%s_spritesheet.png" % [textures_folder, source_file_no_ext]
	opts.datafile_path = "%s/%s_data.json" % [textures_folder, source_file_no_ext]
	opts.flattened_path = "%s/%s_flattened.ase" % [textures_folder, source_file_no_ext]
	opts.sheet_type = import_options.sheet_type
	self.aseprite_options = opts

@warning_ignore("shadowed_variable")
func use_executable(executable: AsepriteExecutable) -> void:
	self.executable = executable

@warning_ignore("shadowed_variable")
func use_import_plugin(import_plugin: EditorImportPlugin) -> void:
	self.import_plugin = import_plugin

func run() -> Error:
	var steps = [
		_validate,
		_make_fallback_texture,
		_export_spritesheet,
		_load_spritesheet,
		_generate_atlas_textures,
		_generate_spriteframes,
		_save_final_atlas_texture,
		_reimport_spritesheet,
	]
	for step in steps:
		var err = step.call()
		if err != OK:
			return err
	return OK

func _validate() -> Error:
	var fail = false
	if self.editor == null:
		fail = true
		print("call use_editor() before run()")
	if self.source_file == "":
		fail = true
		print("call use_source_file() before run()")
	if self.import_options == null:
		fail = true
		print("call use_import_options() before run()")
	if self.executable == null:
		fail = true
		print("call use_executable() before run()")
	if self.import_plugin == null:
		fail = true
		print("call use_import_plugin() before run()")
	if fail:
		return FAILED
	return OK

func _make_fallback_texture() -> Error:
	# Get empty AtlasTexture as fallback
	self.texture_path = "%s.%s" % [self.save_path, self.save_extension]

	# Setup AtlasTexture
	self.atex = AtlasTexture.new()
	self.atex.atlas = PlaceholderTexture2D.new()
	self.atex.region.position.x = 0
	self.atex.region.position.y = 0
	self.atex.region.size.x = 1
	self.atex.region.size.y = 1

	# Save to texture_path
	var err = ResourceSaver.save(atex, texture_path)
	if err != OK:
		return err
	self.atex.take_over_path(texture_path)
	return OK

func _export_spritesheet() -> Error:
	# Make textures folder if required
	DirAccess.make_dir_recursive_absolute(self.textures_folder)

	# Execute Aseprite
	var aseprite_result = self.executable.export_spritesheet(source_file, aseprite_options)
	if aseprite_result[0] != OK:
		return aseprite_result[0]
	self.spritesheet_data = aseprite_result[1]

	var editor_file_system = self.editor.get_resource_filesystem()

	# Delete JSON if necessary
	if not self.import_options.keep_json:
		DirAccess.remove_absolute(self.aseprite_options.datafile_path)
		editor_file_system.update_file(self.aseprite_options.datafile_path)

	# Refresh view of exported file
	editor_file_system.update_file(textures_folder)
	editor_file_system.update_file(aseprite_options.spritesheet_path)
	editor_file_system.update_file(aseprite_options.datafile_path)
	self.import_plugin.append_import_external_resource(aseprite_options.spritesheet_path)

	return OK

func _load_spritesheet() -> Error:
	# Load spritesheet as texture
	self.spritesheet_texture = ResourceLoader.load(
		aseprite_options.spritesheet_path,
		"Texture2D",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if self.spritesheet_texture == null:
		return ERR_SCRIPT_FAILED
	return OK

func _generate_atlas_textures() -> Error:
	if not self.import_options.generate_atlas_textures:
		return OK

	var atlas_tools = AsepriteUtilAtlasTools.new()
	atlas_tools.use_spritesheet(self.source_file_no_ext, self.spritesheet_data, self.textures_folder)
	atlas_tools.use_texture(self.spritesheet_texture)
	atlas_tools.use_editor(self.editor)
	atlas_tools.split_layers = self.import_options.split_layers
	return atlas_tools.run()

func _generate_spriteframes() -> Error:
	if not self.import_options.generate_spriteframes:
		return OK

	var spriteframe_tools = AsepriteUtilSpriteFrameTools.new()
	spriteframe_tools.use_spritesheet(self.source_file_no_ext, self.spritesheet_data, self.textures_folder)
	spriteframe_tools.use_texture(self.spritesheet_texture)
	spriteframe_tools.use_editor(self.editor)
	spriteframe_tools.split_layers = self.import_options.split_layers
	spriteframe_tools.read_framerate = self.import_options.read_framerate
	return spriteframe_tools.run()

func _save_final_atlas_texture() -> Error:
	self.atex.atlas = self.spritesheet_texture
	self.atex.region.position.x = 0
	self.atex.region.position.y = 0
	self.atex.region.size.x = self.spritesheet_texture.get_width()
	self.atex.region.size.y = self.spritesheet_texture.get_height()
	var err = ResourceSaver.save(atex, texture_path)
	if err != OK:
		return err
	return OK

func _reimport_spritesheet() -> Error:
	self.editor.get_base_control().get_tree().process_frame.connect(
		self._reimport_deferred.bind([self.aseprite_options.spritesheet_path])
	)
	return OK

func _reimport_deferred(files: PackedStringArray):
	self.editor.get_base_control().get_tree().process_frame.disconnect(self._reimport_deferred)
	self.editor.get_resource_filesystem().reimport_files(files)
