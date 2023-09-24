@tool
class_name AsepriteUtilSpriteFrameTools
extends AsepriteUtilAtlasTools

var read_framerate: bool

var _frame_durations: Array
var _named_spriteframes_atlas_names: Dictionary
var _named_spriteframes: Dictionary

func run() -> Error:
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
	_make_load_spriteframes()
	_read_frame_durations()
	_add_animations()

	return _save_spriteframes()

func _read_frame_durations() -> void:
	self._frame_durations = []
	if not split_layers:
		for key in self.spritesheet_data.frames:
			self._frame_durations.append(self.spritesheet_data.frames[key].duration)
	else:
		var prev_layer_name = ""
		var layer = 0
		for key in self.spritesheet_data.frames:
			# key looks like "filename (layer) 0.ase" for split-layers
			# key looks like "filename (layer).ase" for split-layers  if there's only 1 frame
			var layer_name = key.rsplit(")", true, 1)[0].rsplit("(", true, 1)[1]
			if layer_name != prev_layer_name:
				layer += 1
				if layer > 1:
					break
			self._frame_durations.append(self.spritesheet_data.frames[key].duration)
			prev_layer_name = layer_name

func _flatten_slice_regions_split() -> void:
	self._named_atlas_regions = {}
	self._named_spriteframes_atlas_names = {}
	for i in range(self._frame_regions.size()):
		for layer_name in self._frame_regions[i]:
			for slice_name in self._slices:
				var spriteframes_name = "%s_%s_%s" % [self.spritesheet_name, slice_name, layer_name]
				var atlas_texture_name = "%s_%s_%s_%d" % [self.spritesheet_name, slice_name, layer_name, i]
				if spriteframes_name not in self._named_spriteframes_atlas_names:
					self._named_spriteframes_atlas_names[spriteframes_name] = []
				self._named_spriteframes_atlas_names[spriteframes_name].append(atlas_texture_name)
				self._named_atlas_regions[atlas_texture_name] = self._slice_regions[i][layer_name][slice_name]
				if slice_name in self._slice_styleboxes:
					self._named_stylebox_regions[atlas_texture_name] = self._slice_styleboxes[slice_name]

func _flatten_slice_regions() -> void:
	self._named_atlas_regions = {}
	self._named_spriteframes_atlas_names = {}
	for i in range(self._frame_regions.size()):
		for slice_name in self._slices:
			var spriteframes_name = "%s_%s" % [self.spritesheet_name, slice_name]
			var atlas_texture_name = "%s_%s_%d" % [self.spritesheet_name, slice_name, i]
			if spriteframes_name not in self._named_spriteframes_atlas_names:
				self._named_spriteframes_atlas_names[spriteframes_name] = []
			self._named_spriteframes_atlas_names[spriteframes_name].append(atlas_texture_name)
			self._named_atlas_regions[atlas_texture_name] = self._slice_regions[i]["default"][slice_name]

func _flatten_frame_regions_split() -> void:
	self._named_atlas_regions = {}
	self._named_spriteframes_atlas_names = {}
	for i in range(self._frame_regions.size()):
		for layer_name in self._frame_regions[i]:
			var spriteframes_name = "%s_%s" % [self.spritesheet_name, layer_name]
			var atlas_texture_name = "%s_%s_%d" % [self.spritesheet_name, layer_name, i]
			if spriteframes_name not in self._named_spriteframes_atlas_names:
				self._named_spriteframes_atlas_names[spriteframes_name] = []
			self._named_spriteframes_atlas_names[spriteframes_name].append(atlas_texture_name)
			self._named_atlas_regions[atlas_texture_name] = self._frame_regions[i][layer_name]

func _flatten_frame_regions() -> void:
	self._named_atlas_regions = {}
	self._named_spriteframes_atlas_names = {}
	for i in range(self._frame_regions.size()):
		var spriteframes_name = self.spritesheet_name
		var atlas_texture_name = "%s_%d" % [self.spritesheet_name, i]
		if spriteframes_name not in self._named_spriteframes_atlas_names:
			self._named_spriteframes_atlas_names[spriteframes_name] = []
		self._named_spriteframes_atlas_names[spriteframes_name].append(atlas_texture_name)
		self._named_atlas_regions[atlas_texture_name] = self._frame_regions[i]["default"]

func _make_load_spriteframes() -> void:
	self._named_spriteframes = {}
	for spriteframes_name in self._named_spriteframes_atlas_names:
		var sprite_frames_path: String = "%s/%s_spriteframes.tres" % [self.textures_folder, spriteframes_name]
		var sprite_frames: SpriteFrames
		if FileAccess.file_exists(sprite_frames_path):
			sprite_frames = load(sprite_frames_path)
		else:
			sprite_frames = SpriteFrames.new()
		self._named_spriteframes[spriteframes_name] = sprite_frames

func _save_spriteframes() -> Error:
	for spriteframes_name in self._named_spriteframes:
		var sprite_frames_path: String = "%s/%s_spriteframes.tres" % [self.textures_folder, spriteframes_name]
		var err = ResourceSaver.save(self._named_spriteframes[spriteframes_name], sprite_frames_path)
		if err != OK:
			print("SpriteFrames save error: %s" % error_string(err))
			return err

		self.editor.get_resource_filesystem().update_file(sprite_frames_path)
		self._named_spriteframes[spriteframes_name].take_over_path(sprite_frames_path)

	return OK

func _add_animations() -> void:

	# Add in "default" animation if there is none
	if self.spritesheet_data.meta.frameTags.size() == 0:
		self.spritesheet_data.meta.frameTags.append({
			"name": "default",
			"from": 0,
			"to": self._frame_durations.size() - 1,
			"direction": "forward",
			"color": "#000000ff",
		})

	for tag in self.spritesheet_data.meta.frameTags:
		var anim_name: String = tag.name
		if anim_name.ends_with("-noimp"):
			continue

		for spriteframes_name in self._named_spriteframes:
			var spriteframes: SpriteFrames = self._named_spriteframes[spriteframes_name]

			if spriteframes.has_animation(anim_name):
				spriteframes.clear(anim_name)
			else:
				spriteframes.add_animation(anim_name)

			# Animation looping is based off "loop" or "cycle" hint
			spriteframes.set_animation_loop(anim_name, anim_name.ends_with("loop") or anim_name.ends_with("cycle"))

			# Animation direction
			var frame_range = range(tag.from, tag.to+1) # forwards
			if tag.direction == "reverse":
				frame_range = range(tag.to, tag.from-1, -1) # backwards
			if tag.direction == "pingpong":
				frame_range = range(tag.from, tag.to) + range(tag.to, tag.from, -1) # ping-pong

			if self.read_framerate:
				# FPS is based on the first animation frame
				var ms_per_frame = float(self._frame_durations[tag.from])
				var fps = 1.0 / (ms_per_frame / 1000.0)
				spriteframes.set_animation_speed(anim_name, roundf(fps))

				for i in frame_range:
					var frame_duration = self._frame_durations[i] / ms_per_frame
					var atlas_names = _named_spriteframes_atlas_names[spriteframes_name]
					spriteframes.add_frame(anim_name, _named_atlas_textures[atlas_names[i]], frame_duration)

			else:
				for i in frame_range:
					var atlas_names = _named_spriteframes_atlas_names[spriteframes_name]
					spriteframes.add_frame(anim_name, _named_atlas_textures[atlas_names[i]])

	for spriteframes_name in self._named_spriteframes:
		var spriteframes: SpriteFrames = self._named_spriteframes[spriteframes_name]
		# Remove default animation if necessary
		var has_default = false
		for tag in self.spritesheet_data.meta.frameTags:
			if tag.name == "default":
				has_default = true
				break
		if !has_default:
			spriteframes.remove_animation("default")
