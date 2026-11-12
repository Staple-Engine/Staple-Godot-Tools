@tool
extends EditorPlugin

var entity_counter = 0

func _enter_tree() -> void:
	
	add_tool_menu_item("Staple Engine/Export selected files", Callable(self, "export"))
	
func _exit_tree() -> void:
	
	remove_tool_menu_item("Staple Engine/Export selected files")

func export() -> void:
	
	var save_dialog = EditorFileDialog.new()

	save_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	save_dialog.title = "Select folder to store exported files"
	
	save_dialog.dir_selected.connect(export_selected)
	
	EditorInterface.popup_dialog_centered(save_dialog)

func get_class_properties(node: Node) -> Array:
	
	var properties = node.get_property_list()
	var parent = ClassDB.get_parent_class(node.get_class())
	
	if parent == null or parent.is_empty():
		return properties
		
	var parent_properties = ClassDB.class_get_property_list(parent)
	
	var parent_property_names = PackedStringArray()
	
	for property in parent_properties:
		parent_property_names.append(property.name)
	
	var out_value = []
	
	for property in properties:
		
		if property.name in parent_property_names:
			continue
		
		out_value.append(property)
	
	return out_value
	
func add_node(node: Node, scene_data: Array, node_relationships: Dictionary):
	
	var parent_id = 0
	
	if node.get_parent() != null and node_relationships[node.get_parent()] != null:
		parent_id = int(node_relationships[node.get_parent()])
		
	entity_counter += 1
	
	var position = Vector3()
	var rotation = Vector3()
	var scale = Vector3()
	var visible = true
	
	if node is Node2D:
		var n: Node2D = node
		visible = n.is_visible()
		position = n.position
		rotation = n.rotation_degrees
		scale = n.scale

	if node is Node3D:
		var n: Node3D = node
		visible = n.is_visible()
		position = n.position
		rotation = n.rotation_degrees
		scale = n.scale
	
	var entity_data = {
		"kind": "Entity",
		"name": node.name,
		"ID": entity_counter,
		"parent": parent_id,
		"transform": {
			"position": {
				"x": position.x,
				"y": position.y,
				"z": position.z
			},
			"rotation": {
				"x": rotation.x,
				"y": rotation.y,
				"z": rotation.z,
			},
			"scale": {
				"x": scale.x,
				"y": scale.y,
				"z": scale.z,
			}
		},
		"layer": "Default",
		"enabled": visible,
		"hierarchyVisibility": "None"
	}

	var components = []
	
	var component_type = ""
	var component_data = {}
	
	match node.get_class():
		"AudioListener3D":
			component_type = "Staple.AudioListener"
		"Camera3D":
			var camera: Camera3D = node
			var projection = ""
			
			match camera.projection:
				Camera3D.PROJECTION_PERSPECTIVE:
					projection = "Perspective"
				Camera3D.PROJECTION_ORTHOGONAL:
					projection = "Orthographic"
				_:
					projection = "Perspective"
			
			component_type = "Staple.Camera"
			component_data = {
				"cullingLayers": camera.cull_mask,
				"farPlane": camera.far,
				"nearPlane": camera.near,
				"cameraType": projection,
				"orthographicSize": camera.size,
				"fov": camera.fov
			}
		"Node2D":
			component_type = ""
		"Node3D":
			component_type = ""
		_:
			component_type = node.get_class()
			var properties = get_class_properties(node)
			
			if properties != null and !properties.is_empty():
		
				for property in properties:

					if not(property.usage & PROPERTY_USAGE_STORAGE):
						continue

					match property.type:
						Variant.Type.TYPE_NIL:
							continue
							
						Variant.Type.TYPE_BOOL:
							component_data[property.name] = node.get(property.name)
						
						Variant.Type.TYPE_INT:
							component_data[property.name] = node.get(property.name)
						
						Variant.Type.TYPE_FLOAT:
							component_data[property.name] = node.get(property.name)
						
						Variant.Type.TYPE_STRING:
							component_data[property.name] = node.get(property.name)
						
						Variant.Type.TYPE_VECTOR2:
							var v: Vector2 = node.get(property.name)
							
							component_data[property.name] = {
								"x": v.x,
								"y": v.y,
							}
						
						Variant.Type.TYPE_VECTOR2I:
							var v: Vector2i = node.get(property.name)
							
							component_data[property.name] = {
								"x": v.x,
								"y": v.y,
							}
						
						Variant.Type.TYPE_VECTOR3:
							var v: Vector3 = node.get(property.name)
							
							component_data[property.name] = {
								"x": v.x,
								"y": v.y,
								"z": v.z,
							}
						
						Variant.Type.TYPE_VECTOR3I:
							var v: Vector3i = node.get(property.name)
							
							component_data[property.name] = {
								"x": v.x,
								"y": v.y,
								"z": v.z,
							}
						
						Variant.Type.TYPE_VECTOR4:
							var v: Vector4 = node.get(property.name)
							
							component_data[property.name] = {
								"x": v.x,
								"y": v.y,
								"z": v.z,
								"w": v.w,
							}
						
						Variant.Type.TYPE_VECTOR4I:
							var v: Vector4i = node.get(property.name)
							
							component_data[property.name] = {
								"x": v.x,
								"y": v.y,
								"z": v.z,
								"w": v.w,
							}
						
						Variant.Type.TYPE_COLOR:
							var v: Color = node.get(property.name)
							
							component_data[property.name] = v.to_html()
						
			
	
	components = {
		"type": component_type,
		"data": component_data
	}
	
	entity_data.components = components
	
	node_relationships[node] = entity_counter
	
	scene_data.append(entity_data)
	
	for child in node.get_children():
		add_node(child, scene_data, node_relationships)

func export_selected(path: String) -> void:
	var selected_files = EditorInterface.get_selected_paths()
	
	var valid_files = PackedStringArray()
	
	for file in selected_files:
		if file.ends_with(".tscn"):
			valid_files.append(file)
			
	if valid_files.size() == 0:
		var dialog = AcceptDialog.new()
		
		dialog.title = "Error"
		dialog.dialog_text = "No valid files selected. Currently only scenes may be exported."

		EditorInterface.popup_dialog_centered(dialog);
		
		return
		
	var failures = PackedStringArray()
	
	for file in valid_files:
		var resource: Resource = ResourceLoader.load(file)
		
		if not (resource is PackedScene):
			
			failures.append(file)
			
			return
		
		var scene: PackedScene = resource
		var instance: Node = scene.instantiate()
		
		var scene_data: Array = []
		var node_relationships = {}
		
		entity_counter = 0
		
		add_node(instance, scene_data, node_relationships)
		
		instance.queue_free()
		
		var data = JSON.stringify(scene_data, "\t", false)
		
		var out_file_name = path.path_join(file.get_file().replace(".tscn", ".scene"))
		
		var out_file = FileAccess.open(out_file_name, FileAccess.WRITE)
		
		if out_file:
			out_file.store_string(data)
			out_file.close()
			
			print("Saved %s!" % [out_file_name])
		else:
			failures.append(file)
		
	for failure in failures:
		print("Failed to export %s" % [failure])
