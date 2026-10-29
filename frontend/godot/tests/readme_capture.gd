extends SceneTree
## Captures réelles de l'application ; les PNG intermédiaires restent dans .tools.

var app
var frame_counts := {}
var output: String


func _initialize() -> void:
	call_deferred("_record")


func _frames(sequence: String, count: int) -> void:
	var directory := output.path_join(sequence)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Impossible de créer le dossier de captures : " + directory)
		quit(1)
		return
	var offset: int = frame_counts.get(sequence, 0)
	for index in range(count):
		await create_timer(0.125).timeout
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		if frame.save_png(directory.path_join("%04d.png" % (offset + index))) != OK:
			quit(1)
			return
	frame_counts[sequence] = offset + count


func _record() -> void:
	root.size = Vector2i(1280, 800)
	output = ProjectSettings.globalize_path("res://../../.tools/readme-frames")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 15000
	while app.scenario.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if app.scenario.is_empty():
		push_error("Le moteur local n'a pas fourni de scénario.")
		quit(1)
		return
	var scenario: Dictionary = app.scenario.duplicate(true)
	scenario.name = "Démonstration Traffic"
	scenario.vehicles = 90
	scenario.pedestrians = 30
	scenario.duration = 60
	scenario.step_length = 0.5
	scenario.controller = "adaptive"
	app._send({"command": "configure", "scenario": scenario})
	deadline = Time.get_ticks_msec() + 15000
	while app.scenario.name != scenario.name and Time.get_ticks_msec() < deadline: await process_frame
	if app.scenario.name != scenario.name:
		quit(1)
		return
	app._send({"command": "speed", "value": 2})
	app._command("play")
	await create_timer(3).timeout
	await _frames("simulation", 24)
	if not app.agents.is_empty(): app._picked("vehicle", app.agents.keys()[0])
	await _frames("simulation", 56)
	app._command("pause")
	app.ui.tabs.current_tab = 0
	await create_timer(0.3).timeout
	var node: Dictionary = app.editor.network.nodes[0]
	app._action("inspect_object", {"kind": "intersection", "id": node.id})
	await _frames("network", 12)
	app._action("tool", {"tool": "move"})
	app.editor.selected = node.id
	app._edit_click(Vector3(float(node.x) - 25, 0, -float(node.y)))
	await _frames("network", 16)
	app._action("undo", {})
	await _frames("network", 12)
	app._action("redo", {})
	await _frames("network", 12)
	app._action("undo", {})
	app._action("camera", {"mode": 1})
	await _frames("network", 16)
	var manifest := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"fps": 8, "frames": frame_counts}, "\t"))
	print("TRAFFIC_README_CAPTURE_OK : ", JSON.stringify(frame_counts))
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
