extends Control

# Video and dialogue configuration
var videos: Array = [
	"res://art/video/Cutscenes/CyberScene1.ogv",
	"res://art/video/Cutscenes/CyberScene2.ogv",
	"res://art/video/Cutscenes/CyberScene3.ogv"
]

# Define dialogue triggers: {video_index: [{time: seconds, dialogue: path}]}
var dialogue_triggers: Dictionary = {
	0: [  # Video 1: Cyber-tactic-game-cutscenes_1.ogv
		{"time": 3.5, "dialogue": "res://dialogues/Cutscene1_Part1.json"},
		{"time": 6.0, "dialogue": "res://dialogues/Cutscene1_Part2.json"},
		{"time": 8.5, "dialogue": "res://dialogues/Cutscene1_Part3.json"}
	],
	1: [  # Video 2: Cutscene2-cybertactics.ogv
		{"time": 5.0, "dialogue": "res://dialogues/Cutscene2_Part1.json"},
		{"time": 16.0, "dialogue": "res://dialogues/Cutscene2_Part2.json"}
	],
	2: [  # Video 3: encounter3-cybertactics_1.og
		{"time": 9.0, "dialogue": "res://dialogues/Cutscene3_Part1.json"},
		{"time": 20.0, "dialogue": "res://dialogues/Cutscene3_Part2.json"},
		{"time": 23.0, "dialogue": "res://dialogues/Cutscene3_Part3.json"}
	] 
}

@onready var video_stream_player: VideoStreamPlayer = %VideoStreamPlayer
@onready var dialogue_ui: DialogueUI = $DialogueLayer/DialogueUI

var current_video_index: int = 0
var is_dialogue_active: bool = false
var checked_triggers: Array = []  # Track which triggers we've already fired

# ── Hard skip state ──────────────────────────────────────────────────────
# Set to true the moment ESC is pressed so _process() stops firing dialogue
# triggers and _on_video_finished() stops queuing the next video while
# we're tearing things down.
var _is_skipping: bool = false


func _ready() -> void:
	DialogueState.reset_all()
	# Hide dialogue UI initially
	if dialogue_ui:
		dialogue_ui.visible = false
	
	# Connect video finished signal
	if video_stream_player:
		video_stream_player.finished.connect(_on_video_finished)
	
	# Connect dialogue finished signal
	if dialogue_ui:
		dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	
	# Start first video
	_load_and_play_video(0)


# ── ESC hard-skip ────────────────────────────────────────────────────────
# Single press of ESC (ui_cancel) skips the entire cutscene — bypasses any
# remaining videos AND any active or pending dialogue — and goes straight
# to the scene defined in _transition_to_run().
func _unhandled_input(event: InputEvent) -> void:
	if _is_skipping:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_skip_cutscene()


func _skip_cutscene() -> void:
	if _is_skipping:
		return
	_is_skipping = true
	
	# Stop the video so it doesn't keep ticking / firing finished mid-skip.
	if video_stream_player and video_stream_player.is_playing():
		video_stream_player.stop()
	
	# If a dialogue is currently up, tear it down without letting it run
	# its normal "finished -> maybe change scene" cascade. DialogueManager
	# is connected to dialogue_ui.dialogue_finished as CONNECT_ONE_SHOT, so
	# we disconnect it before we ourselves hide the UI to avoid firing the
	# manager's post-scene logic.
	if dialogue_ui:
		if DialogueManager and dialogue_ui.is_connected("dialogue_finished", Callable(DialogueManager, "_on_ui_finished")):
			dialogue_ui.disconnect("dialogue_finished", Callable(DialogueManager, "_on_ui_finished"))
		dialogue_ui.force_hide_block()
		dialogue_ui.visible = false
	
	is_dialogue_active = false
	
	# Instant cut to the next scene.
	_transition_to_run(true)


func _process(_delta: float) -> void:
	if _is_skipping:
		return
	if is_dialogue_active or not video_stream_player or not video_stream_player.is_playing():
		return
	
	# Check for dialogue triggers at current playback position
	_check_dialogue_triggers()


func _check_dialogue_triggers() -> void:
	var current_time: float = video_stream_player.stream_position
	
	# Get triggers for current video
	if not dialogue_triggers.has(current_video_index):
		return
	
	var triggers: Array = dialogue_triggers[current_video_index]
	
	for i in range(triggers.size()):
		var trigger: Dictionary = triggers[i]
		var trigger_time: float = trigger.get("time", 0.0)
		var trigger_key: String = "%d_%d" % [current_video_index, i]
		
		# Check if we've reached this trigger time and haven't fired it yet
		if current_time >= trigger_time and not checked_triggers.has(trigger_key):
			checked_triggers.append(trigger_key)
			_pause_and_show_dialogue(trigger.get("dialogue", ""))
			break  # Only trigger one dialogue at a time


func _pause_and_show_dialogue(dialogue_path: String) -> void:
	if dialogue_path == "" or not FileAccess.file_exists(dialogue_path):
		push_error("Cutscene: Dialogue file not found: %s" % dialogue_path)
		return
	
	# Pause video
	video_stream_player.paused = true
	is_dialogue_active = true
	
	# Show dialogue using DialogueManager
	if DialogueManager:
		DialogueManager.start_dialogue_from_file(dialogue_path, "", Callable(), 0.0)
	else:
		push_error("Cutscene: DialogueManager not found!")
		_resume_video()


func _on_dialogue_finished() -> void:
	if _is_skipping:
		return
	is_dialogue_active = false
	_resume_video()


func _resume_video() -> void:
	if video_stream_player:
		video_stream_player.paused = false


func _on_video_finished() -> void:
	if _is_skipping:
		return
	
	# Move to next video
	current_video_index += 1
	
	if current_video_index < videos.size():
		# Load next video
		_load_and_play_video(current_video_index)
	else:
		# All videos finished, transition to run scene
		_transition_to_run()


func _load_and_play_video(index: int) -> void:
	if index < 0 or index >= videos.size():
		push_error("Cutscene: Invalid video index: %d" % index)
		return
	
	var video_path: String = videos[index]
	
	if not ResourceLoader.exists(video_path):
		push_error("Cutscene: Video not found: %s" % video_path)
		_transition_to_run()  # Fallback to run scene
		return
	
	var video_stream: VideoStream = ResourceLoader.load(video_path) as VideoStream
	
	if video_stream:
		video_stream_player.stream = video_stream
		video_stream_player.play()
		print("Cutscene: Playing video %d: %s" % [index, video_path])
	else:
		push_error("Cutscene: Failed to load video: %s" % video_path)
		_transition_to_run()


# `instant` skips the normal 0.5s pause before the scene change.
# Used by the ESC hard skip so the transition feels like a hard cut.
func _transition_to_run(instant: bool = false) -> void:
	print("Cutscene: Transitioning to run scene")
	if not instant:
		await get_tree().create_timer(0.5).timeout
	
	# Change scene first
	var result = get_tree().change_scene_to_file("res://scenes/battle/battleSim.tscn")
	
	if result == OK:
		# Queue free this cutscene node after scene change
		queue_free()
	else:
		push_error("Cutscene: Failed to change scene (Error: %d)" % result)
