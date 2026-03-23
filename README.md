
# <img align="center" src="./icon.png" /> Godot Aseprite Spritesheet Importer

A simple yet powerful Godot plugin designed to streamline importing spritesheets and animations from Aseprite. Treat your ASE files like source code!

<img align="center" src="./screenshots/aseprite.gif" />

<img align="center" src="./screenshots/atlas_textures.gif" />

<img align="center" src="./screenshots/spriteframes.gif" />

<img align="center" src="./screenshots/stylebox.gif" />

Thanks to Kenney.nl for the original sprites used in these examples

## Key Features

- **Update on save**: Saving the changes to an Aseprite file will automatically update textures in Godot.

- **Support for multiple Layers, Frames, and Slices**: Supports complex Aseprite files with multiple characters or images organized using Layer Groups and/or Slices. This is very useful if you want to make a character with _both the body and equipment in the same file_.

- **Support for nine-patch StyleBox**: Useful for creating GUI elements.

- **Resource focus**: This plugin focuses on creating Resources (ie. SpriteFrames, AtlasTexture, Stylebox) rather than Nodes or Scenes (eg. AnimatedSprite2D, AnimatedSprite3D, or AnimationTree).

## Import Options

### Layers

- **Export Hidden Layers** - Makes all layers visible before export.

- **Flatten Layer Groups** - Flattens top-level Layer Groups before export (useful when combined with Split Layers).

- **Split Layers** - Splits layers into their own area of the spritesheet.

### Generate Resources

- **Atlas Textures** - Generate AtlasTexture (Texture2D) Resources for each subregion of the spritesheet - this respects both Slices, Layers (when used with Split Layers) and 9-patch Slices (for StyleBox)

- **SpriteFrames** - Generate SpriteFrames Resource(s) that has an animation for each Tag (or "default" if there is no tag).

- **Ignore Framerate** - By default the plugin uses the frame delay configured in Aseprite to set the FPS and individual frame delay of each animation within an exported SpriteFrames.

### Export options

# Export options
- **Sheet Type** - Spritesheet type to export (default, horizontal, vertical, rows, columns, or packed)

- **Sheet Width** - Sprite sheet width

- **Sheet Height** - Sprite sheet height

- **Sheet Columns** - Fixed # of columns for sheet_type rows

- **Sheet Rows** - Fixed # of rows for sheet_type columns

- **Border Padding** - Add padding on the texture borders

- **Shape Padding** - Add padding between frames

- **Inner Padding** - Add padding inside each frame

- **Trim** - Trim images, removing transparent pixels

- **Extrude** - Extrude all images duplicating all edges one pixel

### Compress options
- **Mode** - The compression mode to use,

For 2D usage (compressed on disk, uncompressed on VRAM), the lossy and lossless modes are recommended. For 3D usage (compressed on VRAM) it depends on the target platform.
If you intend to only use desktop, S3TC or BPTC are recommended. For only mobile, ETC2 is recommended.

- **Lossy Quality** - The quality to use when using the ***Lossy* compression mode. This maps to Lossy WebP compression quality.

- **Normal Map** - Ensure optimum quality if this image will be used as a normal map.

# Debug
- **Keep JSON** - Keep the JSON datafile instead of cleaning it up after export. Useful for debugging purposes.

- **Keep PNG** - Keep exported png file for inspection

## Import hints

The import hints used for the addon were chosen to match the import hints for [the official Godot Blender plugin](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_scenes.html#import-hints)

### Slices

Any Aseprite Slice with the suffix `-noimp` will be ignored when creating AtlasTexture Resources (although the images will still be exported as part of the spritesheet png).

### Animations

Any Aseprite Tags with the suffix `-noimp` will be ignored when creating SpriteFrames Resources (although the images will still be exported as part of the spritesheet png).

Tags with the suffix `loop` or `cycle` will be set as looping within the SpriteFrames animation.

## How to Use

1. **Installation**:
   - Download the plugin from the [release page](https://github.com/colinheathman/godot-aseprite-spritesheet-importer/releases).
   - Extract the plugin folder into your Godot project's `addons` directory.

2. **Configuration**:
   - Open your Godot project.
   - Navigate to `Project > Project Settings > Plugins`.
   - Enable the "Aseprite Spritesheet Importer" plugin.

3. **Custom install location for Aseprite**:
   - If you've installed Aseprite to a custom location (or you're using the Steam version)
   - Navigate to `Editor > Editor Settings > Aseprite > General`.
   - Configure the `Command Path` to the path of the aseprite executable.
	   - MacOS Default: "/Applications/Aseprite.app/Contents/MacOS/aseprite"
	   - Windows Default: "%ProgramFiles%\\Aseprite\\Aseprite.exe"
	   - Otherwise: "aseprite"

4. **Usage**:
   - Once activated, `.ase` and `.aseprite` files will show up in the FileSystem dock.
   - Select the Aseprite file you want to import.
   - Configure any additional settings based in the import dock `Import > Spritesheet`.
   - Click 'Import' to generate the resources in a `textures` folder next to the Aseprite file.

## Compatibility

This addon was tested using Godot 4.4.1-stable, and should work with any higher version

The addon should also be compatible with [Aseprite Wizard](https://github.com/viniciusgerevini/godot-aseprite-wizard) if you want to use both in your project.

## Support and Contribution

If you encounter any issues or have suggestions for improvement, please [open an issue](https://github.com/colinheathman/godot-aseprite-spritesheet-importer/issues) on the GitHub repository.

## License

This plugin is licensed under [MIT License](https://github.com/colinheathman/godot-aseprite-spritesheet-importer/blob/main/LICENSE).

## Disclaimer

This plugin is not affiliated with Aseprite, or its developers.
