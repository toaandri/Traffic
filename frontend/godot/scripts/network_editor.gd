extends RefCounted
## Modifications locales : le backend valide et applique le réseau au lancement.

var network: Dictionary = {}
var selected := ""
var tool := "select"
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []


func set_network(value: Dictionary) -> void:
	network = value.duplicate(true)
	selected = ""
	history.clear()
	future.clear()


func _remember() -> void:
	future.clear()
	history.append(network.duplicate(true))
	if history.size() > 50:
		history.pop_front()


func undo() -> void:
	if not history.is_empty():
		future.append(network.duplicate(true))
		network = history.pop_back()
		selected = ""


func redo() -> void:
	if not future.is_empty():
		history.append(network.duplicate(true))
		network = future.pop_back()
		selected = ""


func nearest(position: Vector3) -> String:
	var result := ""
	var distance := 15.0
	for node in network.get("nodes", []):
		var candidate := Vector3(float(node.x), 0, -float(node.y)).distance_to(position)
		if candidate < distance:
			distance = candidate
			result = str(node.id)
	return result


func click(position: Vector3) -> void:
	var target := nearest(position)
	if tool == "select":
		selected = target
		return
	if tool == "delete_road":
		var positions: Dictionary = {}
		for node in network.nodes:
			positions[node.id] = Vector3(float(node.x), 0, -float(node.y))
		var closest: Dictionary = {}
		var distance := 8.0
		for road in network.roads:
			var point := Geometry3D.get_closest_point_to_segment(position, positions[road.source], positions[road.target])
			if point.distance_to(position) < distance:
				distance = point.distance_to(position)
				closest = road
		if not closest.is_empty():
			_remember()
			network.roads = network.roads.filter(func(road): return not ((road.source == closest.source and road.target == closest.target) or (road.source == closest.target and road.target == closest.source)))
		return
	if tool == "node":
		if not target.is_empty():
			selected = target
			return
		_remember()
		var identifier := "custom" + str(Time.get_ticks_usec())
		network.nodes.append({"id": identifier, "x": snappedf(position.x, 25), "y": snappedf(-position.z, 25)})
		var point := Vector3(snappedf(position.x, 25), 0, snappedf(position.z, 25))
		var positions: Dictionary = {}
		for node in network.nodes: positions[node.id] = Vector3(float(node.x), 0, -float(node.y))
		var replacements: Array = []
		for road in network.roads:
			var a: Vector3 = positions[road.source]
			var b: Vector3 = positions[road.target]
			var closest := Geometry3D.get_closest_point_to_segment(point, a, b)
			if closest.distance_to(point) < 1 and point.distance_to(a) > 20 and point.distance_to(b) > 20:
				for pair in [[road.source, identifier], [identifier, road.target]]:
					var replacement: Dictionary = road.duplicate(true)
					replacement.id = str(pair[0]) + "__" + str(pair[1])
					replacement.source = pair[0]
					replacement.target = pair[1]
					replacements.append(replacement)
			else: replacements.append(road)
		network.roads = replacements
		selected = identifier
	elif tool == "road":
		if not selected.is_empty() and not target.is_empty() and target != selected:
			_remember()
			for pair in [[selected, target], [target, selected]]:
				var identifier: String = str(pair[0]) + "__" + str(pair[1])
				var exists := false
				for road in network.roads:
					if road.source == pair[0] and road.target == pair[1]:
						exists = true
				if not exists:
					network.roads.append({"id": identifier, "source": pair[0], "target": pair[1], "lanes": 1, "speed": 13.89})
		selected = target
	elif tool == "move":
		if not target.is_empty():
			selected = target
		elif not selected.is_empty():
			_remember()
			for node in network.nodes:
				if node.id == selected:
					node.x = snappedf(position.x, 25)
					node.y = snappedf(-position.z, 25)
	elif tool == "delete" and not target.is_empty():
		_remember()
		network.nodes = network.nodes.filter(func(node): return node.id != target)
		network.roads = network.roads.filter(func(road): return road.source != target and road.target != target)
		if network.has("crossings"): network.crossings = network.crossings.filter(func(crossing): return crossing.node != target)
		selected = ""
