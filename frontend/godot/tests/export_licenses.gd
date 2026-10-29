extends SceneTree


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://../../docs/licenses")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("godot.txt"), FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	var dependencies := FileAccess.open(folder.path_join("godot-dependencies.json"), FileAccess.WRITE)
	dependencies.store_string(JSON.stringify(Engine.get_license_info(), "\t"))
	var icon := Image.new()
	icon.load_svg_from_string(FileAccess.get_file_as_string("res://assets/traffic.svg"))
	icon.save_png(ProjectSettings.globalize_path("res://../../.tools/traffic-icon.png"))
	quit(0)
