extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 12000
	while app.scenario.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if app.scenario.is_empty():
		push_error("Scénario non reçu.")
		quit(1)
		return
	app._action("example", {"name": "grid"})
	await create_timer(0.8).timeout
	app._command("play")
	await create_timer(7).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../../docs/screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Capture GPU vide.")
		quit(1)
		return
	image.save_png(folder.path_join("studio-simulation.png"))
	app.ui.tabs.current_tab = 0
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("studio-network.png"))
	app.ui.tabs.current_tab = 2
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("studio-experiments.png"))
	root.size = Vector2i(1100, 740)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("studio-compact.png"))
	root.size = Vector2i(1440, 900)
	app.ui.open_settings(1)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("studio-settings.png"))
	print("TRAFFIC_UI_CAPTURE_OK : ", folder)
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
