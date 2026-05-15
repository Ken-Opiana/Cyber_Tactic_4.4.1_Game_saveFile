class_name DialogueUI
extends Control

signal dialogue_finished()

# Expose node paths so you can set them in the inspector if your tree differs
@export var transparent_block_path: NodePath = NodePath("TransparentBlock")
@export var black_block_path: NodePath = NodePath("BlackBlock")
@export var panel_path: NodePath = NodePath("Panel")
@export var speaker_icon_path: NodePath = NodePath("Panel/HBoxContainer/Icon")  # TextureRect for small portrait
@export var name_label_path: NodePath = NodePath("Panel/HBoxContainer/VBoxContainer/NameLabel")
@export var dialogue_label_path: NodePath = NodePath("Panel/HBoxContainer/VBoxContainer/DialogueLabel")
@export var image_panel_path: NodePath = NodePath("ImagePanel") # TextureRect for tutorial image
@export var next_button_path: NodePath = NodePath("NextButton")
@export var skip_button_path: NodePath = NodePath("SkipButton")

@export_range(0.001, 0.2, 0.001) var char_delay: float = 0.02

# Typed onready nodes
@onready var transparent_block: ColorRect = get_node(transparent_block_path) as ColorRect
@onready var black_block: ColorRect = get_node(black_block_path) as ColorRect
@onready var panel: Control = get_node(panel_path) as Control
@onready var speaker_icon: TextureRect = get_node(speaker_icon_path) as TextureRect
@onready var name_label: Label = get_node(name_label_path) as Label
@onready var dialogue_label: RichTextLabel = get_node(dialogue_label_path) as RichTextLabel
@onready var image_panel: TextureRect = get_node(image_panel_path) as TextureRect
@onready var next_button: Button = get_node(next_button_path) as Button
@onready var skip_button: Button = get_node(skip_button_path) as Button

@onready var default_portrait: Texture2D = preload("res://art/question_mark.png")
var _debug_log_path: String = "user://dialogue_debug.log"
@onready var default_tutorial_image: Texture2D = preload("res://art/question_mark.png")

@onready var model_viewport_container: SubViewportContainer = get_node_or_null("ModelViewportContainer") as SubViewportContainer
var model_viewport: Viewport = null
var model_root: Node3D = null
var _current_model_instance: Node = null
var _previous_viewport_camera: Camera3D = null

var _lines: Array = []
var _index: int = 0
var _full_bbcode_text: String = ""
var _typing: bool = false

# ---------------- Typewriter / SFX config ----------------
# Speech SFX: plays every sfx_interval visible characters (skips whitespace)
@export var speech_sfx: AudioStream = null
@export_range(1, 10) var sfx_interval: int = 2
@export_range(0.0, 0.5, 0.01) var sfx_random_pitch: float = 0.06
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = -6.0
@export var enable_speech_sfx: bool = true
var _sfx_player: AudioStreamPlayer = null

func _ready() -> void:
	# Hide/show the entire DialogueUI root instead of individual children.
	# Set this Control invisible initially.
	visible = false

	# register UI so DialogueManager can find it
	if DialogueManager:
		DialogueManager.register_ui(self)
	
	_bind_model_nodes()

	# connect buttons (if found)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

func show_block_immediately() -> void:
	# Show the whole UI root (so BlackBlock is visible)
	visible = true
	_clear_current_model()
	# Make sure TransparentBlock is visible immediately
	if transparent_block:
		transparent_block.visible = true
	
	if black_block:
		black_block.visible = false
	# Hide the actual dialogue panel and other visual elements until reveal
	if panel:
		panel.visible = false
	# Clear any existing textures/text so nothing flashes
	if image_panel:
		image_panel.visible = false
	
	if next_button:
		next_button.visible = false
	if skip_button:
		skip_button.visible = true

func show_dialogue(dialogue_data: Dictionary) -> void:
	_lines = dialogue_data.get("lines", [])
	_index = 0
	if _lines.size() == 0:
		_emit_finished()
		return
	
	if panel:
		panel.visible = true
	# Clear any existing textures/text so nothing flashes
	if black_block:
		black_block.visible = true
	if image_panel:
		image_panel.visible = true
	
	if next_button:
		next_button.visible = true

	# Show entire UI (root Control). This hides/show everything at once.
	visible = true
	_show_current_line()

func _show_current_line() -> void:
	if _index < 0 or _index >= _lines.size():
		_emit_finished()
		return

	var line: Dictionary = _lines[_index] as Dictionary

	# 1) Speaker name
	if name_label:
		name_label.text = str(line.get("speaker", ""))
	
	# Portrait is shown if portrait key/path present (always set portrait first)
	var portrait_key_or_path: String = str(line.get("portrait", ""))
	_set_portrait_from_key_or_path(portrait_key_or_path)

	# 2) Model or portrait selection
	var model_key_or_path: String = str(line.get("model", ""))
	var anim_name: String = str(line.get("anim", "Idle"))

	if model_key_or_path != "":
		# Attempt to show model; function will hide model viewport if not found
		_show_model_if_available(model_key_or_path, anim_name)
	else:
		# No model requested: ensure model removed/hidden
		_clear_current_model()
		if model_viewport_container:
			model_viewport_container.visible = false
	
	# 3) Tutorial image (large image panel) - use the helper
	var image_key_or_path: String = str(line.get("image", ""))
	_set_image_from_key_or_path(image_key_or_path)

	# text typewriter
	_full_bbcode_text = str(line.get("text", ""))
	_start_typing_bbcode(_full_bbcode_text)

func _start_typing_bbcode(full_bbcode_text: String) -> void:
	if dialogue_label == null:
		return

	# ensure BBCode mode
	dialogue_label.bbcode_enabled = true
	# set the bbcode text once so layout is stable
	dialogue_label.bbcode_text = full_bbcode_text
	dialogue_label.visible_characters = 0
	_typing = true

	# get plain text by stripping tags (so we can test for whitespace)
	var plain_text: String = _strip_bbcode(full_bbcode_text)
	var total_chars: int = plain_text.length()
	if total_chars <= 0:
		_typing = false
		return

	# ensure SFX available if needed
	if enable_speech_sfx and speech_sfx and _sfx_player == null:
		_ensure_sfx_player()

	# show characters one by one using visible_characters (indices 1..total_chars)
	for i in range(1, total_chars + 1):
		if not _typing:
			break
		dialogue_label.visible_characters = i

		# play speech blip every sfx_interval visible characters, skipping whitespace
		if enable_speech_sfx and speech_sfx and sfx_interval > 0 and (i % sfx_interval) == 0:
			# plain_text index is i-1
			if i - 1 < plain_text.length():
				var ch: String = plain_text[i - 1]
				if ch != " " and ch != "\n" and ch != "\t":
					_play_speech_sfx()

		await get_tree().create_timer(char_delay).timeout

	# finalize
	dialogue_label.visible_characters = total_chars
	_typing = false
	# stop any lingering sfx (stop autoload SFXPlayer too)
	if typeof(SFXPlayer) != TYPE_NIL and SFXPlayer and SFXPlayer.has_method("stop"):
		SFXPlayer.stop()
	if _sfx_player:
		_sfx_player.stop()

func _typewriter_bbcode() -> void:
	if dialogue_label == null:
		_typing = false
		return

	# number of visible (rendered) characters (BBCode tags excluded)
	var total_chars: int = dialogue_label.get_total_character_count()
	# if there are no visible characters, just finish
	if total_chars <= 0:
		_typing = false
		return

	for i in range(1, total_chars + 1):
		# If typing was cancelled externally (by input), break and show everything
		if not _typing:
			break
		dialogue_label.visible_characters = i
		# yield a short delay between characters
		await get_tree().create_timer(char_delay).timeout

	# Make sure everything is visible at the end
	dialogue_label.visible_characters = total_chars
	_typing = false

func _on_next_pressed() -> void:
	# finish typing if still typing
	if _typing:
		_typing = false
		if dialogue_label:
			dialogue_label.visible_characters = dialogue_label.get_total_character_count()
		if _sfx_player:
			_sfx_player.stop()
		return

	# advance
	_index += 1
	if _index >= _lines.size():
		_emit_finished()
	else:
		_show_current_line()

func _on_skip_pressed() -> void:
	_emit_finished()

# Force hide the black blocker and allow input again
func force_hide_block() -> void:
	if black_block:
		black_block.visible = false
		black_block.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Ensure UI is fully hidden/unblocked and emit finished
func _emit_finished() -> void:
	visible = false
	force_hide_block()
	_write_debug("DialogueUI: finished dialogue emitted")
	emit_signal("dialogue_finished")
	if _sfx_player:
		_sfx_player.stop()


# --- portrait & image helpers ---
func _write_debug(msg: String) -> void:
	var path: String = _debug_log_path
	var ts_text: String = ""

	# Get OS singleton dynamically to avoid static method references
	if Engine.has_singleton("OS"):
		var os_singleton := Engine.get_singleton("OS")
		if os_singleton != null:
			# call guarded methods dynamically (call avoids static analyzer errors)
			if os_singleton.has_method("get_unix_time"):
				ts_text = str(os_singleton.call("get_unix_time"))
			elif os_singleton.has_method("get_unix_time_msec"):
				ts_text = str(os_singleton.call("get_unix_time_msec"))
			elif os_singleton.has_method("get_ticks_msec"):
				ts_text = str(os_singleton.call("get_ticks_msec"))

	# Final fallback: frames drawn (always available)
	if ts_text == "":
		ts_text = "frame:%s" % str(Engine.get_frames_drawn())

	var line: String = "[%s] %s\n" % [ts_text, msg]

	# Append to the user:// log file. Try WRITE_READ then WRITE.
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE_READ)
	if not f:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_string(line)
		f.close()
	else:
		# In editor you'll still see this if writing fails
		push_error("DialogueUI: Failed to open debug log '%s' — msg: %s" % [path, msg])


# Robust texture resolver used by both portrait and image panel
func _get_texture_from_registry_or_path(key_or_path: String) -> Texture2D:
	# empty -> null
	if key_or_path == null or key_or_path.strip_edges() == "":
		return null

	# 1) Try static class lookup (fast)
	if ClassDB.class_exists("PortraitRegistry"):
		# static call
		if PortraitRegistry.has_method("get_portrait"):
			var t := PortraitRegistry.get_portrait(key_or_path)
			if t and t is Texture2D:
				_write_debug("PortraitRegistry (static) hit: %s" % key_or_path)
				return t
		# also try tutorial image static method
		if PortraitRegistry.has_method("get_tutorial_image"):
			var tt := PortraitRegistry.get_tutorial_image(key_or_path)
			if tt and tt is Texture2D:
				_write_debug("PortraitRegistry (static tutorial) hit: %s" % key_or_path)
				return tt

	# 2) Try autoload instance (if user registered as autoload named PortraitRegistry)
	if typeof(PortraitRegistry) != TYPE_NIL and PortraitRegistry is Object:
		if PortraitRegistry.has_method("get_portrait_instance"):
			var t2 := PortraitRegistry.get_portrait_instance(key_or_path)
			if t2 and t2 is Texture2D:
				_write_debug("PortraitRegistry (autoload instance) hit: %s" % key_or_path)
				return t2
		# fallback to static-like instance method name
		if PortraitRegistry.has_method("get_portrait"):
			var t3 := PortraitRegistry.get_portrait(key_or_path)
			if t3 and t3 is Texture2D:
				_write_debug("PortraitRegistry (autoload get_portrait) hit: %s" % key_or_path)
				return t3

	# 3) Try direct resource path (res://...). This helps if you used a path in JSON
	if ResourceLoader.exists(key_or_path):
		var loaded := ResourceLoader.load(key_or_path)
		if loaded and loaded is Texture2D:
			_write_debug("ResourceLoader loaded texture from path: %s" % key_or_path)
			return loaded as Texture2D

	# Not found
	_write_debug("Texture MISS for key/path: %s" % key_or_path)
	return null


func _set_portrait_from_key_or_path(key_or_path: String) -> void:
	var tex: Texture2D = _get_texture_from_registry_or_path(key_or_path)
	if tex == null:
		# fallback to default portrait (preloaded earlier)
		tex = default_portrait if default_portrait != null else null
	if speaker_icon:
		speaker_icon.texture = tex


func _set_image_from_key_or_path(key_or_path: String) -> void:
	# clear previous
	if image_panel:
		image_panel.texture = null

	if key_or_path == "" or key_or_path == null:
		return

	# first try tutorial image registry (explicit)
	var tex: Texture2D = null
	# prefer static method (if exists)
	if ClassDB.class_exists("PortraitRegistry") and PortraitRegistry.has_method("get_tutorial_image"):
		var t_stat := PortraitRegistry.get_tutorial_image(key_or_path)
		if t_stat and t_stat is Texture2D:
			tex = t_stat as Texture2D

	# try autoload instance
	if tex == null and typeof(PortraitRegistry) != TYPE_NIL and PortraitRegistry is Object:
		if PortraitRegistry.has_method("get_tutorial_image_instance"):
			var t_inst := PortraitRegistry.get_tutorial_image_instance(key_or_path)
			if t_inst and t_inst is Texture2D:
				tex = t_inst as Texture2D

	# fallback to general resolver (covers both registry portrait and resource paths)
	if tex == null:
		tex = _get_texture_from_registry_or_path(key_or_path)

	if tex:
		if image_panel:
			image_panel.texture = tex
		_write_debug("ImagePanel set to: %s" % key_or_path)
	else:
		_write_debug("ImagePanel MISS for: %s" % key_or_path)


# --- model (3D) support ---
func _bind_model_nodes() -> void:
	if model_viewport_container:
		model_viewport = get_node_or_null("ModelViewportContainer/ModelViewport") as Viewport
		model_root = get_node_or_null("ModelViewportContainer/ModelViewport/ModelRoot") as Node3D
	if model_viewport == null:
		model_viewport = get_node_or_null("ModelViewport") as Viewport
	if model_root == null:
		model_root = get_node_or_null("ModelRoot") as Node3D

	if model_viewport_container and (model_viewport == null or model_root == null):
		model_viewport_container.visible = false


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _find_animation_player(c)
		if f:
			return f
	return null


func _find_camera3d(node: Node) -> Camera3D:
	if node == null:
		return null
	if node is Camera3D:
		return node as Camera3D
	for c in node.get_children():
		var f := _find_camera3d(c)
		if f:
			return f
	return null


func _capture_viewport_camera() -> void:
	_previous_viewport_camera = null
	if model_viewport == null:
		return
	_previous_viewport_camera = _find_camera3d(model_viewport)


func _restore_previous_viewport_camera() -> void:
	if _previous_viewport_camera and _previous_viewport_camera.is_inside_tree():
		if _previous_viewport_camera.has_method("make_current"):
			_previous_viewport_camera.make_current()
		else:
			if "current" in _previous_viewport_camera:
				_previous_viewport_camera.current = true
	_previous_viewport_camera = null


func _clear_current_model() -> void:
	# free the tracked instance
	if _current_model_instance:
		if _current_model_instance.is_inside_tree():
			_current_model_instance.queue_free()
		_current_model_instance = null

	# free all children of model_root (defensive cleanup)
	if model_root:
		for child in model_root.get_children():
			if child:
				child.queue_free()

	# restore camera and hide viewport
	_restore_previous_viewport_camera()
	if model_viewport_container:
		model_viewport_container.visible = false


func _show_model_if_available(key_or_path: String, anim_name: String = "Idle") -> void:
	_clear_current_model()
	_capture_viewport_camera()

	# resolve model via registry or path
	var model_scene: PackedScene = null
	if ClassDB.class_exists("ModelRegistry") and ModelRegistry.has_method("get_model"):
		var s := ModelRegistry.get_model(key_or_path)
		if s and s is PackedScene:
			model_scene = s as PackedScene
	if model_scene == null and typeof(ModelRegistry) != TYPE_NIL and ModelRegistry is Object and ModelRegistry.has_method("get_model"):
		var s2 := ModelRegistry.get_model(key_or_path)
		if s2 and s2 is PackedScene:
			model_scene = s2 as PackedScene
	if model_scene == null and key_or_path != "" and ResourceLoader.exists(key_or_path):
		var loaded := ResourceLoader.load(key_or_path)
		if loaded and loaded is PackedScene:
			model_scene = loaded as PackedScene

	if model_scene == null:
		_write_debug("DialogueUI: model miss for %s; keeping portrait only" % key_or_path)
		if model_viewport_container:
			model_viewport_container.visible = false
		_restore_previous_viewport_camera()
		return

	if model_viewport == null or model_root == null:
		_bind_model_nodes()
		if model_viewport == null or model_root == null:
			_write_debug("DialogueUI: viewport nodes missing; cannot show model")
			if model_viewport_container:
				model_viewport_container.visible = false
			_restore_previous_viewport_camera()
			return

	_current_model_instance = model_scene.instantiate()
	if _current_model_instance == null:
		_write_debug("DialogueUI: failed instantiate %s" % key_or_path)
		_restore_previous_viewport_camera()
		if model_viewport_container:
			model_viewport_container.visible = false
		return

	# add and reset transform
	if _current_model_instance is Node3D:
		var md := _current_model_instance as Node3D
		md.transform = Transform3D()
		model_root.add_child(md)
	else:
		model_root.add_child(_current_model_instance)

	if model_viewport_container:
		model_viewport_container.visible = true

	# prefer model camera if present
	var model_cam: Camera3D = _find_camera3d(_current_model_instance)
	if model_cam:
		if model_cam.has_method("make_current"):
			model_cam.make_current()
		else:
			if "current" in model_cam:
				model_cam.current = true

	# play animation if available
	var anim_player: AnimationPlayer = _find_animation_player(_current_model_instance)
	if anim_player:
		if anim_name != "" and anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
		elif anim_player.has_animation("Idle"):
			anim_player.play("Idle")
		else:
			var anims := anim_player.get_animation_list()
			if anims.size() > 0:
				anim_player.play(anims[0])

# ---------------- Speech SFX helpers ----------------
func _ensure_sfx_player() -> void:
	if _sfx_player != null:
		return
	_sfx_player = AudioStreamPlayer.new()
	# attach to this Control so it gets freed with UI; positioned audio not required
	add_child(_sfx_player)
	_sfx_player.stream = speech_sfx
	_sfx_player.volume_db = sfx_volume_db
	_sfx_player.autoplay = false
	# ensure it uses your main bus; change if you have a dedicated SFX bus
	_sfx_player.bus = "SFX"

func _play_speech_sfx() -> void:
	if not enable_speech_sfx or speech_sfx == null:
		return
	if _sfx_player == null:
		_ensure_sfx_player()
	# retrigger cleanly
	_sfx_player.stop()
	_sfx_player.pitch_scale = 1.0 + randf_range(-sfx_random_pitch, sfx_random_pitch)
	_sfx_player.play()

func _strip_bbcode(bb: String) -> String:
	if bb == null or bb == "":
		return ""
	var out := String()
	var in_tag := false
	for i in bb:
		# i is a one-character string
		if not in_tag:
			if i == "[":
				in_tag = true
				continue
			out += i
		else:
			# we are inside a tag; wait for closing bracket
			if i == "]":
				in_tag = false
			# else skip chars inside tag
	return out
