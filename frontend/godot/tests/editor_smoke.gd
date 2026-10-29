extends SceneTree


func _initialize() -> void:
	var editor = load("res://scripts/network_editor.gd").new()
	editor.tool = "node"
	editor.set_network({"nodes": [], "roads": []})
	editor.click(Vector3(0, 0, 0))
	editor.click(Vector3(100, 0, 0))
	assert(editor.network.nodes.size() == 2)
	editor.tool = "road"
	editor.selected = ""
	editor.click(Vector3.ZERO)
	editor.click(Vector3(100, 0, 0))
	assert(editor.network.roads.size() == 2)
	editor.tool = "delete_road"
	editor.click(Vector3(50, 0, 0))
	assert(editor.network.roads.is_empty())
	editor.undo()
	assert(editor.network.roads.size() == 2)
	editor.tool = "delete"
	editor.click(Vector3.ZERO)
	assert(editor.network.nodes.size() == 1 and editor.network.roads.is_empty())
	editor.undo()
	assert(editor.network.nodes.size() == 2 and editor.network.roads.size() == 2)
	print("TRAFFIC_EDITOR_OK : création, connexion, suppression et annulation.")
	quit(0)
