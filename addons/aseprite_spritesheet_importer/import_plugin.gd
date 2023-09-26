@tool
class_name AsepriteImportPlugin
extends EditorImportPlugin

var executable: AsepriteExecutable
var editor: EditorInterface

enum Presets { DEFAULT }

const EXPORT_HIDDEN_LAYERS = {
	"name": "layers/export_hidden_layers",
	"default_value": false,
	"description": "Make all layers visible",
}

const FLATTEN_LAYER_GROUPS = {
	"name": "layers/flatten_layer_groups",
	"default_value": false,
	"description": "Flatten Layer Groups",
}

const SPLIT_LAYERS = {
	"name": "layers/split_layers",
	"default_value": false,
	"description": "Split Layers",
}

const GENERATE_ATLAS_TEXTURES = {
	"name": "generate_resources/atlas_textures",
	"default_value": false,
	"description": "Generate Atlas Texture resources",
}

const GENERATE_SPRITEFRAMES = {
	"name": "generate_resources/spriteframes",
	"default_value": false,
	"description": "Generate SpriteFrames resources",
}

const READ_FRAMERATE = {
	"name": "generate_resources/read_framerate",
	"default_value": true,
	"description": "Calculate framerate for Spriteframes from frame delay",
}

const KEEP_JSON = {
	"name": "generate_resources/keep_json",
	"default_value": false,
	"description": "Keep data json file for inspection",
}

const SHEET_TYPE = {
	"name": "export_options/sheet_type",
	"default_value": AsepriteExecutable.SheetType.DEFAULT,
	"description": "Sheet type to export",
	"property_hint": PROPERTY_HINT_ENUM,
	"hint_string": "default,horizontal,vertical,rows,columns,packed",
}

const SHEET_WIDTH = {
	"name": "export_options/sheet_width",
	"default_value": 0,
	"description": "Sprite sheet width",
}

const SHEET_HEIGHT = {
	"name": "export_options/sheet_height",
	"default_value": 0,
	"description": "Sprite sheet height",
}

const SHEET_COLUMNS = {
	"name": "export_options/sheet_columns",
	"default_value": 0,
	"description": "Fixed # of columns for sheet_type rows",
}

const SHEET_ROWS = {
	"name": "export_options/sheet_rows",
	"default_value": 0,
	"description": "Fixed # of rows for sheet_type columns",
}

const BORDER_PADDING = {
	"name": "export_options/border_padding",
	"default_value": 0,
	"description": "Add padding on the texture borders",
}

const SHAPE_PADDING = {
	"name": "export_options/shape_padding",
	"default_value": 0,
	"description": "Add padding between frames",
}

const INNER_PADDING = {
	"name": "export_options/inner_padding",
	"default_value": 0,
	"description": "Add padding inside each frame",
}

const TRIM = {
	"name": "export_options/trim",
	"default_value": false,
	"description": "Trim images",
}

const EXTRUDE = {
	"name": "export_options/extrude",
	"default_value": false,
	"description": "Extrude all images duplicating all edges one pixel",
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
			return [
				EXPORT_HIDDEN_LAYERS,
				FLATTEN_LAYER_GROUPS,
				SPLIT_LAYERS,
				GENERATE_ATLAS_TEXTURES,
				GENERATE_SPRITEFRAMES,
				READ_FRAMERATE,
				KEEP_JSON,
				SHEET_TYPE,
				SHEET_WIDTH,
				SHEET_HEIGHT,
				SHEET_COLUMNS,
				SHEET_ROWS,
				BORDER_PADDING,
				SHAPE_PADDING,
				INNER_PADDING,
				TRIM,
				EXTRUDE,
			]
		_:
			return []

func _get_option_visibility(_path: String, option_name: StringName, options: Dictionary):
	# only show "sheet_width" and "sheet_height" if sheet_type = "horizontal", "vertical" or "packed"
	if option_name == "export_options/sheet_width" or option_name == "export_options/sheet_height":
		return (
			options["export_options/sheet_type"] == AsepriteExecutable.SheetType.HORIZONTAL
			or options["export_options/sheet_type"] == AsepriteExecutable.SheetType.VERTICAL
			or options["export_options/sheet_type"] == AsepriteExecutable.SheetType.PACKED
		)
	# only show sheet_columns if sheet_type = "rows"
	if option_name == "export_options/sheet_columns":
		return options["export_options/sheet_type"] == AsepriteExecutable.SheetType.ROWS
	# only show sheet_rows if sheet_type = "columns"
	if option_name == "export_options/sheet_rows":
		return options["export_options/sheet_type"] == AsepriteExecutable.SheetType.COLUMNS

	# only show trim if slices aren't being used
	# this is because of a limitation in how slices are implemented in Aseprite
	if option_name == "export_options/trim":
		return not (options["generate_resources/atlas_textures"] or options["generate_resources/spriteframes"])

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
