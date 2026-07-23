@tool
extends RefCounted

const AsepriteExecutable = preload("res://addons/aseprite_spritesheet_importer/executable.gd")
const AsepriteUtilAtlasTools = preload("res://addons/aseprite_spritesheet_importer/util/atlas_tools.gd")
const AsepriteUtilSpriteFrameTools = preload("res://addons/aseprite_spritesheet_importer/util/spriteframe_tools.gd")

# (PROOF OF CONCEPT) # the default directories set by user project settings, if empty does textures/ fallback
const SETTING_SPRITEFRAME_DIR = "aseprite_importer/defaults/spriteframe_directory"
const SETTING_ATLAS_DIR = "aseprite_importer/defaults/atlas_directory"

var editor: EditorInterface
var source_file: String
var save_path: String
var save_extension: String
var source_file_folder: String
var source_file_basename: String
var source_file_no_ext: String
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

@warning_ignore("shadowed_variable")
func use_import_options(import_options: Dictionary) -> void:
	self.import_options = import_options
	var opts: AsepriteExecutable.Options = AsepriteExecutable.Options.new()
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
	var steps: Array[Callable] = [
		self._validate,
		self._make_fallback_texture,
		self._export_spritesheet,
		self._generate_atlas_textures,
		self._generate_spriteframes,
		self._prune_files,
	]
	for step in steps:
		var err: Error = step.call()
		if err != OK:
			return err
	return OK

func _validate() -> Error:
	var fail: bool = false
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
	var img: Image = Image.create(1,1,false, Image.FORMAT_RGBA8)
	img.set_pixel(0,0, Color.FUCHSIA)
	self.spritesheet_texture = PortableCompressedTexture2D.new()
	self.spritesheet_texture.create_from_image(
		img,
		PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS,
	)
	
	# Save to texture_path
	var err: Error = ResourceSaver.save(self.spritesheet_texture, self.texture_path)
	if err != OK:
		return err
	self.spritesheet_texture.take_over_path(self.texture_path)
	return OK

func _export_spritesheet() -> Error:
	# Execute Aseprite
	var aseprite_result: Array = self.executable.export_spritesheet(self.source_file, self.aseprite_options)
	if aseprite_result[0] != OK:
		return aseprite_result[0]
	self.spritesheet_data = aseprite_result[1]


	# Delete JSON if necessary
	if not self.import_options["debug/keep_json"]:
		DirAccess.remove_absolute(self.aseprite_options.datafile_path)

	# Load PNG file
	var img: Image = Image.load_from_file(self.aseprite_options.spritesheet_path)
	self.spritesheet_texture = PortableCompressedTexture2D.new()

	# Compress image
	self.spritesheet_texture.create_from_image(
		img,
		self.import_options["compress/mode"],
		self.import_options["compress/lossy_quality"],
		self.import_options["compress/normal_map"]
	)

	# Save to texture_path
	var err: Error = ResourceSaver.save(self.spritesheet_texture, self.texture_path)
	if err != OK:
		return err
	self.spritesheet_texture.take_over_path(self.texture_path)

	# Delete PNG file
	if not self.import_options["debug/keep_png"]:
		DirAccess.remove_absolute(self.aseprite_options.spritesheet_path)

	# Refresh Editor
	EditorInterface.get_resource_filesystem().update_file(self.texture_path)
	return OK

func _generate_atlas_textures() -> Error:
	if not self.import_options["generate_resources/atlas_textures"]:
		return OK

	# (PROOF OF CONCEPT)
	# when generation is requested from the import dock it makes sure the folder exists
	var atlas_folder: String = _resolve_atlas_folder() 
	_ensure_directory_exists(atlas_folder)

	var atlas_tools: AsepriteUtilAtlasTools = AsepriteUtilAtlasTools.new()
	atlas_tools.use_spritesheet(self.source_file_no_ext, self.spritesheet_data, atlas_folder) # (PROOF OF CONCEPT)
	atlas_tools.use_texture(self.spritesheet_texture)
	atlas_tools.use_editor(self.editor)
	atlas_tools.split_layers = self.import_options["layers/split_layers"]
	var err: Error = atlas_tools.run()
	self.gen_files.append_array(atlas_tools.gen_files)
	return err

func _generate_spriteframes() -> Error:
	if not self.import_options["generate_resources/spriteframes"]:
		return OK

	# (PROOF OF CONCEPT)
	# when generation is requested from the import dock it makes sure the folder exists
	var spriteframe_folder: String = _resolve_spriteframe_folder() # (PROOF OF CONCEPT)
	_ensure_directory_exists(spriteframe_folder) # (PROOF OF CONCEPT)

	var spriteframe_tools: AsepriteUtilSpriteFrameTools = AsepriteUtilSpriteFrameTools.new()
	spriteframe_tools.use_spritesheet(self.source_file_no_ext, self.spritesheet_data, spriteframe_folder) # (PROOF OF CONCEPT)
	spriteframe_tools.use_texture(self.spritesheet_texture)
	spriteframe_tools.use_editor(self.editor)
	spriteframe_tools.split_layers = self.import_options["layers/split_layers"]
	spriteframe_tools.ignore_framerate = self.import_options["generate_resources/ignore_framerate"]
	spriteframe_tools.localize_textures = ! self.import_options["generate_resources/atlas_textures"]
	var err: Error = spriteframe_tools.run()
	self.gen_files.append_array(spriteframe_tools.gen_files)
	return err

func _prune_files() -> Error:
	
	var prev_files: Dictionary = {}
	var import_path: String = "%s.import" % self.source_file
	var import_file: FileAccess = FileAccess.open(import_path, FileAccess.READ)
	if import_file == null:
		return FileAccess.get_open_error()

	while import_file.get_position() < import_file.get_length():
		# Find line that starts with files=
		var line: String = import_file.get_line()
		if line.begins_with("files="):
			# Read previous files into a set
			for f: Variant in JSON.parse_string(line.trim_prefix("files=")):
				prev_files[f] = true
	import_file.close()
	
	for r in self.gen_files:
		# Remove the file from the set of previous files
		prev_files.erase(r.resource_path)
	
	# Prune any previously generated files that weren't generated this time
	for f: String in prev_files:
		if FileAccess.file_exists(f):
			var err: Error = DirAccess.remove_absolute(f)
			if err != OK:
				return err
			EditorInterface.get_resource_filesystem().update_file(f)
	
	# (PROOF OF CONCEPT) extra feature
	# Delete the folder if its empty
	_prune_empty_folder(_resolve_atlas_folder())
	_prune_empty_folder(_resolve_spriteframe_folder())
	
	return OK

# (PROOF OF CONCEPT)
# verifies which dir to use based on order of operation
# 1. checks for custom user directory inputted through the import dock
# 2. checks default project settings
# 3. falls back to textures/ within the same folder if neither of the above exists
func _resolve_spriteframe_folder() -> String:
	# 1. custom dir
	var custom_dir: String = self.import_options.get("output/spriteframe_directory", "").strip_edges()
	if not custom_dir.is_empty():
		return custom_dir.simplify_path()

	# 2. project default
	if ProjectSettings.has_setting(SETTING_SPRITEFRAME_DIR):
		var global_dir: String = str(ProjectSettings.get_setting(SETTING_SPRITEFRAME_DIR)).strip_edges()
		if not global_dir.is_empty():
			return global_dir.simplify_path()

	# 3. fallback
	return self.source_file_folder.path_join("textures").simplify_path()

# (PROOF OF CONCEPT)
# verifies which dir to use based on order of operation
# 1. checks for custom user directory inputted through the import dock
# 2. checks default project settings
# 3. falls back to textures/ within the same folder if neither of the above exists
func _resolve_atlas_folder() -> String:
	# 1. custom dir
	var custom_dir: String = self.import_options.get("output/atlas_directory", "").strip_edges()
	if not custom_dir.is_empty():
		return custom_dir.simplify_path()

	# 2. project default
	if ProjectSettings.has_setting(SETTING_ATLAS_DIR):
		var global_dir: String = str(ProjectSettings.get_setting(SETTING_ATLAS_DIR)).strip_edges()
		if not global_dir.is_empty():
			return global_dir.simplify_path()

	# 3. fallback
	return self.source_file_folder.path_join("textures").simplify_path()

# (PROOF OF CONCEPT)
# function makes sure that the directory exists and if it doesn't it creates it.
# pushes an Error if the folder can't be created for whatever reason
func _ensure_directory_exists(path: String) -> Error:
	if not DirAccess.dir_exists_absolute(path):
		var err: Error = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("Failed to create folder at '%s': Error %d" % [path, err])
			return err
		self.do_scan = true
	return OK

# (PROOF OF CONCEPT)
# function that removes target directory only if it exists and contains zero files or subfolders.
# 1. SAFTEY
# 2. read files and directories
# 3. if no sub directories or files then delete
# pushes a Warning if folder can't be deleted for whatever reason
func _prune_empty_folder(path: String) -> void:
	var clean_path: String = path.simplify_path()
	
	# 1. SO THE FUNCTION DOESN'T DELETE IMPORTANT STUFF 
	if clean_path.is_empty() or clean_path in ["res:", "res://", ".", "/"]:
		return
	if not DirAccess.dir_exists_absolute(clean_path):
		return

	# 2. reads
	var files: PackedStringArray = DirAccess.get_files_at(clean_path)
	var dirs: PackedStringArray = DirAccess.get_directories_at(clean_path)

	# 3. final check and removal
	if files.is_empty() and dirs.is_empty():
		var err: Error = DirAccess.remove_absolute(clean_path)
		if err == OK:
			self.do_scan = true
		else:
			push_warning("Failed to prune empty folder at '%s': Error %d" % [clean_path, err])
