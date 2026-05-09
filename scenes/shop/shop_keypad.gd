class_name ShopKeypad
extends Control

# Emitted when the player presses Enter/OK with a valid-length code typed.
signal code_entered(code: String)
# Emitted when Clear is pressed.
signal code_cleared()

const MAX_CODE_LENGTH := 4

# ── SFX Export Variables ───────────────────────────────────────────────────────
# Assign these in the Godot Inspector on the Keypad node inside shop_ui2.tscn.
@export var sfx_button_press: AudioStream   ## Played on every keypad button press (A-D, 0-9, CLR).
@export var sfx_purchase_fail: AudioStream  ## Played on invalid code, sold out, or insufficient funds.
@export var sfx_purchase_success: AudioStream ## Played on successful purchase (dispensing).

var _current_input: String = ""

@onready var display_label: Label = %DisplayLabel
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_update_display("")


# ── Called by each button in the scene ────────────────────────────────────────

func press_char(ch: String) -> void:
	if _current_input.length() >= MAX_CODE_LENGTH:
		return
	_current_input += ch.to_upper()
	_update_display(_current_input)
	_play(sfx_button_press)


func press_clear() -> void:
	_current_input = ""
	_update_display("")
	_play(sfx_button_press)
	code_cleared.emit()


func press_enter() -> void:
	if _current_input.length() == 0:
		show_message("ENTER CODE")
		_play(sfx_button_press)
		return
	code_entered.emit(_current_input)


func clear_input() -> void:
	_current_input = ""
	_update_display("")


# ── SFX helpers (called by ShopUI2 after resolving a purchase) ─────────────────

func play_fail_sfx() -> void:
	_play(sfx_purchase_fail)


func play_success_sfx() -> void:
	_play(sfx_purchase_success)


# ── Display helpers ────────────────────────────────────────────────────────────

func show_message(msg: String, duration: float = 1.8) -> void:
	display_label.text = msg
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		_update_display(_current_input)


func _update_display(text: String) -> void:
	if not display_label:
		return
	if text.is_empty():
		display_label.text = "_ _ _ _"
	else:
		display_label.text = " ".join(text.split(""))


# ── Internal audio player ──────────────────────────────────────────────────────

func _play(stream: AudioStream) -> void:
	if stream and _audio:
		_audio.stream = stream
		_audio.play()
