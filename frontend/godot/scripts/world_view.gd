extends Node3D

signal picked(kind: String, identifier: String)
signal edit_clicked(position: Vector3)

var agents: Dictionary = {}
var people: Dictionary = {}
var targets: Dictionary = {}
var light_views: Dictionary = {}
var roads_root := Node3D.new()
var vehicles_root := Node3D.new()
var nodes_root := Node3D.new()
var geometry_root := Node3D.new()
var decor := Node3D.new()
var camera := Camera3D.new()
var editing := false
var editor: RefCounted
var center := Vector3(100, 0, -100)
var camera_angle := 0.45
var camera_distance := 280.0
var camera_mode := 0
var model: Dictionary = {}
var selected := ""
var heatmap := false
var route_views: Dictionary = {}
var selection := MeshInstance3D.new()


func _ready() -> void:
	for item in [roads_root, vehicles_root, nodes_root, geometry_root, decor, camera]: add_child(item)
	camera.current = true
	var ring := TorusMesh.new()
	ring.inner_radius = 4.0
	ring.outer_radius = 5.0
	ring.rings = 32
	ring.ring_segments = 8
	selection.mesh = ring
	var selection_material := StandardMaterial3D.new()
	selection_material.albedo_color = Color("e0a12b")
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection.material_override = selection_material
	selection.visible = false
	add_child(selection)
	camera.far = 4000
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("e3e9ee")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)
	_update_camera()


func _process(delta: float) -> void:
	for identifier in targets:
		var item: Node3D = agents.get(identifier, people.get(identifier))
		if is_instance_valid(item): item.position = item.position.lerp(targets[identifier], minf(1, delta * 12))
	_update_camera()
	selection.visible = false
	if agents.has(selected) or people.has(selected):
		selection.position = agents.get(selected, people.get(selected)).position
		selection.position.y = 0.25
		selection.visible = true
	else:
		for node in model.get("nodes", []):
			if node.id == selected:
				selection.position = Vector3(node.x, 0.25, -node.y)
				selection.visible = true



func _update_camera() -> void:
	if camera_mode == 1:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = camera_distance
		camera.position = center + Vector3(0, camera_distance, 0.01)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE if camera_mode == 2 else Camera3D.PROJECTION_ORTHOGONAL
		camera.size = camera_distance
		camera.position = center + Vector3(sin(camera_angle) * camera_distance, camera_distance * 0.8, cos(camera_angle) * camera_distance)
	camera.look_at(center)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			camera_angle -= event.relative.x * 0.006
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			center += camera.global_basis.x * -event.relative.x * camera_distance / 650
			center += Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized() * -event.relative.y * camera_distance / 650
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_distance = maxf(40, camera_distance * 0.9)
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_distance = minf(1500, camera_distance * 1.1)
	if event.button_index != MOUSE_BUTTON_LEFT: return
	var point = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
	if point == null: return
	if editing:
		edit_clicked.emit(point)
		return
	var best := camera_distance / 35
	var chosen := ""
	var kind := ""
	for collection in [agents, people]:
		for identifier in collection:
			var item: Node3D = collection[identifier]
			var distance := Vector2(item.position.x, item.position.z).distance_to(Vector2(point.x, point.z))
			if distance < best:
				best = distance
				chosen = identifier
				kind = "vehicle" if collection == agents else "pedestrian"
	for node in model.get("nodes", []):
		var distance := Vector3(node.x, 0, -node.y).distance_to(point)
		if distance < best:
			best = distance
			chosen = node.id
			kind = "intersection"
	selected = chosen
	picked.emit(kind, chosen)


func load_network(network: Dictionary, geometry: Dictionary) -> void:
	model = network
	fit_network()
	_draw_network(network)
	_draw_geometry(geometry)
	_clear(decor)
	var ground := _box(Vector3(1800, 0.25, 1800), Color("d6dfe4"))
	ground.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decor.add_child(ground)
	ground.position = center - Vector3.UP * 0.35
	for index in range(-10, 11):
		var offset := float(index * 25)
		_segment(decor, center + Vector3(offset, -0.10, -250), center + Vector3(offset, -0.10, 250), 0.12, Color("becbd3"))
		_segment(decor, center + Vector3(-250, -0.10, offset), center + Vector3(250, -0.10, offset), 0.12, Color("becbd3"))
	_draw_blocks(network)


func fit_network() -> void:
	center = Vector3.ZERO
	for node in model.get("nodes", []): center += Vector3(float(node.x), 0, -float(node.y))
	center /= max(1, model.get("nodes", []).size())
	var extent := 100.0
	for node in model.get("nodes", []): extent = maxf(extent, center.distance_to(Vector3(float(node.x), 0, -float(node.y))) * 2.1)
	camera_distance = extent


func _draw_blocks(network: Dictionary) -> void:
	var xs: Array = []
	var ys: Array = []
	for node in network.nodes:
		if not xs.has(node.x): xs.append(node.x)
		if not ys.has(node.y): ys.append(node.y)
	xs.sort()
	ys.sort()
	for x in range(min(8, xs.size() - 1)):
		for y in range(min(8, ys.size() - 1)):
			var origin := Vector3((xs[x] + xs[x+1]) / 2, 0, -(ys[y] + ys[y+1]) / 2)
			var block_width: float = (xs[x+1] - xs[x]) * 0.65
			var block_depth: float = (ys[y+1] - ys[y]) * 0.65
			if block_width < 20 or block_depth < 20: continue
			var parcel := _box(Vector3(block_width, 0.4, block_depth), Color("9fae9e"))
			decor.add_child(parcel)
			parcel.position = origin
			for index in range(4):
				var height: float = 6 + posmod((x * 17 + y * 11 + index * 3), 12)
				var building := _box(Vector3(block_width * 0.3, height, block_depth * 0.3), Color("afb6bd") if index % 2 else Color("8d9eac"))
				decor.add_child(building)
				building.position = origin + Vector3((index % 2 - 0.5) * block_width * 0.6, height / 2, (floori(index / 2.0) - 0.5) * block_depth * 0.6)
				var roof := _box(Vector3(block_width * 0.3 + 0.6, 0.6, block_depth * 0.3 + 0.6), Color("596b78"))
				building.add_child(roof)
				roof.position.y = height / 2
				for level in range(1, int(height / 3)):
					var band := _box(Vector3(block_width * 0.3 + 0.1, 0.55, block_depth * 0.3 + 0.1), Color("667f90"))
					building.add_child(band)
					band.position.y = -height / 2 + level * 3


func update_snapshot(data: Dictionary) -> void:
	_render_agents(data.vehicles, agents, false)
	_render_agents(data.pedestrians, people, true)
	var loads: Dictionary = {}
	var closures: Dictionary = {}
	for road in model.get("roads", []):
		if not route_views.has(road.id): continue
		var mesh: MeshInstance3D = route_views[road.id]
		var key := mesh.get_instance_id()
		loads[key] = maxi(int(loads.get(key, 0)), int(data.get("congestion", {}).get(road.id, 0)))
		if road.id in data.get("closed_roads", []): closures[key] = true
	for road_id in route_views:
		var mesh: MeshInstance3D = route_views[road_id]
		var key := mesh.get_instance_id()
		var color := Color("3b5161")
		if heatmap: color = color.lerp(Color("c68a23"), minf(1, float(loads.get(key, 0)) / 8))
		if closures.has(key): color = Color("a94646")
		mesh.material_override.albedo_color = color
	for light in data.lights:
		if not light_views.has(light.id): continue
		var view: Dictionary = light_views[light.id]
		var vehicle_state := ""
		var pedestrian_state := ""
		for index in view.links:
			if view.links[index].pedestrian: pedestrian_state += light.state[int(index)]
			else: vehicle_state += light.state[int(index)]
		view.vehicle.material_override.albedo_color = _color_state(vehicle_state)
		view.pedestrian.material_override.albedo_color = _color_state(pedestrian_state)
		view.label.text = str(light.id) + "  V/P " + str(light.phase)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	return instance


func _segment(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> void:
	if start.distance_to(end) < 0.1: return
	var item := _box(Vector3(width, 0.15, start.distance_to(end)), color)
	parent.add_child(item)
	item.position = (start + end) / 2
	item.look_at(end)


func _draw_network(network: Dictionary) -> void:
	_clear(roads_root)
	_clear(nodes_root)
	route_views.clear()
	var positions: Dictionary = {}
	for node in network.get("nodes", []):
		var location := Vector3(float(node.x), 0, -float(node.y))
		positions[node.id] = location
		if editing:
			var marker := _box(Vector3(6, 1, 6), Color("e6ae42") if editor.selected == node.id else Color("23649a"))
			nodes_root.add_child(marker)
			marker.position = location + Vector3.UP
	var drawn: Dictionary = {}
	for road in network.get("roads", []):
		var pair := [str(road.source), str(road.target)]
		pair.sort()
		var key: String = "|".join(pair)
		if not positions.has(road.source) or not positions.has(road.target): continue
		if drawn.has(key):
			route_views[road.id] = drawn[key]
			continue
		var start: Vector3 = positions[road.source]
		var end: Vector3 = positions[road.target]
		var width: float = 4 + float(road.get("lanes", 1)) * 6.4
		_segment(roads_root, start - Vector3.UP * 0.08, end - Vector3.UP * 0.08, width + 4, Color("a9b5bf"))
		var index := roads_root.get_child_count()
		_segment(roads_root, start, end, width, Color("3b5161"))
		if roads_root.get_child_count() > index:
			var mesh: MeshInstance3D = roads_root.get_child(index)
			drawn[key] = mesh
			route_views[road.id] = mesh
		var direction := (end - start).normalized()
		var perpendicular := Vector3(-direction.z, 0, direction.x)
		var length := start.distance_to(end)
		for offset in [-width / 2 + 0.3, width / 2 - 0.3]:
			_segment(roads_root, start + perpendicular * offset + Vector3.UP * 0.11, end + perpendicular * offset + Vector3.UP * 0.11, 0.16, Color("d6dce0"))
		for distance in range(12, int(length) - 12, 7):
			var a := start + direction * distance + Vector3.UP * 0.12
			_segment(roads_root, a, a + direction * 3, 0.22, Color("ede5bf"))


func _draw_geometry(geometry: Dictionary) -> void:
	_clear(geometry_root)
	light_views.clear()
	for crossing in geometry.get("crossings", []):
		var shape: Array = crossing.shape
		for index in range(shape.size() - 1):
			var a := Vector3(shape[index][0], 0.25, -shape[index][1])
			var b := Vector3(shape[index + 1][0], 0.25, -shape[index + 1][1])
			var direction := (b - a).normalized()
			for distance in range(0, int(a.distance_to(b)), 2):
				var stripe := a + direction * distance
				_segment(geometry_root, stripe, stripe + direction * minf(0.8, stripe.distance_to(b)), 2, Color("edf1f3"))
	for light in geometry.get("lights", []):
		var marker := _box(Vector3(2, 5, 2), Color.RED)
		var pedestrian := _box(Vector3(2, 3, 2), Color.RED)
		geometry_root.add_child(marker)
		geometry_root.add_child(pedestrian)
		marker.position = Vector3(float(light.x) - 6, 3, -float(light.y) - 6)
		pedestrian.position = marker.position + Vector3(3, 0, 0)
		var label := Label3D.new()
		label.text = str(light.id) + " | V  P"
		label.font_size = 40
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		geometry_root.add_child(label)
		label.position = marker.position + Vector3(1, 5, 0)
		light_views[light.id] = {"vehicle": marker, "pedestrian": pedestrian, "label": label, "links": light.links}


func _render_agents(states: Array, collection: Dictionary, pedestrian: bool) -> void:
	var present: Dictionary = {}
	for state in states:
		present[state.id] = true
		var location := Vector3(float(state.x), 0.95 if pedestrian else 0.85, -float(state.y))
		if not collection.has(state.id):
			var item: MeshInstance3D
			if pedestrian:
				item = MeshInstance3D.new()
				var capsule := CapsuleMesh.new()
				capsule.radius = 0.35
				capsule.height = 1.8
				item.mesh = capsule
				var material := StandardMaterial3D.new()
				material.albedo_color = Color("c67b29")
				item.material_override = material
			else:
				item = _box(Vector3(1.8, 1.1, 4.5), Color("2585b5"))
				var cabin := _box(Vector3(1.45, 0.7, 2), Color("c7e5ec"))
				item.add_child(cabin)
				cabin.position.y = 0.9
			vehicles_root.add_child(item)
			item.position = location
			collection[state.id] = item
		targets[state.id] = location
		if not pedestrian: collection[state.id].rotation.y = -deg_to_rad(float(state.angle))
	for identifier in collection.keys():
		if not present.has(identifier):
			collection[identifier].queue_free()
			collection.erase(identifier)
			targets.erase(identifier)


func _color_state(state: String) -> Color:
	if state.contains("G") or state.contains("g"): return Color(0.2, 0.85, 0.3)
	if state.contains("y") or state.contains("Y"): return Color(1, 0.7, 0.1)
	return Color(0.95, 0.15, 0.15)



