@tool
class_name AsepriteUtilAtlasTools
extends RefCounted

var spritesheet_name: String
var spritesheet_data: Dictionary
var textures_folder: String
var texture: Texture2D
var split_layers: bool
var editor: EditorInterface

var _frame_regions: Array[Dictionary]
var _slice_regions: Array[Dictionary]
var _slices: Dictionary
var _slice_styleboxes: Dictionary
var _named_atlas_regions: Dictionary
var _named_stylebox_regions: Dictionary
var _named_atlas_textures: Dictionary
var _named_atlas_styleboxes: Dictionary

@warning_ignore("shadowed_variable")
func use_spritesheet(spritesheet_name: String, spritesheet_data: Dictionary, textures_folder: String) -> void:
	self.spritesheet_name = spritesheet_name
	self.spritesheet_data = spritesheet_data
	self.textures_folder = textures_folder

@warning_ignore("shadowed_variable")
func use_texture(texture: Texture2D) -> void:
	self.texture = texture

@warning_ignore("shadowed_variable")
func use_editor(editor: EditorInterface) -> void:
	self.editor = editor

func run() -> Error:
	var err: Error
	_read_frames()
	if self.spritesheet_data.meta.slices.size() > 0:
		_read_slices()
		_read_slice_regions()
		if self.split_layers:
			_flatten_slice_regions_split()
		else:
			_flatten_slice_regions()
	else:
		if self.split_layers:
			_flatten_frame_regions_split()
		else:
			_flatten_frame_regions()

	_make_load_atlas_textures()
	err = _save_atlas_textures()
	if err != OK:
		return err

	_make_load_styleboxes()
	err = _save_atlas_styleboxes()
	if err != OK:
		return err

	return OK

func _read_frames() -> void:
	self._frame_regions = []
	var frame_number = 0
	if not split_layers:
		for key in self.spritesheet_data.frames:
			# key looks like "filename 0.ase" normally
			# key looks like "filename.ase" if there's only 1 frame
			if self._frame_regions.size() == frame_number:
				self._frame_regions.append({})
			self._frame_regions[frame_number]["default"] = Rect2i(
				self.spritesheet_data.frames[key].frame.x,
				self.spritesheet_data.frames[key].frame.y,
				self.spritesheet_data.frames[key].frame.w,
				self.spritesheet_data.frames[key].frame.h,
			)
			frame_number += 1
	else:
		var prev_layer_name = ""
		for key in self.spritesheet_data.frames:
			# key looks like "filename (layer) 0.ase" for split-layers
			# key looks like "filename (layer).ase" for split-layers  if there's only 1 frame
			var layer_name = key.rsplit(")", true, 1)[0].rsplit("(", true, 1)[1]
			if layer_name != prev_layer_name:
				frame_number = 0
			if self._frame_regions.size() == frame_number:
				self._frame_regions.append({})
			self._frame_regions[frame_number][layer_name] = Rect2i(
				self.spritesheet_data.frames[key].frame.x,
				self.spritesheet_data.frames[key].frame.y,
				self.spritesheet_data.frames[key].frame.w,
				self.spritesheet_data.frames[key].frame.h,
			)
			prev_layer_name = layer_name
			frame_number += 1

func _read_slices() -> void:
	self._slices = {}
	self._slice_styleboxes = {}
	for slice in self.spritesheet_data.meta.slices:
		if slice.name.ends_with("-noimp"):
			# Do not import
			continue

		self._slices[slice.name] = {}
		for key in slice.keys:
			self._slices[slice.name][key.frame] = Rect2i(
				key.bounds.x,
				key.bounds.y,
				key.bounds.w,
				key.bounds.h,
			)

		# Make Stylebox?
		if "center" not in slice.keys[0]:
			continue

		self._slice_styleboxes[slice.name] = Rect2i(
			slice.keys[0].center.x,
			slice.keys[0].center.y,
			slice.keys[0].bounds.w - slice.keys[0].center.x - slice.keys[0].center.w,
			slice.keys[0].bounds.h - slice.keys[0].center.y - slice.keys[0].center.h,
		)

func _get_slice_bounds(slice_name, frame_number) -> Rect2i:
	var all_slice_bounds = self._slices[slice_name]
	var result: Rect2i
	for slice_frame_number in all_slice_bounds:
		if slice_frame_number > frame_number:
			break
		result = all_slice_bounds[slice_frame_number]
	return result

func _read_slice_regions() -> void:
	self._slice_regions = []
	self._slice_regions.resize(self._frame_regions.size())

	for i in range(self._frame_regions.size()):
		self._slice_regions[i] = {}
		for layer_name in self._frame_regions[i]:
			self._slice_regions[i][layer_name] = {}
			for slice_name in self._slices:
				var slice_bounds: Rect2i = self._get_slice_bounds(slice_name, i)
				var frame_bounds: Rect2i = self._frame_regions[i][layer_name]
				self._slice_regions[i][layer_name][slice_name] = Rect2i(
					frame_bounds.position.x + slice_bounds.position.x,
					frame_bounds.position.y + slice_bounds.position.y,
					slice_bounds.size.x,
					slice_bounds.size.y,
				)

func _flatten_slice_regions_split() -> void:
	self._named_atlas_regions = {}
	if self._frame_regions.size() > 1:
		# For N frames
		for i in range(self._frame_regions.size()):
			for layer_name in self._frame_regions[i]:
				for slice_name in self._slices:
					var atlas_texture_name = "%s_%s_%s_%d" % [self.spritesheet_name, slice_name, layer_name, i]
					self._named_atlas_regions[atlas_texture_name] = self._slice_regions[i][layer_name][slice_name]
					if slice_name in self._slice_styleboxes:
						self._named_stylebox_regions[atlas_texture_name] = self._slice_styleboxes[slice_name]
	else:
		# For 1 frame
		for layer_name in self._frame_regions[0]:
			for slice_name in self._slices:
				var atlas_texture_name = "%s_%s_%s" % [self.spritesheet_name, slice_name, layer_name]
				self._named_atlas_regions[atlas_texture_name] = self._slice_regions[0][layer_name][slice_name]
				if slice_name in self._slice_styleboxes:
					self._named_stylebox_regions[atlas_texture_name] = self._slice_styleboxes[slice_name]

func _flatten_slice_regions() -> void:
	self._named_atlas_regions = {}
	if self._frame_regions.size() > 1:
		# For N frames
		for i in range(self._frame_regions.size()):
			for slice_name in self._slices:
				var atlas_texture_name = "%s_%s_%d" % [self.spritesheet_name, slice_name, i]
				self._named_atlas_regions[atlas_texture_name] = self._slice_regions[i]["default"][slice_name]
				if slice_name in self._slice_styleboxes:
					self._named_stylebox_regions[atlas_texture_name] = self._slice_styleboxes[slice_name]
	else:
		# For 1 frame
		for slice_name in self._slices:
			var atlas_texture_name = "%s_%s" % [self.spritesheet_name, slice_name]
			self._named_atlas_regions[atlas_texture_name] = self._slice_regions[0]["default"][slice_name]
			if slice_name in self._slice_styleboxes:
				self._named_stylebox_regions[atlas_texture_name] = self._slice_styleboxes[slice_name]

func _flatten_frame_regions_split() -> void:
	self._named_atlas_regions = {}
	if self._frame_regions.size() > 1:
		# For N frames
		for i in range(self._frame_regions.size()):
			for layer_name in self._frame_regions[i]:
				var atlas_texture_name = "%s_%s_%d" % [self.spritesheet_name, layer_name, i]
				self._named_atlas_regions[atlas_texture_name] = self._frame_regions[i][layer_name]
	else:
		# For 1 frame
		for layer_name in self._frame_regions[0]:
			var atlas_texture_name = "%s_%s" % [self.spritesheet_name, layer_name]
			self._named_atlas_regions[atlas_texture_name] = self._frame_regions[0][layer_name]

func _flatten_frame_regions() -> void:
	self._named_atlas_regions = {}
	if self._frame_regions.size() > 1:
		# For N frames
		for i in range(self._frame_regions.size()):
			var atlas_texture_name = "%s_%d" % [self.spritesheet_name, i]
			self._named_atlas_regions[atlas_texture_name] = self._frame_regions[i]["default"]
	else:
		# For 1 frame
		var atlas_texture_name = self.spritesheet_name
		self._named_atlas_regions[atlas_texture_name] = self._frame_regions[0]["default"]

func _make_load_atlas_textures() -> void:
	self._named_atlas_textures = {}
	for atlas_texture_name in self._named_atlas_regions:
		var atlas_texture_path: String = "%s/%s.tres" % [self.textures_folder, atlas_texture_name]
		var atex: AtlasTexture
		if FileAccess.file_exists(atlas_texture_path):
			atex = load(atlas_texture_path)
		else:
			atex = AtlasTexture.new()

		atex.atlas = self.texture
		atex.region = self._named_atlas_regions[atlas_texture_name]
		self._named_atlas_textures[atlas_texture_name] = atex

func _save_atlas_textures() -> Error:
	for atlas_texture_name in self._named_atlas_textures:
		var atlas_texture_path: String = "%s/%s.tres" % [self.textures_folder, atlas_texture_name]
		var err = ResourceSaver.save(self._named_atlas_textures[atlas_texture_name], atlas_texture_path)
		if err != OK:
			print("AtlasTexture save error: %s" % error_string(err))
			return err

		self.editor.get_resource_filesystem().update_file(atlas_texture_path)
		self._named_atlas_textures[atlas_texture_name].take_over_path(atlas_texture_path)

	return OK

func _make_load_styleboxes() -> void:
	self._named_atlas_styleboxes = {}
	for atlas_texture_name in self._named_atlas_textures:

		# Does stylebox exist?
		if atlas_texture_name not in self._named_stylebox_regions:
			continue
		var stylebox_path: String = "%s/%s_stylebox.tres" % [self.textures_folder, atlas_texture_name]
		var stylebox: StyleBoxTexture
		if FileAccess.file_exists(stylebox_path):
			stylebox = load(stylebox_path)
		else:
			stylebox = StyleBoxTexture.new()

		stylebox.texture = self._named_atlas_textures[atlas_texture_name]
		stylebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		stylebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE

		var stylebox_region = self._named_stylebox_regions[atlas_texture_name]

		stylebox.texture_margin_left = stylebox_region.position.x
		stylebox.texture_margin_top = stylebox_region.position.y
		stylebox.texture_margin_bottom = stylebox_region.size.x
		stylebox.texture_margin_right = stylebox_region.size.y

		self._named_atlas_styleboxes[atlas_texture_name] = stylebox

func _save_atlas_styleboxes() -> Error:
	for atlas_texture_name in self._named_atlas_styleboxes:
		var stylebox_path: String = "%s/%s_stylebox.tres" % [self.textures_folder, atlas_texture_name]
		var err = ResourceSaver.save(self._named_atlas_styleboxes[atlas_texture_name], stylebox_path)
		if err != OK:
			print("StyleBoxTexture save error: %s" % error_string(err))
			return err

		self.editor.get_resource_filesystem().update_file(stylebox_path)
		self._named_atlas_styleboxes[atlas_texture_name].take_over_path(stylebox_path)

	return OK
