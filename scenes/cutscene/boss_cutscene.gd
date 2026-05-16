## boss_cutscene.gd
## Lightweight, no-skip single-video cutscene used for the boss encounter
## and the post-boss ending. Designed to be instantiated as a child of
## run.tscn's CurrentView container so the run state (top bar, music,
## save data) stays alive in the background.
##
## Usage from run.gd:
##     var cs := BOSS_CUTSCENE_SCENE.instantiate() as BossCutscene
##     cs.video_path = "res://art/video/Cutscenes/Boss Encounter Scene_beforeBattle.ogv"
##     cs.finished.connect(_on_my_callback)
##     current_view.add_child(cs)
##
## Music from MusicPlayer is intentionally NOT paused — the video's own
## audio track plays on top of the existing music bed.

class_name BossCutscene
extends Control

signal finished

## Full res:// path to the .ogv video to play. Set this BEFORE adding the
## node to the tree, otherwise nothing will play.
var video_path: String = ""

@onready var video_stream_player: VideoStreamPlayer = %VideoStreamPlayer

var _has_finished: bool = false


func _ready() -> void:
	# Fill the parent rect — CurrentView is a full-screen Control in run.tscn.
	anchor_right  = 1.0
	anchor_bottom = 1.0
	
	if not video_stream_player:
		push_error("BossCutscene: VideoStreamPlayer node missing.")
		_finish()
		return
	
	video_stream_player.finished.connect(_on_video_finished)
	
	if video_path == "":
		push_error("BossCutscene: video_path was not set.")
		_finish()
		return
	
	if not ResourceLoader.exists(video_path):
		push_error("BossCutscene: Video not found at %s" % video_path)
		_finish()
		return
	
	var stream := ResourceLoader.load(video_path) as VideoStream
	if not stream:
		push_error("BossCutscene: Failed to load VideoStream from %s" % video_path)
		_finish()
		return
	
	video_stream_player.stream = stream
	video_stream_player.play()


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if _has_finished:
		return
	_has_finished = true
	finished.emit()
	queue_free()
