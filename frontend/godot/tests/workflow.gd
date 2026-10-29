extends SceneTree


func _initialize() -> void:
	call_deferred("_exercise")


func _exercise() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 20000
	while app.scenario.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	assert(not app.scenario.is_empty())
	assert(not app.ui.settings.visible)
	assert(app.ui.network_tree.get_root().get_child_count() == 2)
	var node_item = app.ui.network_tree.get_root().get_first_child().get_first_child()
	node_item.select(0)
	await process_frame
	assert(app.selected_id == node_item.get_text(0))
	assert("Intersection" in app.ui.inspector.text)
	app.ui.open_settings(1)
	assert(app.ui.settings.visible)
	app.ui.settings.hide()
	app.ui.project_name.text = "Recette de l’IHM"
	app.ui.vehicles.value = 12
	app.ui.pedestrians.value = 4
	app.ui.duration.value = 15
	app.ui.step.value = 0.5
	app.ui.algorithm.select(1)
	app._action("apply", {})
	while app.scenario.vehicles != 12 and Time.get_ticks_msec() < deadline: await process_frame
	assert(app.scenario.vehicles == 12 and app.scenario.controller == "adaptive")
	assert(not app.ui.settings.visible)
	app._action("save_project", {})
	while app.project_id == null and Time.get_ticks_msec() < deadline: await process_frame
	assert(app.project_id != null)
	app.ui.tabs.current_tab = 0
	assert(app.world.editing)
	app.editor.tool = "select"
	await process_frame
	var node: Dictionary = app.editor.network.nodes[0]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = app.world.camera.unproject_position(Vector3(node.x, 0, -node.y))
	app.ui.viewport.push_input(press, true)
	await process_frame
	assert(app.editor.selected == node.id)
	app.editor.tool = "move"
	app.editor.selected = app.editor.network.nodes[0].id
	var original: Dictionary = app.editor.network.duplicate(true)
	app._edit_click(Vector3(-25,0,0))
	assert(app.editor.network != original)
	app._action("undo", {})
	assert(app.editor.network == original)
	app._action("redo", {})
	assert(app.editor.network != original)
	app._action("undo", {})
	app._action("apply", {})
	deadline = Time.get_ticks_msec() + 15000
	while app.dirty and Time.get_ticks_msec() < deadline: await process_frame
	assert(not app.dirty)
	app.ui.tabs.current_tab = 1
	app._command("play")
	deadline = Time.get_ticks_msec() + 6000
	while (app.agents.is_empty() or app.people.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	assert(not app.agents.is_empty() and not app.people.is_empty())
	app._picked("vehicle", app.agents.keys()[0])
	assert("Vitesse" in app.ui.inspector.text)
	app._command("pause")
	app._action("export", {})
	await create_timer(0.5).timeout
	assert(not app.last_results.is_empty())
	app.ui.seed_count.value = 1
	app._action("compare", {})
	deadline = Time.get_ticks_msec() + 45000
	while app.ui.busy.visible and Time.get_ticks_msec() < deadline: await process_frame
	if app.ui.busy.visible:
		print("Comparaison en attente : ", app.ui.message.text, " / scénario : ", app.scenario.duration)
		quit(1)
		return
	if not "Fixe / adaptatif" in app.ui.results.text:
		print("Comparaison échouée : ", app.ui.message.text)
		quit(1)
		return
	print("TRAFFIC_WORKFLOW_OK : configurer, appliquer, enregistrer, éditer, annuler/rétablir, inspecter, exporter, comparer.")
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
