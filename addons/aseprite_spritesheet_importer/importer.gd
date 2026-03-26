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
var spritesheet_texture: PortableCompressedTexture2D
var spritesheet_data: Dictionary
var gen_files: Array[Resource]
var do_scan: bool

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
	opts.all_layers = import_options["layers/export_hidden_layers"]
	opts.split_layers = import_options["layers/split_layers"]
	opts.flatten_layer_groups = import_options["layers/flatten_layer_groups"]
	opts.spritesheet_path = "%s/%s_tmp_spritesheet.png" % [self.source_file_folder, self.source_file_no_ext]
	opts.datafile_path = "%s/%s_tmp_data.json" % [self.source_file_folder, self.source_file_no_ext]
	opts.flattened_path = "%s/%s_tmp_flattened.ase" % [self.source_file_folder, self.source_file_no_ext]
	opts.sheet_type = import_options["export_options/sheet_type"]
	opts.sheet_width = import_options["export_options/sheet_width"]
	opts.sheet_height = import_options["export_options/sheet_height"]
	opts.sheet_columns = import_options["export_options/sheet_columns"]
	opts.sheet_rows = import_options["export_options/sheet_rows"]
	opts.border_padding = import_options["export_options/border_padding"]
	opts.shape_padding = import_options["export_options/shape_padding"]
	opts.inner_padding = import_options["export_options/inner_padding"]
	# only trim if slices aren't being used
	# this is because of a limitation in how slices are implemented in Aseprite
	opts.trim = import_options["export_options/trim"] and not (import_options["generate_resources/atlas_textures"] or import_options["generate_resources/spriteframes"])
	opts.extrude = import_options["export_options/extrude"]
	self.aseprite_options = opts

@warning_ignore("shadowed_variable")
func use_executable(executable: AsepriteExecutable) -> void:
	self.executable = executable

@warning_ignore("shadowed_variable")
func use_import_plugin(import_plugin: EditorImportPlugin) -> void:
	self.import_plugin = import_plugin

func run() -> Error:
	self.gen_files = []
	var steps = [
		self._validate,
		self._make_fallback_texture,
		self._export_spritesheet,
		self._generate_atlas_textures,
		self._generate_spriteframes,
		self._prune_files,
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
	# Get empty Texture as fallback
	self.texture_path = "%s.%s" % [self.save_path, self.save_extension]

	# Setup ImageTexture
	var img = Image.create(1,1,false, Image.FORMAT_RGBA8)
	img.set_pixel(0,0, Color.FUCHSIA)
	self.spritesheet_texture = PortableCompressedTexture2D.new()
	self.spritesheet_texture.create_from_image(img, 0)
	
	# Save to texture_path
	var err = ResourceSaver.save(self.spritesheet_texture, self.texture_path)
	if err != OK:
		return err
	self.spritesheet_texture.take_over_path(self.texture_path)
	return OK

func _export_spritesheet() -> Error:
	var editor_file_system = self.editor.get_resource_filesystem()
	
	# Make textures folder if required
	if (self.import_options["generate_resources/atlas_textures"] \
	or self.import_options["generate_resources/spriteframes"]) \
	and ! DirAccess.dir_exists_absolute(self.textures_folder):
		DirAccess.make_dir_recursive_absolute(self.textures_folder)
		# Notify import_plugin to run a scan
		self.do_scan = true

	# Execute Aseprite
	var aseprite_result = self.executable.export_spritesheet(self.source_file, self.aseprite_options)
	if aseprite_result[0] != OK:
		return aseprite_result[0]
	self.spritesheet_data = aseprite_result[1]


	# Delete JSON if necessary
	if not self.import_options["debug/keep_json"]:
		DirAccess.remove_absolute(self.aseprite_options.datafile_path)

	# Load PNG file
	var img = Image.load_from_file(self.aseprite_options.spritesheet_path)
	self.spritesheet_texture = PortableCompressedTexture2D.new()

	# Compress image
	self.spritesheet_texture.create_from_image(
		img,
		self.import_options["compress/mode"],
		self.import_options["compress/lossy_quality"],
		self.import_options["compress/normal_map"]
	)

	# Save to texture_path
	var err = ResourceSaver.save(self.spritesheet_texture, self.texture_path)
	if err != OK:
		return err
	self.spritesheet_texture.take_over_path(self.texture_path)

	# Delete PNG file
	if not self.import_options["debug/keep_png"]:
		DirAccess.remove_absolute(self.aseprite_options.spritesheet_path)

	# Refresh Editor
	editor_file_system.update_file(self.texture_path)
	return OK

func _generate_atlas_textures() -> Error:
	if not self.import_options["generate_resources/atlas_textures"]:
		return OK

	var atlas_tools = AsepriteUtilAtlasTools.new()
	atlas_tools.use_spritesheet(self.source_file_no_ext, self.spritesheet_data, self.textures_folder)
	atlas_tools.use_texture(self.spritesheet_texture)
	atlas_tools.use_editor(self.editor)
	atlas_tools.split_layers = self.import_options["layers/split_layers"]
	var err = atlas_tools.run()
	self.gen_files.append_array(atlas_tools.gen_files)
	return err

func _generate_spriteframes() -> Error:
	if not self.import_options["generate_resources/spriteframes"]:
		return OK

	var spriteframe_tools = AsepriteUtilSpriteFrameTools.new()
	spriteframe_tools.use_spritesheet(self.source_file_no_ext, self.spritesheet_data, self.textures_folder)
	spriteframe_tools.use_texture(self.spritesheet_texture)
	spriteframe_tools.use_editor(self.editor)
	spriteframe_tools.split_layers = self.import_options["layers/split_layers"]
	spriteframe_tools.ignore_framerate = self.import_options["generate_resources/ignore_framerate"]
	spriteframe_tools.localize_textures = ! self.import_options["generate_resources/atlas_textures"]
	var err = spriteframe_tools.run()
	self.gen_files.append_array(spriteframe_tools.gen_files)
	return err

func _prune_files() -> Error:
	
	var prev_files: Dictionary = {}
	var import_path = "%s.import" % self.source_file
	var import_file = FileAccess.open(import_path, FileAccess.READ)
	if import_file == null:
		return FileAccess.get_open_error()

	while import_file.get_position() < import_file.get_length():
		# Find line that starts with files=
		var line: String = import_file.get_line()
		if line.begins_with("files="):
			# Read previous files into a set
			for f in JSON.parse_string(line.trim_prefix("files=")):
				prev_files[f] = true
	import_file.close()
	
	for r in self.gen_files:
		# Remove the file from the set of previous files
		prev_files.erase(r.resource_path)
	
	# Prune any previously generated files that weren't generated this time
	var editor_file_system = editor.get_resource_filesystem()
	for f in prev_files:
		if FileAccess.file_exists(f):
			var err = DirAccess.remove_absolute(f)
			if err != OK:
				return err
			editor_file_system.update_file(f)
	
	# Delete the folder if it's empty
	if DirAccess.dir_exists_absolute(self.textures_folder) \
	and DirAccess.get_files_at(self.textures_folder).size() == 0:
		var err = DirAccess.remove_absolute(self.textures_folder)
		if err != OK:
			return err
		# Notify import_plugin to run a scan
		self.do_scan = true

	return OK
