extends Control

const MAIN_MENU_PATH = "res://scenes/ui/main_menu.tscn"
const INTRO_SCENE    = preload("res://cutscene.tscn")
const RUN_SCENE      = preload("res://scenes/run/run.tscn")

const WARRIOR_STATS  := preload("res://characters/warrior/warrior.tres")
const WIZARD_STATS   := preload("res://characters/wizard/wizard.tres")
const ASSASSIN_STATS := preload("res://characters/assassin/assassin.tres")

# Visual states for the small selector icons.
const LOCKED_MODULATE   := Color(0.35, 0.35, 0.35, 1.0)
const UNLOCKED_MODULATE := Color(1, 1, 1, 1)

@export var run_startup: RunStartup

# All characters in display order. This must match CHARACTER_UNLOCK_ORDER
# in meta_progression.gd by character_name.
var _characters: Array[CharacterStats] = []

# Index of the character currently being previewed.
var _current_index: int = 0

@onready var pause_menu: PauseMenu = $PauseMenu

@onready var char_name_label: Label   = %CharacterName
@onready var char_desc_label: Label   = %CharacterDescription
@onready var char_portrait: TextureRect = %CharacterPortrait
@onready var lock_label: Label        = %LockLabel
@onready var new_badge: Label         = %NewBadge

@onready var prev_button: Button      = %PrevButton
@onready var next_button: Button      = %NextButton
@onready var start_run_button: Button = %StartRunButton
@onready var main_menu_button: Button = %MainMenuButton

# Optional small icon strip across the bottom showing all character slots.
@onready var icon_strip: HBoxContainer = %IconStrip


func _ready() -> void:
	# Wire pause menu
	pause_menu.save_and_quit.connect(_save_and_return_to_menu)

	# Hub music
	MusicPlayer.play_track(MusicManager.Track.RESULT)

	# Keep Continue working from main menu
	_ensure_hub_save()

	# Build the character list (display order = unlock order in meta).
	_characters = [WARRIOR_STATS, WIZARD_STATS, ASSASSIN_STATS]

	# Build the small icon strip dynamically so the visual matches the data.
	_build_icon_strip()

	# Start on the first unlocked character so the hub never opens on a locked slot.
	_current_index = _find_first_unlocked_index()
	_refresh_view()


# ---------- SAVE/EXIT ----------

func _ensure_hub_save() -> void:
	var existing := SaveGame.load_data()
	if existing == null or not existing.was_in_hub:
		SaveGame.save_hub_state()


func _on_main_menu_button_pressed() -> void:
	SaveGame.save_hub_state()
	MusicPlayer.stop_music()
	StaticTransition.transition_to_file(MAIN_MENU_PATH)


func _save_and_return_to_menu() -> void:
	SaveGame.save_hub_state()
	MusicPlayer.stop_music()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


# ---------- BROWSING ----------

func _on_prev_button_pressed() -> void:
	_current_index = (_current_index - 1 + _characters.size()) % _characters.size()
	_refresh_view()


func _on_next_button_pressed() -> void:
	_current_index = (_current_index + 1) % _characters.size()
	_refresh_view()


func _find_first_unlocked_index() -> int:
	var meta := MetaProgression.load_meta()
	for i in _characters.size():
		if meta.is_character_unlocked(_characters[i].character_name):
			return i
	return 0


# ---------- VIEW REFRESH ----------

func _refresh_view() -> void:
	var meta := MetaProgression.load_meta()
	var char := _characters[_current_index]
	var unlocked := meta.is_character_unlocked(char.character_name)

	# Portrait
	char_portrait.texture = char.portrait
	char_portrait.modulate = UNLOCKED_MODULATE if unlocked else LOCKED_MODULATE

	# Name + description
	if unlocked:
		char_name_label.text = char.character_name
		char_desc_label.text = char.description
		lock_label.visible = false
	else:
		char_name_label.text = "???"
		char_desc_label.text = "Beat a run with the previous character to unlock."
		lock_label.visible = true

	# "NEW!" badge — shown the first time the player sees this character
	# highlighted after it unlocks. Clears as soon as it's been viewed.
	if unlocked and meta.is_character_newly_unlocked(char.character_name):
		new_badge.visible = true
		meta.acknowledge_new_unlock(char.character_name)
	else:
		new_badge.visible = false

	# Start button only works on unlocked characters.
	start_run_button.disabled = not unlocked

	# Refresh the icon strip highlight + lock state.
	_refresh_icon_strip(meta)


# ---------- ICON STRIP (small thumbnails at the bottom) ----------

func _build_icon_strip() -> void:
	# Clear any leftover children from the .tscn placeholder (if any).
	for child in icon_strip.get_children():
		child.queue_free()

	for i in _characters.size():
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.texture_normal = _characters[i].portrait
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.pressed.connect(_on_icon_strip_pressed.bind(i))
		icon_strip.add_child(btn)


func _refresh_icon_strip(meta: MetaProgression) -> void:
	for i in icon_strip.get_child_count():
		var btn := icon_strip.get_child(i) as TextureButton
		if btn == null:
			continue
		var char := _characters[i]
		var unlocked := meta.is_character_unlocked(char.character_name)
		# Tint: locked = dark grey, unlocked = full color.
		# The currently-selected one is slightly brightened.
		if not unlocked:
			btn.modulate = LOCKED_MODULATE
		elif i == _current_index:
			btn.modulate = Color(1.2, 1.2, 1.2, 1)
		else:
			btn.modulate = UNLOCKED_MODULATE
		btn.tooltip_text = char.character_name if unlocked else "Locked"


func _on_icon_strip_pressed(index: int) -> void:
	_current_index = index
	_refresh_view()


# ---------- START RUN ----------

func _on_start_run_button_pressed() -> void:
	var meta := MetaProgression.load_meta()
	var char := _characters[_current_index]
	if not meta.is_character_unlocked(char.character_name):
		return

	MusicPlayer.stop_music()

	# Clear discovered cards for new run (matches play_selector behavior).
	CardLibrary.discovered_cards.clear()

	# Set up the run.
	run_startup.type = RunStartup.Type.NEW_RUN
	run_startup.picked_character = char

	# Mark run as started + clear any old hub save so Continue resumes the run
	# rather than dumping the player back here.
	meta.increment_runs_started()
	SaveGame.delete_data()

	# First-time intro behavior, mirrored from play_selector.gd.
	if not meta.has_seen_intro:
		meta.mark_intro_seen()
		var intro_screen = INTRO_SCENE.instantiate()
		get_tree().root.add_child(intro_screen)
		get_tree().current_scene.queue_free()
	else:
		get_tree().change_scene_to_packed(RUN_SCENE)
