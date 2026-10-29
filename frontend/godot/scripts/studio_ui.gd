extends Control

signal action(name: String, payload: Dictionary)

var world: Node3D
var viewport := SubViewport.new()
var tabs := TabContainer.new()
var chart := preload("res://scripts/metrics_chart.gd").new()
var project_name := LineEdit.new()
var description := TextEdit.new()
var vehicles := SpinBox.new()
var pedestrians := SpinBox.new()
var seed := SpinBox.new()
var duration := SpinBox.new()
var step := SpinBox.new()
var rows := SpinBox.new()
var columns := SpinBox.new()
var spacing := SpinBox.new()
var density := SpinBox.new()
var green := SpinBox.new()
var minimum_green := SpinBox.new()
var maximum_green := SpinBox.new()
var vehicle_rate := SpinBox.new()
var pedestrian_rate := SpinBox.new()
var lanes := SpinBox.new()
var speed := SpinBox.new()
var algorithm := OptionButton.new()
var demand := OptionButton.new()
var vehicle_profile := OptionButton.new()
var pedestrian_speed := SpinBox.new()
var time_label := Label.new()
var status := Label.new()
var message := Label.new()
var performance := Label.new()
var inspector := RichTextLabel.new()
var results := RichTextLabel.new()
var projects := ItemList.new()
var history := ItemList.new()
var events := ItemList.new()
var play: Button
var apply: Button
var compare: Button
var busy := ProgressBar.new()
var metrics: Dictionary = {}
var origin := OptionButton.new()
var destination := OptionButton.new()
var route_names: Array[String] = []
var event_time := SpinBox.new()
var event_amount := SpinBox.new()
var event_people := SpinBox.new()
var event_kind := OptionButton.new()
var event_road := OptionButton.new()
var event_duration := SpinBox.new()
var seed_count := SpinBox.new()
var automatic_crossings := CheckBox.new()
var settings := Window.new()
var network_tree := Tree.new()
var document_title := Label.new()
var scenario_summary := Label.new()
var mode_buttons: Array[Button] = []
var tool_buttons: Array[Button] = []
var analysis := TabContainer.new()
var project_items: Array = []
var history_items: Array = []


func _style(color: Color, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(margin)
	return box


func _theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	theme.default_font = font
	theme.default_font_size = 13
	for kind in ["Label", "Button", "LineEdit", "TextEdit", "OptionButton", "CheckBox", "TabContainer", "ItemList", "RichTextLabel", "Tree"]:
		theme.set_color("font_color", kind, Color("243746"))
		theme.set_color("font_hover_color", kind, Color("23649a"))
		theme.set_color("font_focus_color", kind, Color("23649a"))
		theme.set_color("font_pressed_color", kind, Color("174d78"))
		theme.set_color("font_disabled_color", kind, Color("6c7d8b"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("687987"))
	theme.set_color("icon_normal_color", "OptionButton", Color("526777"))
	theme.set_color("icon_normal_color", "SpinBox", Color("526777"))
	for kind in ["Button", "OptionButton"]:
		for state_name in ["normal", "hover", "pressed", "disabled"]:
			var box := _style(Color("f0f3f7") if state_name == "normal" else Color("dceaf5"), 10)
			box.set_corner_radius_all(3)
			box.border_color = Color("c8d1db")
			box.set_border_width_all(1)
			theme.set_stylebox(state_name, kind, box)
		var focus := _style(Color(0,0,0,0), 10)
		focus.border_color = Color("23649a")
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", kind, focus)
	for kind in ["LineEdit", "TextEdit", "ItemList"]:
		theme.set_stylebox("normal", kind, _style(Color("f0f3f7"), 8))
	theme.set_color("default_color", "RichTextLabel", Color("243746"))
	theme.set_color("font_selected_color", "TabContainer", Color("243746"))
	theme.set_color("font_unselected_color", "TabContainer", Color("526d7e"))
	theme.set_stylebox("panel", "PanelContainer", _style(Color("f7f9fb"), 10))
	theme.set_stylebox("panel", "Tree", _style(Color("f7f9fb"), 4))
	theme.set_stylebox("selected", "Tree", _style(Color("dceaf5"), 4))
	theme.set_color("font_color", "Tree", Color("243746"))
	theme.set_color("font_selected_color", "Tree", Color("243746"))
	theme.set_constant("v_separation", "Tree", 9)
	theme.set_stylebox("panel", "TabContainer", _style(Color.WHITE, 10))
	theme.set_stylebox("tab_selected", "TabContainer", _style(Color("dceaf5"), 9))
	theme.set_stylebox("tab_unselected", "TabContainer", _style(Color("f0f3f7"), 9))
	theme.set_stylebox("tabbar_background", "TabContainer", _style(Color("e4e9ef"), 0))
	return theme


func _label(parent: Control, text: String, size: int = 14) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(item)
	return item


func _button(parent: Control, text: String, command: String, data: Dictionary = {}) -> Button:
	var item := Button.new()
	item.text = text
	item.tooltip_text = text
	item.custom_minimum_size.y = 30
	item.pressed.connect(func(): action.emit(command, data))
	parent.add_child(item)
	return item


func _field(parent: Control, text: String, input: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var caption := _label(row, text, 13)
	caption.custom_minimum_size.x = 245
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.y = maxf(30, input.custom_minimum_size.y)
	row.add_child(input)


func _number(parent: Control, title: String, input: SpinBox, minimum: float, maximum: float, value: float, increment: float = 1) -> void:
	input.min_value = minimum
	input.max_value = maximum
	input.step = increment
	input.value = value
	_field(parent, title, input)


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)
	return column


func _section(parent: Control, title: String) -> void:
	parent.add_child(HSeparator.new())
	_label(parent, title, 17)


func _menu(parent: Control, title: String, entries: Array) -> void:
	var menu := MenuButton.new()
	menu.text = title
	parent.add_child(menu)
	for entry in entries: menu.get_popup().add_item(entry[0])
	menu.get_popup().index_pressed.connect(func(index): action.emit(entries[index][1], {}))


func open_settings(index: int) -> void:
	tabs.current_tab = index
	settings.popup_centered(Vector2i(680, mini(660, int(get_viewport_rect().size.y) - 90)))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _theme()
	var background := ColorRect.new()
	background.color = Color("e4e9ef")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/traffic.svg")
	icon.custom_minimum_size = Vector2(24,24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	_label(header, "Traffic", 17).autowrap_mode = TextServer.AUTOWRAP_OFF
	_menu(header, "Projet", [["Nouveau", "new"], ["Ouvrir…  Ctrl+O", "open_dialog"], ["Enregistrer  Ctrl+S", "save_project"], ["Dupliquer", "duplicate"], ["Exporter le projet JSON…", "export_json"], ["Reprendre le brouillon", "recover"]])
	_menu(header, "Édition", [["Annuler  Ctrl+Z", "undo"], ["Rétablir  Ctrl+Y", "redo"], ["Valider le réseau", "validate"]])
	_menu(header, "Résultats", [["Exporter les mesures", "export"], ["Ouvrir le dossier", "open_results"], ["Capturer la vue", "capture"]])
	_menu(header, "Aide", [["Utiliser Traffic  F1", "help"]])
	document_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	document_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	document_title.clip_text = true
	header.add_child(document_title)
	status.text = "Connexion…"
	header.add_child(status)
	_button(header, "Enregistrer", "save_project").tooltip_text = "Enregistrer le projet (Ctrl+S)"
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	var modes := ButtonGroup.new()
	for index in range(3):
		var button := Button.new()
		button.text = ["Réseau", "Simulation", "Expériences"][index]
		button.toggle_mode = true
		button.button_group = modes
		button.custom_minimum_size.y = 34
		button.pressed.connect(func():
			tabs.current_tab = index
			if index == 2: open_settings(index))
		toolbar.add_child(button)
		mode_buttons.append(button)
	_button(toolbar, "Paramètres…", "settings")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	play = _button(toolbar, "Démarrer", "toggle_play")
	_button(toolbar, "Réinitialiser", "reset")
	for value in [0.5, 1.0, 2.0]: _button(toolbar, str(value) + "×", "speed", {"value": value})
	time_label.custom_minimum_size.x = 72
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.text = "0.0 s"
	toolbar.add_child(time_label)
	settings.title = "Configuration du projet"
	settings.transient = true
	settings.exclusive = true
	settings.min_size = Vector2i(620, 400)
	settings.close_requested.connect(func(): settings.hide())
	add_child(settings)
	settings.hide()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(tabs)
	tabs.tab_changed.connect(func(index):
		mode_buttons[index].button_pressed = true
		action.emit("mode", {"index": index}))
	var network := _tab("Réseau")
	_label(network, "Construire le réseau", 20)
	_label(network, "Cliquer dans la ville. Les modifications sont validées avant le lancement.", 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tools := GridContainer.new()
	tools.columns = 2
	network.add_child(tools)
	for entry in [["Sélectionner", "select"], ["Ajouter un nœud", "node"], ["Relier", "road"], ["Déplacer", "move"], ["Effacer nœud", "delete"], ["Effacer route", "delete_road"]]:
		_button(tools, entry[0], "tool", {"tool": entry[1]})
	var undo := HBoxContainer.new()
	network.add_child(undo)
	_button(undo, "Annuler", "undo")
	_button(undo, "Rétablir", "redo")
	_section(network, "Générer une ville")
	var dimensions := VBoxContainer.new()
	network.add_child(dimensions)
	_number(dimensions, "Lignes", rows, 2, 6, 3)
	_number(dimensions, "Colonnes", columns, 2, 6, 3)
	_number(network, "Espacement (m)", spacing, 60, 200, 100, 10)
	_number(network, "Densité routière (%)", density, 40, 100, 100, 10)
	_button(network, "Générer la grille", "generate")
	_section(network, "Élément sélectionné")
	_number(network, "Voies par direction", lanes, 1, 4, 1)
	_number(network, "Vitesse maximale (km/h)", speed, 10, 70, 50, 5)
	_number(network, "Vert fixe (secondes)", green, 5, 120, 30)
	_number(network, "Vert minimal (s)", minimum_green, 5, 120, 10)
	_number(network, "Vert maximal (s)", maximum_green, 5, 120, 40)
	_button(network, "Modifier la sélection", "edit_properties")
	automatic_crossings.text = "Générer les passages piétons"
	automatic_crossings.button_pressed = true
	network.add_child(automatic_crossings)
	_button(network, "Ajouter une traversée au nœud", "crossing")
	_button(network, "Valider le réseau", "validate")
	var simulation := _tab("Simulation")
	_label(simulation, "Scénario", 20)
	_field(simulation, "Nom du projet", project_name)
	project_name.placeholder_text = "Mon quartier"
	description.custom_minimum_size.y = 64
	_field(simulation, "Description", description)
	_number(simulation, "Véhicules à injecter", vehicles, 0, 2000, 100)
	_number(simulation, "Piétons à injecter", pedestrians, 0, 1000, 30)
	_number(simulation, "Débit véhicules/h (0 = auto)", vehicle_rate, 0, 50000, 0, 50)
	_number(simulation, "Débit piétons/h (0 = auto)", pedestrian_rate, 0, 50000, 0, 50)
	_number(simulation, "Durée de l’essai (s)", duration, 10, 3600, 120, 10)
	_number(simulation, "Pas de simulation (s)", step, 0.05, 1, 0.1, 0.05)
	_number(simulation, "Graine reproductible", seed, 0, 2147483645, 42)
	algorithm.add_item("Feux fixes")
	algorithm.add_item("Feux adaptatifs")
	algorithm.add_item("Max-Pressure")
	_field(simulation, "Contrôleur", algorithm)
	vehicle_profile.add_item("Conduite standard")
	vehicle_profile.add_item("Conduite prudente")
	vehicle_profile.add_item("Conduite agressive")
	_field(simulation, "Profil de conduite", vehicle_profile)
	_number(simulation, "Vitesse de marche (m/s)", pedestrian_speed, 0.5, 3, 1.3, 0.1)
	demand.add_item("Demande régulière")
	demand.add_item("Heure de pointe")
	_field(simulation, "Répartition des départs", demand)
	_field(simulation, "Origine véhicules / piétons", origin)
	_field(simulation, "Destination véhicules / piétons", destination)
	apply = _button(simulation, "Appliquer et réinitialiser", "apply")
	_section(simulation, "Événements programmés")
	event_kind.add_item("Hausse de demande")
	event_kind.add_item("Fermeture de route")
	event_kind.add_item("Accident simulé")
	_field(simulation, "Type d’événement", event_kind)
	_number(simulation, "Instant (s)", event_time, 0, 3599, 30)
	_number(simulation, "Véhicules supplémentaires", event_amount, 0, 500, 20)
	_number(simulation, "Piétons supplémentaires", event_people, 0, 500, 0)
	_field(simulation, "Route concernée", event_road)
	_number(simulation, "Durée de l’incident (s)", event_duration, 1, 600, 30)
	_button(simulation, "Programmer l’événement", "event")
	events.custom_minimum_size.y = 85
	simulation.add_child(events)
	_button(simulation, "Supprimer l’événement choisi", "remove_event")
	var experiments := _tab("Expériences")
	_label(experiments, "Comparer les contrôleurs", 20)
	_label(experiments, "Même carte, demande et événements pour chaque graine. Le rendu est suspendu pendant les essais.", 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_number(experiments, "Nombre de graines", seed_count, 1, 10, 3)
	compare = _button(experiments, "Lancer la comparaison", "compare")
	busy.indeterminate = true
	busy.show_percentage = false
	busy.visible = false
	experiments.add_child(busy)
	_button(experiments, "Annuler le calcul", "cancel_comparison")
	_button(experiments, "Campagne de résistance", "stress")
	_button(experiments, "Exporter les mesures", "export")
	_button(experiments, "Ouvrir les résultats", "open_results")
	_section(experiments, "Historique des campagnes")
	history.custom_minimum_size.y = 140
	experiments.add_child(history)
	history.item_selected.connect(func(index): action.emit("history", {"index": index}))
	_section(experiments, "Projets enregistrés")
	projects.custom_minimum_size.y = 120
	experiments.add_child(projects)
	projects.item_activated.connect(func(index): action.emit("load_project", {"index": index}))
	_button(experiments, "Actualiser la bibliothèque", "catalog")
	_button(experiments, "Reprendre le brouillon", "recover")
	for entry in [["Exemple : quatre carrefours", "crossing_lab"], ["Exemple : ville en grille", "grid"], ["Exemple : congestion", "congestion"]]:
		_button(experiments, entry[0], "example", {"name": entry[1]})
	var settings_layout := VBoxContainer.new()
	settings_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(settings_layout)
	tabs.reparent(settings_layout)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var settings_footer := HBoxContainer.new()
	settings_layout.add_child(settings_footer)
	var settings_spacer := Control.new()
	settings_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_footer.add_child(settings_spacer)
	apply.reparent(settings_footer)
	var close_settings := Button.new()
	close_settings.text = "Fermer"
	close_settings.custom_minimum_size = Vector2(100, 34)
	close_settings.pressed.connect(func(): settings.hide())
	settings_footer.add_child(close_settings)
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 224
	root.add_child(body)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 220
	body.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left_panel.add_child(left)
	_label(left, "Explorateur du réseau", 17)
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher un objet…"
	search.clear_button_enabled = true
	left.add_child(search)
	search.text_changed.connect(_filter_tree)
	network_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_tree.custom_minimum_size.y = 170
	network_tree.hide_root = true
	left.add_child(network_tree)
	network_tree.item_selected.connect(func():
		var item := network_tree.get_selected()
		var metadata = item.get_metadata(0)
		if metadata is Dictionary: action.emit("inspect_object", metadata))
	_section(left, "Édition du réseau")
	var tools_bar := GridContainer.new()
	tools_bar.columns = 2
	left.add_child(tools_bar)
	var group := ButtonGroup.new()
	for entry in [["Sélection", "select"], ["Nœud +", "node"], ["Relier", "road"], ["Déplacer", "move"], ["Nœud −", "delete"], ["Route −", "delete_road"]]:
		var button := _button(tools_bar, entry[0], "tool", {"tool": entry[1]})
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tool_buttons.append(button)
	tool_buttons[0].button_pressed = true
	var edit_row := HBoxContainer.new()
	left.add_child(edit_row)
	_button(edit_row, "Annuler", "undo")
	_button(edit_row, "Rétablir", "redo")
	_section(left, "Scénario actif")
	scenario_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(scenario_summary)
	_button(left, "Configurer le scénario…", "settings", {"index": 1})
	var main_split := HSplitContainer.new()
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_split)
	var center_column := VSplitContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(center_column)
	var canvas := VBoxContainer.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_child(canvas)
	var viewbar := HBoxContainer.new()
	canvas.add_child(viewbar)
	_label(viewbar, "Vue du réseau", 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [["3D", 0], ["Plan", 1], ["Perspective", 2]]:
		_button(viewbar, entry[0], "camera", {"mode": entry[1]})
	_button(viewbar, "Cadrer", "fit_camera")
	_button(viewbar, "Congestion", "heatmap").toggle_mode = true
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size = Vector2(300, 270)
	canvas.add_child(viewport_container)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	viewport.add_child(world)
	var legend := HBoxContainer.new()
	canvas.add_child(legend)
	_label(legend, "● Véhicules", 12).add_theme_color_override("font_color", Color("2585b5"))
	_label(legend, "● Piétons", 12).add_theme_color_override("font_color", Color("a15c17"))
	_label(legend, "Feux : vert / orange / rouge", 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(legend, "Molette : zoom", 12)
	analysis.custom_minimum_size.y = 165
	center_column.add_child(analysis)
	chart.name = "Agents en attente"
	chart.custom_minimum_size.y = 130
	analysis.add_child(chart)
	results.name = "Comparaison"
	results.bbcode_enabled = true
	results.text = "Lancez une comparaison dans Expériences pour examiner les résultats des contrôleurs."
	analysis.add_child(results)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size.x = 234
	main_split.add_child(right_panel)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	right_scroll.add_child(right)
	_label(right, "Sélection", 17)
	inspector.fit_content = true
	inspector.custom_minimum_size = Vector2(210, 130)
	inspector.bbcode_enabled = true
	inspector.text = "Sélectionnez un objet dans la carte ou dans l’explorateur pour consulter ses propriétés."
	right.add_child(inspector)
	_button(right, "Propriétés du réseau…", "settings", {"index": 0})
	_section(right, "Mesures de l’essai")
	for entry in [["vehicles", "Véhicules actifs / arrivés"], ["pedestrians", "Piétons actifs / arrivés"], ["wait", "En attente : véhicules / piétons"], ["average_wait", "Attente moyenne des arrivés"], ["travel", "Trajet moyen des arrivés"], ["unfinished", "Trajets inachevés"]]:
		_label(right, entry[1], 12)
		metrics[entry[0]] = _label(right, "—", 17)
	_label(right, "Les moyennes portent sur les agents arrivés. Les trajets inachevés sont comptés séparément.", 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := HBoxContainer.new()
	root.add_child(footer)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.clip_text = true
	message.text = "Prêt. Clic droit : rotation ; clic milieu : déplacement."
	footer.add_child(message)
	experiments.remove_child(busy)
	busy.custom_minimum_size = Vector2(95, 8)
	busy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(busy)
	var cancel := _button(footer, "Annuler le calcul", "cancel_comparison")
	cancel.visible = false
	busy.visibility_changed.connect(func(): cancel.visible = busy.visible)
	footer.add_child(performance)
	tabs.current_tab = 1
	mode_buttons[1].button_pressed = true
	for button in tool_buttons: button.disabled = true
	tabs.tab_changed.connect(func(index):
		for button in tool_buttons: button.disabled = index != 0)


func _filter_tree(query: String) -> void:
	var root_item := network_tree.get_root()
	if root_item == null: return
	for category in root_item.get_children():
		if not query.is_empty(): category.collapsed = false
		for item in category.get_children():
			item.visible = query.is_empty() or query.to_lower() in item.get_text(0).to_lower()


func refresh_network(network: Dictionary) -> void:
	network_tree.clear()
	var root_item := network_tree.create_item()
	for entry in [["nodes", "Intersections", "intersection"], ["roads", "Routes", "road"]]:
		var objects: Array = network.get(entry[0], [])
		var category := network_tree.create_item(root_item)
		category.set_text(0, "%s (%d)" % [entry[1], objects.size()])
		category.set_selectable(0, false)
		category.collapsed = entry[0] == "roads"
		for object in objects:
			var item := network_tree.create_item(category)
			item.set_text(0, str(object.id))
			item.set_metadata(0, {"kind": entry[2], "id": str(object.id)})


func toast(text: String, error: bool = false) -> void:
	message.text = text
	message.tooltip_text = text
	message.modulate = Color("a23838") if error else Color("243746")


func populate(scenario: Dictionary) -> void:
	document_title.text = scenario.name
	var controller_label: String = {"adaptive": "Feux adaptatifs", "max_pressure": "Max-Pressure"}.get(scenario.controller, "Feux fixes")
	scenario_summary.text = "%d véhicules / %d piétons\nDurée : %.0f s\n%s" % [scenario.vehicles, scenario.pedestrians, scenario.duration, controller_label]
	refresh_network(scenario.network)
	project_name.text = scenario.name
	description.text = scenario.get("description", "")
	vehicles.value = scenario.vehicles
	pedestrians.value = scenario.pedestrians
	vehicle_rate.value = float(scenario.get("vehicle_rate", 0)) if scenario.get("vehicle_rate") != null else 0
	pedestrian_rate.value = float(scenario.get("pedestrian_rate", 0)) if scenario.get("pedestrian_rate") != null else 0
	seed.value = scenario.seed
	duration.value = scenario.duration
	step.value = scenario.step_length
	algorithm.select({"adaptive": 1, "max_pressure": 2}.get(scenario.controller, 0))
	vehicle_profile.select({"cautious": 1, "aggressive": 2}.get(scenario.get("vehicle_profile", "standard"), 0))
	pedestrian_speed.value = scenario.get("pedestrian_speed", 1.3)
	demand.select(1 if scenario.get("demand_profile") == "peak" else 0)
	automatic_crossings.button_pressed = scenario.network.get("auto_crossings", true)
	origin.clear()
	destination.clear()
	event_road.clear()
	origin.add_item("Répartition automatique")
	destination.add_item("Répartition automatique")
	route_names.clear()
	for road in scenario.network.roads:
		route_names.append(road.id)
		origin.add_item(road.id)
		destination.add_item(road.id)
		event_road.add_item(road.id)
	for choice in [origin, destination, event_road]:
		choice.fit_to_longest_item = false
		choice.clip_text = true
		choice.custom_minimum_size.x = 0
	for field in [[origin, "vehicle_origins"], [destination, "vehicle_destinations"]]:
		var values: Array = scenario.get(field[1], [])
		if not values.is_empty(): field[0].select(route_names.find(values[0]) + 1)
	refresh_events(scenario.events)


func refresh_events(items: Array) -> void:
	events.clear()
	for event in items:
		events.add_item("%.0f s : %s" % [event.time, ("+%d V / %d P" % [event.vehicles, event.get("pedestrians", 0)]) if event.has("vehicles") else str(event.type) + " " + str(event.road)])


func metric_snapshot(data: Dictionary) -> void:
	time_label.text = "%.1f s" % data.time
	metrics.vehicles.text = "%d / %d" % [data.metrics.active, data.metrics.arrived]
	metrics.pedestrians.text = "%d / %d" % [data.metrics.pedestrians_active, data.metrics.pedestrians_arrived]
	metrics.wait.text = "%d / %d" % [data.metrics.waiting_now, data.metrics.pedestrians_waiting]
	var summary: Dictionary = data.summary
	metrics.travel.text = _seconds(summary.vehicles.mean_travel_time) + " / " + _seconds(summary.pedestrians.mean_travel_time)
	metrics.average_wait.text = _seconds(summary.vehicles.mean_waiting_time) + " / " + _seconds(summary.pedestrians.mean_waiting_time)
	metrics.unfinished.text = "%d / %d" % [summary.vehicles.unfinished, summary.pedestrians.unfinished]
	chart.add_point(float(data.time), int(data.metrics.waiting_now), int(data.metrics.pedestrians_waiting))
	performance.text = "%d FPS" % Engine.get_frames_per_second()
	if data.has("performance"): performance.text += " / %.1f ms par pas" % data.performance.step_ms


func _seconds(value) -> String:
	return "—" if value == null else "%.1f s" % float(value)


func show_report(report: Dictionary) -> void:
	analysis.current_tab = 1
	var fixed: Dictionary = report.aggregates.fixed
	var adaptive: Dictionary = report.aggregates.adaptive
	var max_pressure: Dictionary = report.aggregates.max_pressure
	results.text = "[b]Fixe / adaptatif / Max-Pressure[/b]\nArrivées véhicules\n%.1f / %.1f / %.1f\n\nArrivées piétons\n%.1f / %.1f / %.1f\n\nAttente véhicules arrivés\n%s / %s / %s\n\nExaminer aussi les trajets inachevés.\nGraines : %s" % [fixed.mean_vehicle_arrivals, adaptive.mean_vehicle_arrivals, max_pressure.mean_vehicle_arrivals, fixed.mean_pedestrian_arrivals, adaptive.mean_pedestrian_arrivals, max_pressure.mean_pedestrian_arrivals, _seconds(fixed.mean_vehicle_wait), _seconds(adaptive.mean_vehicle_wait), _seconds(max_pressure.mean_vehicle_wait), str(report.seeds)]
