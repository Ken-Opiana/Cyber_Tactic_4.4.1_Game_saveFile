## battle_3d_background.gd
## Renders a 3D .glb model as a static background inside a 2D battle scene
## using a SubViewport.
##
## NOTE: This script does NOT create a Camera3D automatically. Add a Camera3D
## as a child of the SubViewport in the editor and position it manually for
## the default GLB. For runtime GLB swaps (e.g. boss battle), pass an optional
## camera transform to set_glb() so each background can have its own framing.

class_name Battle3DBackground
extends SubViewport

## The .glb (or any PackedScene) to display as the 3D background.
## Set this in the editor for the default background.
@export var glb_scene: PackedScene:
	set(value):
		glb_scene = value
		if is_node_ready():
			_rebuild()

## Directional light energy. Increase if the model looks too dark.
@export_range(0.0, 8.0, 0.1) var light_energy: float = 1.4:
	set(value):
		light_energy = value
		if _light:
			_light.light_energy = value

## Ambient sky/environment brightness (fakes global illumination).
@export_range(0.0, 2.0, 0.05) var ambient_energy: float = 0.5:
	set(value):
		ambient_energy = value
		if _env and _env.environment:
			_env.environment.ambient_light_energy = value

## Background clear color shown behind the model.
@export var clear_color: Color = Color(0.05, 0.05, 0.08, 1.0):
	set(value):
		clear_color = value
		if _env and _env.environment:
			_env.environment.background_color = value

var _light: DirectionalLight3D
var _env: WorldEnvironment
var _model_root: Node3D
var _user_camera: Camera3D


func _ready() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	transparent_bg = false
	own_world_3d = true
	# Note: don't overwrite world_3d here — Godot creates one automatically when
	# own_world_3d = true, and overwriting can drop nodes already added in the editor.
	
	# Find the user's Camera3D (added in the editor) and any pre-existing GLB.
	_find_existing_nodes()
	
	_setup_environment()
	_setup_light()
	_rebuild()


## Walks the immediate children to find a Camera3D and any pre-instanced GLB.
func _find_existing_nodes() -> void:
	for child in get_children():
		if child is Camera3D and _user_camera == null:
			_user_camera = child
		# If the user already instanced the GLB as a child in the editor,
		# treat it as our model_root so _rebuild() can replace it cleanly.
		elif child is Node3D and not (child is DirectionalLight3D) and not (child is WorldEnvironment):
			if _model_root == null:
				_model_root = child


func _setup_environment() -> void:
	# Don't add a second WorldEnvironment if one already exists.
	for child in get_children():
		if child is WorldEnvironment:
			_env = child
			return
	
	_env = WorldEnvironment.new()
	_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = clear_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.7, 0.9, 1.0)
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.environment = env
	add_child(_env)


func _setup_light() -> void:
	# Don't add a second light if one already exists.
	for child in get_children():
		if child is DirectionalLight3D:
			_light = child
			return
	
	_light = DirectionalLight3D.new()
	_light.name = "DirectionalLight3D"
	_light.position = Vector3(0, 5, 5)
	_light.rotation_degrees = Vector3(-45, -30, 0)
	_light.light_energy = light_energy
	_light.shadow_enabled = false
	add_child(_light)


func _rebuild() -> void:
	# Remove the previous model (whether created by us or pre-instanced in the editor).
	if _model_root and is_instance_valid(_model_root):
		_model_root.queue_free()
		_model_root = null
	
	if glb_scene:
		var instance := glb_scene.instantiate()
		if instance is Node3D:
			_model_root = instance
			add_child(_model_root)
		else:
			push_warning("Battle3DBackground: glb_scene root is not a Node3D, ignoring.")
			instance.queue_free()


## Public API: swap the GLB at runtime.
## Optionally pass a camera_transform to reframe the camera for the new model
## (different GLBs have different scales and origins, so reusing the same
## camera position usually doesn't work).
func set_glb(new_scene: PackedScene, camera_transform: Variant = null) -> void:
	glb_scene = new_scene
	if is_node_ready():
		_rebuild()
	
	if camera_transform != null and _user_camera and is_instance_valid(_user_camera):
		if camera_transform is Transform3D:
			_user_camera.transform = camera_transform
		else:
			push_warning("Battle3DBackground.set_glb: camera_transform must be Transform3D, got %s" % typeof(camera_transform))
