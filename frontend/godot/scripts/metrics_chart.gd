extends Control
## Deux séries d'attente en temps simulé ; affichage sans modifier la simulation.

var samples: Array[Vector3] = []


func _ready() -> void:
	custom_minimum_size = Vector2(100, 115)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func clear() -> void:
	samples.clear()
	queue_redraw()


func add_point(time: float, vehicles: int, pedestrians: int) -> void:
	if not samples.is_empty() and time <= samples.back().x:
		if time < samples.back().x: samples.clear()
		else: return
	samples.append(Vector3(time, vehicles, pedestrians))
	if samples.size() > 300: samples.pop_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f7f9fb"))
	var font := get_theme_default_font()
	draw_string(font, Vector2(40, 18), "Véhicules", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2585b5"))
	draw_string(font, Vector2(135, 18), "Piétons", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a15c17"))
	if samples.size() < 2:
		draw_string(font, Vector2(40, 62), "Démarrez l’essai pour suivre les files d’attente.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 13, Color("526777"))
		return
	var maximum := 1.0
	for sample in samples: maximum = maxf(maximum, maxf(sample.y, sample.z))
	var start: float = samples.front().x
	for index in range(4):
		var y := 32.0 + index * (size.y - 50) / 3
		draw_line(Vector2(32, y), Vector2(size.x - 18, y), Color("dce3ea"), 1)
	var span: float = maxf(0.1, samples.back().x - start)
	var cars := PackedVector2Array()
	var people := PackedVector2Array()
	for sample in samples:
		var x: float = 32 + (sample.x - start) / span * (size.x - 50)
		cars.append(Vector2(x, size.y - 18 - sample.y / maximum * (size.y - 50)))
		people.append(Vector2(x, size.y - 18 - sample.z / maximum * (size.y - 50)))
	draw_polyline(cars, Color("2585b5"), 2, true)
	draw_polyline(people, Color("c67b29"), 2, true)
	draw_string(font, Vector2(3, 37), str(int(maximum)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("526777"))
	draw_string(font, Vector2(3, size.y - 18), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("526777"))
	draw_string(font, Vector2(32, size.y - 2), "%.1f s" % start, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("526777"))
	draw_string(font, Vector2(size.x - 70, size.y - 2), "%.1f s" % samples.back().x, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("526777"))
