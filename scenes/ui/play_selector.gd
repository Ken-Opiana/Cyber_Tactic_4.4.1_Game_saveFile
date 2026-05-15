extends Control

const MAIN_MENU_PATH = "res://scenes/ui/main_menu.tscn"
const INTRO_SCENE = preload("res://cutscene.tscn")
const RUN_SCENE = preload("res://scenes/run/run.tscn")
const ASSASSIN_STATS := preload("res://characters/assassin/assassin.tres")
const WARRIOR_STATS := preload("res://characters/warrior/warrior.tres")
const WIZARD_STATS := preload("res://characters/wizard/wizard.tres")

# Color applied to locked-character buttons so they read as disabled
# even though we keep them in toggle_mode for the ButtonGroup.
const LOCKED_MODULATE := Color(0.35, 0.35, 0.35, 1.0)
const UNLOCKED_MODULATE := Color(1, 1, 1, 1)

@export var run_startup: RunStartup

@onready var title: Label = %Title
@onready var description: Label = %Description
@onready var character_portrait: TextureRect = %CharacterPotrait
@onready var back_button: Button = %BackButton
@onready var start_button: Button = $StartButton

# We grab these by node path because they don't have unique_name_in_owner set
# in the current scene. If you toggle unique_name_in_owner on them in the editor,
# you can switch to %StudentButton / %WizardButton2 / %AssassinButton3 instead.
@onready var student_button: Button   = $PlayerButtons/StudentButton
@onready var wizard_button: Button    = $PlayerButtons/WizardButton2
@onready var assassin_button: Button  = $PlayerButtons/AssassinButton3

var current_character: CharacterStats : set = set_current_character
var _meta: MetaProgression


func _ready() -> void:
	_meta = MetaProgression.load_meta()
	_refresh_button_locks()
	
	# Always start the selector on the first unlocked character so we don't
	# accidentally display a locked one as the default selection.
	var default_char := _get_first_unlocked_character()
	set_current_character(default_char)
	
	# Sync the toggle state to match the default character.
	_sync_toggle_to_character(default_char)


# ===== UI WIRING =====

func _refresh_button_locks() -> void:
	_apply_lock_state(student_button, WARRIOR_STATS)
	_apply_lock_state(wizard_button, WIZARD_STATS)
	_apply_lock_state(assassin_button, ASSASSIN_STATS)


func _apply_lock_state(button: Button, stats: CharacterStats) -> void:
	var unlocked := _meta.is_character_unlocked(stats.character_name)
	# We DON'T set button.disabled = true, because Godot's ButtonGroup
	# will skip disabled toggle buttons and that can break the visual layout.
	# Instead we visually grey them out and reject the press in code.
	button.modulate = UNLOCKED_MODULATE if unlocked else LOCKED_MODULATE
	
	# Tooltip explains the unlock condition.
	if unlocked:
		button.tooltip_text = stats.character_name
	else:
		button.tooltip_text = "%s - Locked\nBeat a run with the previous character to unlock." % stats.character_name


func _sync_toggle_to_character(character: CharacterStats) -> void:
	# Force the right toggle button to be pressed without retriggering
	# the _on_*_pressed handlers in a way that overwrites our setup.
	match character:
		WARRIOR_STATS:
			student_button.button_pressed = true
		WIZARD_STATS:
			wizard_button.button_pressed = true
		ASSASSIN_STATS:
			assassin_button.button_pressed = true


func _get_first_unlocked_character() -> CharacterStats:
	if _meta.is_character_unlocked(WARRIOR_STATS.character_name):
		return WARRIOR_STATS
	if _meta.is_character_unlocked(WIZARD_STATS.character_name):
		return WIZARD_STATS
	if _meta.is_character_unlocked(ASSASSIN_STATS.character_name):
		return ASSASSIN_STATS
	# Fallback: Warrior is supposed to be unlocked from the start.
	return WARRIOR_STATS


# ===== DISPLAY =====

func set_current_character(new_character: CharacterStats) -> void:
	current_character = new_character
	
	var unlocked := _meta != null and _meta.is_character_unlocked(new_character.character_name)
	
	if unlocked:
		title.text = new_character.character_name
		description.text = new_character.description
		# Clear the "NEW!" badge as soon as the player has seen this character
		# highlighted on the selector.
		if _meta.is_character_newly_unlocked(new_character.character_name):
			_meta.acknowledge_new_unlock(new_character.character_name)
	else:
		title.text = "??? (Locked)"
		description.text = "Beat a run with the previous character to unlock %s." % new_character.character_name
	
	character_portrait.texture = new_character.portrait
	character_portrait.modulate = UNLOCKED_MODULATE if unlocked else LOCKED_MODULATE
	
	# Disable the Start button when a locked character is highlighted.
	if start_button:
		start_button.disabled = not unlocked


# ===== BUTTON HANDLERS =====

func _on_start_button_pressed() -> void:
	# Guard: never let a locked character actually start a run.
	if not _meta.is_character_unlocked(current_character.character_name):
		return
	
	MusicPlayer.stop_music()
	# Clear discovered cards for new run
	CardLibrary.discovered_cards.clear()

	print("Start new Run with %s" % current_character.character_name)

	# Set up run startup
	run_startup.type = RunStartup.Type.NEW_RUN
	run_startup.picked_character = current_character

	# Load meta progression
	var meta = MetaProgression.load_meta()
	meta.increment_runs_started()

	# Check if this is the first time playing
	if not meta.has_seen_intro:
		# First time - show intro and mark as seen
		meta.mark_intro_seen()
		
		# Load and show intro scene
		var intro_screen = INTRO_SCENE.instantiate()
		get_tree().root.add_child(intro_screen)
		get_tree().current_scene.queue_free()
	else:
		# Not first time - go directly to run
		get_tree().change_scene_to_packed(RUN_SCENE)


func _on_student_button_pressed() -> void:
	set_current_character(WARRIOR_STATS)


func _on_wizard_button_2_pressed() -> void:
	set_current_character(WIZARD_STATS)


func _on_assassin_button_3_pressed() -> void:
	set_current_character(ASSASSIN_STATS)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
