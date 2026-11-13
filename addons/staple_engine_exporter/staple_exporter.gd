@tool
extends EditorPlugin

var entity_counter = 0
var exported_materials = PackedStringArray()

func _enter_tree() -> void:
	add_tool_menu_item("Staple Engine: Export selected files", Callable(self, "export"))
	
func _exit_tree() -> void:
	
	remove_tool_menu_item("Staple Engine: Export selected files")

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

func normalize_resource_path(path: String) -> String:
	if path.begins_with("res://"):
		path = path.substr("res://".length())
	if path.begins_with("user://"):
		path = path.substr("user://".length())
		
	var splitterIndex = path.find("::")
	
	if splitterIndex >= 0:
		path = path.substr(0, splitterIndex)
		
	return path

func normalize_material_extension(path: String) -> String:
	return normalize_resource_path(path).replace(".tres", ".material")

func match_assets_path(path: String) -> String:
	return "Assets/%s" % [path]

func encode_color(color: Color) -> String:
	return "#%s" % [color.to_html().to_upper()]

func export_material(material: BaseMaterial3D) -> String:
	var material_name = normalize_material_extension(material.resource_path)

	if exported_materials.find(material_name) >= 0:
		return material_name
		
	var culling_mode = "Back"
	var albedo_texture = "WHITE"
	
	match material.cull_mode:
		BaseMaterial3D.CULL_FRONT:
			culling_mode = "Front"
		BaseMaterial3D.CULL_DISABLED:
			culling_mode = "None"
	
	if material.albedo_texture != null:
		albedo_texture = match_assets_path(normalize_resource_path(material.albedo_texture.resource_path))
	
	var material_data = {
		"shader": "1ca9a72c-161e-44db-ad76-bf0ae432f78b",
		"cullingMode": culling_mode,
		"parameters": {
			"diffuseColor": {
				"type": "Color",
				"colorValue": {
					"r": clamp(material.albedo_color.r * 255, 0, 255),
					"g": clamp(material.albedo_color.g * 255, 0, 255),
					"b": clamp(material.albedo_color.b * 255, 0, 255),
					"a": clamp(material.albedo_color.a * 255, 0, 255),
				}
			},
			"diffuseTexture": {
				"type": "Texture",
				"textureValue": albedo_texture,
			},
			"alphaThreshold": {
				"type": "Float",
				"floatValue": material.alpha_scissor_threshold,
			}
		}
	}
	
	var data = JSON.stringify(material_data, "\t", false)
	
	var out_file = FileAccess.open(material_name, FileAccess.WRITE)
	
	if out_file:
		out_file.store_string(data)
		out_file.close()
		
		print("Saved %s!" % [material_name])
		
		exported_materials.append(material_name)
	
	return material_name

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
		"CharacterBody3D":
			var character: CharacterBody3D = node
			
			var gravity_factor = 1.0
			
			match character.motion_mode:
				CharacterBody3D.MOTION_MODE_GROUNDED:
					gravity_factor = 1.0
				CharacterBody3D.MOTION_MODE_FLOATING:
					gravity_factor = 0.0
			
			component_type = "Staple.Character3D"

			component_data = {
				"gravityFactor": gravity_factor,
				"maxSlopeAngle": character.floor_max_angle,
				
				"upDirection": {
					"x": character.up_direction.x,
					"y": character.up_direction.y,
					"z": character.up_direction.z,
				},
			}
		"DirectionalLight3D":
			var light: DirectionalLight3D = node
			
			component_type = "Staple.Light"

			component_data = {
				"type": "Directional",
				"color": encode_color(light.light_color.to_html()),
				"intensity": light.light_energy
			}
		"MeshInstance3D":
			var mesh_instance: MeshInstance3D = node
			
			component_type = "Staple.MeshRenderer"
			
			var surface_count = 0
			var materials = []
			var mesh_name = null
			
			if mesh_instance.mesh != null:
				mesh_name = match_assets_path(normalize_resource_path(mesh_instance.mesh.resource_path))
				surface_count = mesh_instance.mesh.get_surface_count()
			
			if surface_count > 0:
				for i in surface_count:
					var surface_arrays = mesh_instance.mesh.surface_get_arrays(i)
					
					if surface_arrays.size() >= ArrayMesh.ARRAY_BONES and surface_arrays[ArrayMesh.ARRAY_BONES] != null:
						component_type = "Staple.SkinnedMeshRenderer"
					
					var material: BaseMaterial3D = mesh_instance.mesh.surface_get_material(i)
					
					if material == null:
						materials.append("")
					else:
						var material_path = export_material(material)
						
						materials.append(match_assets_path(material_path))
			
			component_data = {

				"mesh": mesh_name,
				"materials": materials,
			}
			
		"OmniLight3D":
			var light: OmniLight3D = node

			component_type = "Staple.Light"
			
			component_data = {
				"type": "Point",
				"color": encode_color(light.light_color.to_html()),
				"intensity": light.light_energy,
				"range": light.omni_range
			}
		"RigidBody3D":
			var rigid_body: RigidBody3D = node
			
			var motion_type = "Dynamic"
			
			if rigid_body.freeze:
				match rigid_body.freeze_mode:
					RigidBody3D.FREEZE_MODE_STATIC:
						motion_type = "Static"
					RigidBody3D.FREEZE_MODE_KINEMATIC:
						motion_type = "Kinematic"
			
			component_type = "Staple.RigidBody3D"
			
			component_data = {
				"motionType": motion_type,
				"freezeRotationX": rigid_body.axis_lock_angular_x or rigid_body.lock_rotation,
				"freezeRotationY": rigid_body.axis_lock_angular_y or rigid_body.lock_rotation,
				"freezeRotationZ": rigid_body.axis_lock_angular_z or rigid_body.lock_rotation,
				"is2DPlane": rigid_body.axis_lock_linear_z,
				"gravityFactor": rigid_body.gravity_scale,
				"mass": rigid_body.mass,
			}
		"StaticBody3D":
			var static_body: StaticBody3D = node
			
			component_type = "Staple.RigidBody3D"
			
			component_data = {
				"motionType": "Static",
				"freezeRotationX": static_body.axis_lock_angular_x or static_body.lock_rotation,
				"freezeRotationY": static_body.axis_lock_angular_y or static_body.lock_rotation,
				"freezeRotationZ": static_body.axis_lock_angular_z or static_body.lock_rotation,
				"is2DPlane": static_body.axis_lock_linear_z,
				"mass": static_body.mass,
			}
		"SpotLight3D":
			var light: SpotLight3D = node

			component_type = "Staple.Light"
			
			component_data = {
				"type": "Spot",
				"color": encode_color(light.light_color.to_html()),
				"intensity": light.light_energy,
				"range": light.spot_range
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
							
							component_data[property.name] = encode_color(v.to_html())
						
			
	
	if component_type.length() != 0:
		components.append(
			{
				"type": component_type,
				"data": component_data,
			}
		)
	
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
	
	if exported_materials == null:
		exported_materials = PackedStringArray()
		
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
