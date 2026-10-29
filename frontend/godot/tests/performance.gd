extends SceneTree


func _initialize() -> void:
	call_deferred("_measure")


func _measure() -> void:
	root.size = Vector2i(1440, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 10000
	while app.scenario.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if app.scenario.is_empty():
		quit(1)
		return
	var candidate: Dictionary = app.scenario.duplicate(true)
	candidate.name = "Quartier de démonstration"
	candidate.vehicles = 120
	candidate.pedestrians = 40
	candidate.duration = 60
	candidate.step_length = 0.5
	app._send({"command": "configure", "scenario": candidate})
	while app.scenario.vehicles != 120 and Time.get_ticks_msec() < deadline: await process_frame
	app._send({"command": "speed", "value": 2})
	app._command("play")
	await create_timer(6).timeout
	var elapsed := 0.0
	var frames := 0
	var maximum_vehicles := 0
	var maximum_pedestrians := 0
	while elapsed < 10:
		await process_frame
		elapsed += app.get_process_delta_time()
		frames += 1
		maximum_vehicles = maxi(maximum_vehicles, app.agents.size())
		maximum_pedestrians = maxi(maximum_pedestrians, app.people.size())
	await RenderingServer.frame_post_draw
	if not app.agents.is_empty(): app._picked("vehicle", app.agents.keys()[0])
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../../docs/screenshots")
	root.get_texture().get_image().save_png(directory.path_join("studio-loaded.png"))
	var report := {"frames": frames, "seconds": elapsed, "mean_fps": frames / elapsed,
		"maximum_vehicles": maximum_vehicles, "maximum_pedestrians": maximum_pedestrians,
		"renderer": RenderingServer.get_video_adapter_name(), "window": [1440,900], "fps_cap": Engine.max_fps}
	var file := FileAccess.open(directory.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("TRAFFIC_PERFORMANCE_OK : ", JSON.stringify(report))
	app._command("pause")
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
