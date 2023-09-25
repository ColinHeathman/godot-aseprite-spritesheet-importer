@tool
class_name AsepriteImportPlugin
extends EditorImportPlugin

var executable: AsepriteExecutable
var editor: EditorInterface

enum Presets { DEFAULT }


const EXPORT_HIDDEN_LAYERS = {
	"name": "export_hidden_layers",
	"default_value": false,
	"description": "Make all layers visible",
}

const FLATTEN_LAYER_GROUPS = {
	"name": "flatten_layer_groups",
	"default_value": false,
	"description": "Flatten Layer Groups",
}

const SPLIT_LAYERS = {
	"name": "split_layers",
	"default_value": false,
	"description": "Split Layers",
}

const GENERATE_ATLAS_TEXTURES = {
	"name": "generate_atlas_textures",
	"default_value": false,
	"description": "Generate Atlas Texture resources",
}

const GENERATE_SPRITEFRAMES = {
	"name": "generate_spriteframes",
	"default_value": false,
	"description": "Generate SpriteFrames resources",
}

const READ_FRAMERATE = {
	"name": "read_framerate",
	"default_value": true,
	"description": "Calculate framerate for Spriteframes from frame delay",
}

const SHEET_TYPE = {
	"name": "sheet_type",
	"default_value": AsepriteExecutable.SheetType.DEFAULT,
	"description": "Sheet type to export",
	"property_hint": PROPERTY_HINT_ENUM,
	"hint_string": "default,horizontal,vertical,rows,columns,packed",
	
}

const KEEP_JSON = {
	"name": "keep_json",
	"default_value": false,
	"description": "Keep data json file for inspection",
}

func _get_priority() -> float:
	return 5.0

func _get_import_order() -> int:
	return 0

func _get_importer_name() -> String:
	return "aseprite.spritesheet.importer"

func _get_visible_name() -> String:
	return "Spritesheet"

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "Texture2D"

func _get_recognized_extensions() -> PackedStringArray:
	return ["ase", "aseprite"]

func _get_preset_count() -> int:
	return Presets.size()

func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(_path: String, preset_index: int) -> Array[Dictionary]:
	match preset_index:
		Presets.DEFAULT:
			return [EXPORT_HIDDEN_LAYERS, FLATTEN_LAYER_GROUPS, SPLIT_LAYERS, GENERATE_ATLAS_TEXTURES, GENERATE_SPRITEFRAMES, READ_FRAMERATE, SHEET_TYPE, KEEP_JSON]
		_:
			return []

func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary):
	return true

func _import(source_file: String, save_path: String, options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var err = self.executable.validate()
	if err != OK:
		return err
	var importer = AsepriteImporter.new()
	importer.use_editor(self.editor)
	importer.use_source_file(source_file, save_path, _get_save_extension())
	importer.use_import_options(options)
	importer.use_executable(self.executable)
	importer.use_import_plugin(self)
	return importer.run()
