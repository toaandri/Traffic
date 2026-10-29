extends SceneTree
## Test d'intégration : nécessite le service Python sur le port 8765.


func _initialize() -> void:
	call_deferred("_exercise")


func _exercise() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 10000
	while not app.connected and Time.get_ticks_msec() < deadline:
		await process_frame
	if not app.connected:
		push_error("Pont Python inaccessible.")
		quit(1)
		return
	app._command("play")
	while (app.agents.is_empty() or app.people.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	if app.agents.is_empty() or app.people.is_empty() or app.roads_root.get_child_count() == 0 or app.light_views.is_empty():
		push_error("Réseau, véhicules, piétons ou feux SUMO non reçus par Godot.")
		quit(1)
		return
	app._command("pause")
	print("TRAFFIC_SMOKE_OK : réseau, véhicules, piétons et feux SUMO reçus par la scène.")
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)
