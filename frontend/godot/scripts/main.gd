extends Node3D

const Editor = preload("res://scripts/network_editor.gd")
const World = preload("res://scripts/world_view.gd")
const Studio = preload("res://scripts/studio_ui.gd")
var editor := Editor.new()
var world := World.new()
var ui := Studio.new()
var socket := WebSocketPeer.new()
var connected := false
var paused := true
var editing := false
var dirty := false
var populating := false
var pending_play := false
var scenario: Dictionary = {}
var last_snapshot: Dictionary = {}
var selected_kind := ""
var selected_id := ""
var project_id = null
var last_results := ""
var retry_at := 0
var reconnect_interval := 2000
var import_dialog := FileDialog.new()
var export_dialog := FileDialog.new()
var close_dialog := ConfirmationDialog.new()
var saved_candidate: Dictionary = {}
var autosave_at := 0

var agents: Dictionary:
	get: return world.agents
var people: Dictionary:
	get: return world.people
var roads_root: Node3D:
	get: return world.roads_root
var light_views: Dictionary:
	get: return world.light_views


func _ready() -> void:
	Engine.max_fps = 60
	world.editor = editor
	ui.world = world
	ui.action.connect(_action)
	world.picked.connect(_picked)
	world.edit_clicked.connect(_edit_click)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(ui)
	for field in [ui.vehicles, ui.pedestrians, ui.seed, ui.duration, ui.step, ui.vehicle_rate, ui.pedestrian_rate]:
		field.value_changed.connect(func(_value): _dirty())
	ui.project_name.text_changed.connect(func(_value): _dirty())
	ui.description.text_changed.connect(_dirty)
	ui.algorithm.item_selected.connect(func(_value): _dirty())
	ui.demand.item_selected.connect(func(_value): _dirty())
	ui.origin.item_selected.connect(func(_value): _dirty())
	ui.destination.item_selected.connect(func(_value): _dirty())
	ui.automatic_crossings.toggled.connect(func(_value): _dirty())
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.json ; Scénario Traffic"])
	import_dialog.file_selected.connect(_import_file)
	add_child(import_dialog)
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.json ; Scénario Traffic"])
	export_dialog.file_selected.connect(_export_file)
	add_child(export_dialog)
	close_dialog.dialog_text = "Des modifications ne sont pas enregistrées. Quitter et les abandonner ?"
	close_dialog.confirmed.connect(func(): get_tree().quit())
	add_child(close_dialog)
	get_tree().auto_accept_quit = false
	_connect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if dirty: close_dialog.popup_centered(Vector2i(450, 160))
		else: get_tree().quit()


func _exit_tree() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.close(1000, "Application fermée")


func _connect() -> void:
	var port := OS.get_environment("TRAFFIC_PORT")
	if port.is_empty(): port = "8765"
	socket = WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:" + port)
	retry_at = Time.get_ticks_msec() + reconnect_interval


func _process(_delta: float) -> void:
	if dirty and autosave_at > 0 and Time.get_ticks_msec() >= autosave_at:
		autosave_at = 0
		var draft := FileAccess.open("user://draft.json", FileAccess.WRITE)
		if draft != null: draft.store_string(JSON.stringify(_candidate(), "\t"))
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			ui.status.text = "Prêt · local"
			_send({"command": "catalog"})
		while socket.get_available_packet_count() > 0:
			var data = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary: _receive(data)
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		connected = false
		ui.status.text = "Reconnexion…"
		if Time.get_ticks_msec() >= retry_at: _connect()
	ui.play.disabled = not connected or scenario.is_empty() or ui.busy.visible
	ui.apply.disabled = not connected or ui.busy.visible
	ui.compare.disabled = not connected or ui.busy.visible


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F1: _help()
	if event.ctrl_pressed and event.keycode == KEY_S: _action("save_project", {})
	if event.ctrl_pressed and event.keycode == KEY_O: _action("open_dialog", {})
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
	if event.keycode == KEY_SPACE: _action("toggle_play", {})
	if event.ctrl_pressed and event.keycode == KEY_Z: _action("undo", {})
	if event.ctrl_pressed and event.keycode == KEY_Y: _action("redo", {})
	if event.keycode == KEY_LEFT: world.camera_angle -= 0.12
	if event.keycode == KEY_RIGHT: world.camera_angle += 0.12
	if event.keycode == KEY_UP: world.camera_distance *= 0.9
	if event.keycode == KEY_DOWN: world.camera_distance *= 1.1


func _send(command: Dictionary) -> void:
	if not connected:
		ui.toast("Le moteur démarre. La connexion est rétablie automatiquement.")
		return
	command = command.duplicate(true)
	command.protocol_version = 1
	socket.send_text(JSON.stringify(command))


func _command(command: String) -> void:
	_send({"command": command})


func _dirty() -> void:
	if not populating and not scenario.is_empty():
		dirty = true
		autosave_at = Time.get_ticks_msec() + 1000
		ui.toast("Modifications locales : appliquer avant de simuler ou enregistrer le projet.")
		ui.document_title.text = ui.project_name.text + " *"


func _candidate() -> Dictionary:
	var candidate := scenario.duplicate(true)
	if candidate.is_empty(): return candidate
	candidate.name = ui.project_name.text.strip_edges()
	candidate.description = ui.description.text
	candidate.vehicles = int(ui.vehicles.value)
	candidate.pedestrians = int(ui.pedestrians.value)
	candidate.vehicle_rate = ui.vehicle_rate.value if ui.vehicle_rate.value > 0 else null
	candidate.pedestrian_rate = ui.pedestrian_rate.value if ui.pedestrian_rate.value > 0 else null
	candidate.seed = int(ui.seed.value)
	candidate.duration = ui.duration.value
	candidate.step_length = ui.step.value
	candidate.controller = "adaptive" if ui.algorithm.selected == 1 else "fixed"
	candidate.demand_profile = "peak" if ui.demand.selected == 1 else "steady"
	candidate.network = editor.network.duplicate(true)
	candidate.network.auto_crossings = ui.automatic_crossings.button_pressed
	candidate.vehicle_origins = [ui.route_names[ui.origin.selected - 1]] if ui.origin.selected > 0 else []
	candidate.vehicle_destinations = [ui.route_names[ui.destination.selected - 1]] if ui.destination.selected > 0 else []
	candidate.pedestrian_origins = candidate.vehicle_origins
	candidate.pedestrian_destinations = candidate.vehicle_destinations
	return candidate


func _action(name: String, payload: Dictionary) -> void:
	match name:
		"settings": ui.open_settings(int(payload.get("index", ui.tabs.current_tab)))
		"fit_camera": world.fit_network()
		"inspect_object":
			selected_kind = payload.kind
			selected_id = payload.id
			world.selected = selected_id
			if selected_kind == "intersection":
				editor.selected = selected_id
				_refresh_inspector()
				for node in editor.network.nodes:
					if node.id == selected_id:
						ui.inspector.text = "[b]Intersection %s[/b]\nPosition : %.0f / %.0f m\nVert fixe : %.0f s\nVert adaptatif : %.0f–%.0f s" % [node.id, node.x, node.y, node.fixed_green, node.min_green, node.max_green]
			elif selected_kind == "road":
				for road in editor.network.roads:
					if road.id == selected_id:
						ui.inspector.text = "[b]Route %s[/b]\n%s → %s\n%d voie(s) par direction\nVitesse : %.0f km/h" % [road.id, road.source, road.target, road.lanes, float(road.speed) * 3.6]
			if editing: world._draw_network(editor.network)
		"mode":
			editing = payload.index == 0
			world.editing = editing
			if editing: _command("pause")
			if not editor.network.is_empty(): world._draw_network(editor.network)
		"tool":
			ui.tabs.current_tab = 0
			editor.tool = payload.tool
			editor.selected = ""
			var instructions := {"select": "Sélection : cliquer sur un nœud.", "node": "Ajouter un nœud : cliquer au sol ou au milieu d’une route.", "road": "Relier : cliquer sur le départ puis l’arrivée.", "move": "Déplacer : cliquer sur le nœud puis sa destination.", "delete": "Supprimer : cliquer sur un nœud.", "delete_road": "Supprimer : cliquer sur le segment de route."}
			ui.toast(instructions.get(payload.tool, "Cliquer dans le réseau."))
		"undo", "redo":
			if name == "undo": editor.undo()
			else: editor.redo()
			world._draw_network(editor.network)
			ui.refresh_network(editor.network)
			_dirty()
		"apply": _send({"command": "configure", "scenario": _candidate()})
		"validate": _send({"command": "validate", "scenario": _candidate()})
		"toggle_play":
			if not paused: _command("pause")
			elif dirty or editing:
				pending_play = true
				_send({"command": "configure", "scenario": _candidate()})
			else: _command("play")
		"reset": _command("reset")
		"new": _command("new")
		"recover": _recover()
		"generate": _send({"command": "generate", "rows": int(ui.rows.value), "columns": int(ui.columns.value), "spacing": ui.spacing.value, "density": ui.density.value / 100})
		"camera": world.camera_mode = payload.mode
		"heatmap":
			world.heatmap = not world.heatmap
			ui.toast("Congestion activée : les routes chargées sont signalées en ambre." if world.heatmap else "Couleurs normales rétablies.")
		"edit_properties": _edit_properties()
		"crossing": _crossing()
		"event": _add_event()
		"remove_event":
			var items := ui.events.get_selected_items()
			if not items.is_empty():
				scenario.events.remove_at(items[0])
				ui.refresh_events(scenario.events)
				_dirty()
		"save_project":
			saved_candidate = _candidate()
			_send({"command": "save_project", "scenario": saved_candidate, "id": project_id})
		"duplicate":
			project_id = null
			ui.project_name.text += " — copie"
			_action("save_project", {})
		"open_dialog": import_dialog.popup_centered_ratio(0.7)
		"export_json":
			export_dialog.current_file = "scenario-traffic.json"
			export_dialog.popup_centered_ratio(0.7)
		"load_project":
			if payload.index < ui.project_items.size(): _send({"command": "load_project", "id": ui.project_items[payload.index].id})
		"catalog", "export", "cancel_comparison": _command(name)
		"example": _send({"command": "example", "name": payload.name})
		"compare", "stress":
			if dirty:
				ui.toast("Appliquer les modifications avant de comparer les essais.", true)
				return
			var seeds: Array = []
			for index in range(int(ui.seed_count.value)): seeds.append(int(ui.seed.value) + index)
			ui.busy.visible = true
			ui.settings.hide()
			ui.toast("Campagne en cours. Les résultats s’afficheront sous la carte.")
			_send({"command": name, "seeds": seeds})
		"history":
			if payload.index < ui.history_items.size():
				var report: Dictionary = ui.history_items[payload.index]
				last_results = report.directory
				ui.show_report(report)
		"open_results":
			if not last_results.is_empty(): OS.shell_open(last_results)
			else: ui.toast("Aucun export disponible. Exporter les mesures ou lancer une comparaison.")
		"capture": _capture()
		"help": _help()
		"speed": _send({"command": "speed", "value": payload.value})


func _edit_click(position: Vector3) -> void:
	editor.click(position)
	selected_id = editor.selected
	world.selected = selected_id
	selected_kind = "intersection"
	world._draw_network(editor.network)
	ui.refresh_network(editor.network)
	if editor.tool != "select": _dirty()
	_refresh_inspector()


func _edit_properties() -> void:
	if editor.selected.is_empty():
		ui.toast("Sélectionner un nœud avant de modifier ses routes ou son feu.", true)
		return
	editor._remember()
	for node in editor.network.nodes:
		if node.id == editor.selected:
			node.fixed_green = ui.green.value
			node.min_green = ui.minimum_green.value
			node.max_green = ui.maximum_green.value
	for road in editor.network.roads:
		if road.source == editor.selected:
			road.lanes = int(ui.lanes.value)
			road.speed = ui.speed.value / 3.6
	_dirty()
	world._draw_network(editor.network)


func _crossing() -> void:
	if editor.selected.is_empty():
		ui.toast("Sélectionner l’intersection où ajouter la traversée.", true)
		return
	var roads: Array = []
	var neighbor := ""
	for road in editor.network.roads:
		if road.source == editor.selected:
			neighbor = road.target
			break
	for road in editor.network.roads:
		if (road.source == editor.selected and road.target == neighbor) or (road.target == editor.selected and road.source == neighbor): roads.append(road.id)
	if roads.is_empty(): return
	editor._remember()
	if not editor.network.has("crossings"): editor.network.crossings = []
	var identifier := "cross" + str(Time.get_ticks_usec())
	editor.network.crossings.append({"id": identifier, "node": editor.selected, "roads": roads})
	ui.automatic_crossings.button_pressed = false
	_dirty()
	ui.toast("Traversée ajoutée. Appliquer pour générer son signal protégé.")


func _add_event() -> void:
	if scenario.is_empty(): return
	var event := {"time": ui.event_time.value, "vehicles": int(ui.event_amount.value), "pedestrians": int(ui.event_people.value)}
	if ui.event_kind.selected > 0:
		if ui.event_road.selected < 0: return
		event = {"time": ui.event_time.value, "type": "closure" if ui.event_kind.selected == 1 else "accident", "road": ui.route_names[ui.event_road.selected], "duration": ui.event_duration.value}
	scenario.events.append(event)
	ui.refresh_events(scenario.events)
	_dirty()


func _picked(kind: String, identifier: String) -> void:
	selected_kind = kind
	selected_id = identifier
	world.selected = identifier
	_refresh_inspector()


func _refresh_inspector() -> void:
	if selected_id.is_empty(): return
	if selected_kind == "road": return
	if selected_kind == "intersection":
		for node in editor.network.get("nodes", []):
			if node.id == selected_id:
				ui.green.value = node.get("fixed_green", 30)
				ui.minimum_green.value = node.get("min_green", 10)
				ui.maximum_green.value = node.get("max_green", 40)
				ui.inspector.text = "[b]Intersection %s[/b]\nPosition : %.0f / %.0f m\nVert fixe : %.0f s\nVert adaptatif : %.0f–%.0f s" % [node.id, node.x, node.y, node.get("fixed_green", 30), node.get("min_green", 10), node.get("max_green", 40)]
		for light in last_snapshot.get("lights", []):
			if light.id == selected_id:
				ui.inspector.text = "[b]%s[/b]\nPhase %d\nÉtat : %s\nDurée décidée : %.0f s\nFile observée : %d\nDemandes piétonnes : %d" % [light.id, light.phase, light.state, light.decision.get("duration", 0), light.decision.get("queue", 0), light.decision.get("pedestrians_waiting", 0)]
	else:
		var key := "vehicles" if selected_kind == "vehicle" else "pedestrians"
		var found := false
		for agent in last_snapshot.get(key, []):
			if agent.id == selected_id:
				found = true
				ui.inspector.text = "[b]%s[/b]\n%s\nVitesse : %.1f km/h\nAttente courante : %.1f s\nRoute : %s\nPosition : %.1f / %.1f m" % [agent.id, "Véhicule" if selected_kind == "vehicle" else "Piéton", agent.speed * 3.6, agent.waiting, agent.get("road", "—"), agent.x, agent.y]
		if not found: ui.inspector.text = selected_id + " a quitté le réseau."


func _receive(data: Dictionary) -> void:
	match data.get("type"):
		"network":
			ui.settings.hide()
			selected_id = ""
			world.selected = ""
			ui.inspector.text = "Sélectionnez un objet dans la carte ou dans l’explorateur pour consulter ses propriétés."
			scenario = data.scenario.duplicate(true)
			project_id = data.get("project_id")
			editor.set_network(data.network)
			populating = true
			ui.populate(scenario)
			populating = false
			world.load_network(data.network, data.get("geometry", {}))
			ui.chart.clear()
			dirty = false
			paused = true
			ui.toast("Scénario validé. Prêt à simuler.")
			if pending_play:
				pending_play = false
				ui.tabs.current_tab = 1
				_command("play")
		"snapshot":
			last_snapshot = data
			world.update_snapshot(data)
			ui.metric_snapshot(data)
			_refresh_inspector()
			if data.get("finished", false): ui.toast("Essai terminé. Exporter les résultats ou comparer les contrôleurs.")
		"status":
			paused = data.paused
			ui.play.text = "Démarrer" if paused else "Pause"
			ui.status.text = "Terminé" if data.get("finished", false) else ("Prêt · local" if paused else "Simulation en cours")
		"error", "notice":
			ui.toast(str(data.message), data.type == "error")
			if data.type == "error":
				pending_play = false
				ui.busy.visible = false
			if "annul" in str(data.message): ui.busy.visible = false
			if data.has("directory"): last_results = data.directory
		"progress": ui.toast(data.message)
		"comparison":
			ui.busy.visible = false
			last_results = data.directory
			ui.show_report(data)
			if data.get("mode") == "stress": ui.results.text = "[b]Résistance : cas le plus chargé[/b]\n" + ui.results.text
			ui.toast("Campagne terminée. Le rapport et les données sont disponibles.")
			_command("catalog")
		"validation":
			ui.toast("Réseau valide." if data.errors.is_empty() else " · ".join(data.errors), not data.errors.is_empty())
		"saved":
			project_id = data.id
			dirty = _candidate() != saved_candidate
			ui.toast("Projet enregistré dans la bibliothèque locale.")
			_command("catalog")
		"catalog":
			ui.project_items = data.projects
			ui.history_items = data.history
			ui.projects.clear()
			for project in data.projects: ui.projects.add_item(project.name + (" (fichier corrompu)" if project.get("corrupted", false) else ""))
			ui.history.clear()
			for report in data.history: ui.history.add_item(report.name + " / " + str(report.seeds.size()) + " graines")


func _import_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		ui.toast("Impossible de lire ce fichier.", true)
		return
	var value = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		ui.toast("Fichier JSON invalide. Choisir un scénario Traffic.", true)
		return
	_send({"command": "import", "scenario": value})


func _recover() -> void:
	var file := FileAccess.open("user://draft.json", FileAccess.READ)
	if file == null:
		ui.toast("Aucun brouillon disponible.")
		return
	var value = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or not value.has("network"):
		ui.toast("Le brouillon est illisible.", true)
		return
	_command("pause")
	scenario = value
	editor.set_network(value.network)
	populating = true
	ui.populate(value)
	populating = false
	ui.tabs.current_tab = 0
	world.load_network(value.network, {})
	dirty = true
	ui.toast("Brouillon restauré. Corriger le réseau si nécessaire, puis valider et appliquer.")


func _export_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: ui.toast("Impossible d’enregistrer ici.", true)
	else:
		file.store_string(JSON.stringify(_candidate(), "\t"))
		ui.toast("Scénario JSON exporté : " + path)


func _capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	var path := "user://captures/traffic-%d.png" % Time.get_unix_time_from_system()
	var image := ui.viewport.get_texture().get_image()
	if image != null and image.save_png(path) == OK: ui.toast("Capture enregistrée : " + ProjectSettings.globalize_path(path))
	else: ui.toast("Capture impossible dans ce mode de rendu.", true)


func _help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Utiliser Traffic"
	dialog.dialog_text = "1. Ouvrir un exemple ou générer une grille.\n2. Dans Réseau, créer et relier les nœuds. Valider le réseau.\n3. Dans Simulation, configurer les flux et appliquer.\n4. Démarrer, inspecter les agents, puis exporter.\n5. Dans Expériences, comparer les contrôleurs sur plusieurs graines.\n\nEspace : démarrer/pause · Ctrl+S : enregistrer · Ctrl+O : ouvrir\nCtrl+Z / Ctrl+Y : annuler/rétablir · F1 : aide\nMolette : zoom · clic droit : rotation · clic milieu : déplacement\n\nLes résultats concernent un modèle de simulation, pas une prédiction validée de trafic réel."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(640, 360))
