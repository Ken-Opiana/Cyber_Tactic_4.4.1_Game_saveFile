class_name TutorialManager
extends Node

signal tutorial_started
signal tutorial_completed
signal step_changed(step_index: int)

@export var steps: Array[TutorialStep] = []
@export var tutorial_key: String = ""  # Key for DialogueState
@export var overlay_scene: PackedScene = preload("res://scenes/tutorial/tutorial_overlay.tscn")
@export var narration_scene: PackedScene = preload("res://scenes/tutorial/tutorial_narration.tscn")

# Safety: if a player gets stuck on a PLAY_CARD_TYPE step with no matching
# card and no mana, force-advance after this many seconds.
@export var card_type_step_safety_timeout: float = 30.0

var current_step_index: int = -1
var is_active: bool = false
var overlay: TutorialOverlay
var narration: TutorialNarration
var battle_node: Node
var auto_advance_timer: Timer
var safety_timer: Timer

# Track which UI nodes we explicitly blocked this step so we can restore
# their original disabled state cleanly when the step advances.
var _blocked_buttons: Array[BaseButton] = []
var _hand_disabled_this_step: bool = false


func _ready() -> void:
	# Don't start automatically, wait for explicit start_tutorial() call
	pass


func start_tutorial() -> void:
	# Already completed?
	if tutorial_key != "" and DialogueState.has_shown(tutorial_key):
		print("Tutorial '%s' already completed, skipping..." % tutorial_key)
		queue_free()
		return

	print("Starting tutorial: '%s'" % tutorial_key)
	is_active = true
	battle_node = get_parent()

	overlay = overlay_scene.instantiate()
	battle_node.add_child(overlay)
	overlay.show_overlay()

	narration = narration_scene.instantiate()
	overlay.add_child(narration)

	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	auto_advance_timer.timeout.connect(_on_auto_advance_timeout)
	add_child(auto_advance_timer)

	safety_timer = Timer.new()
	safety_timer.one_shot = true
	safety_timer.timeout.connect(_on_safety_timeout)
	add_child(safety_timer)

	_connect_events()
	emit_signal("tutorial_started")

	await get_tree().create_timer(0.5).timeout
	_advance_to_next_step()


func _connect_events() -> void:
	Events.card_played.connect(_on_card_played)
	Events.player_press_end_turn_button.connect(_on_end_turn_pressed)
	Events.enemy_turn_ended.connect(_on_enemy_turn_ended)
	# CRITICAL: when new cards are drawn at start of turn, we may need to
	# re-apply the hand gating for the current step.
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	Events.player_card_drawn.connect(_on_player_card_drawn)
	# CardUI._on_card_drag_or_aim_ended resets `disabled = false` on every
	# card whenever any drag/aim ends. If we don't re-apply gating after
	# that, the tutorial's lock evaporates the moment the player jiggles
	# a card.
	Events.card_drag_ended.connect(_on_card_interaction_ended)
	Events.card_aim_ended.connect(_on_card_interaction_ended)


func _disconnect_events() -> void:
	if Events.card_played.is_connected(_on_card_played):
		Events.card_played.disconnect(_on_card_played)
	if Events.player_press_end_turn_button.is_connected(_on_end_turn_pressed):
		Events.player_press_end_turn_button.disconnect(_on_end_turn_pressed)
	if Events.enemy_turn_ended.is_connected(_on_enemy_turn_ended):
		Events.enemy_turn_ended.disconnect(_on_enemy_turn_ended)
	if Events.player_hand_drawn.is_connected(_on_player_hand_drawn):
		Events.player_hand_drawn.disconnect(_on_player_hand_drawn)
	if Events.player_card_drawn.is_connected(_on_player_card_drawn):
		Events.player_card_drawn.disconnect(_on_player_card_drawn)
	if Events.card_drag_ended.is_connected(_on_card_interaction_ended):
		Events.card_drag_ended.disconnect(_on_card_interaction_ended)
	if Events.card_aim_ended.is_connected(_on_card_interaction_ended):
		Events.card_aim_ended.disconnect(_on_card_interaction_ended)


func _advance_to_next_step() -> void:
	# Clean up the previous step's gating before applying the new one.
	_release_step_gating()

	current_step_index += 1

	if current_step_index >= steps.size():
		_complete_tutorial()
		return

	var step := steps[current_step_index]
	emit_signal("step_changed", current_step_index)
	_execute_step(step)


func _execute_step(step: TutorialStep) -> void:
	# Narration
	if step.narration_text != "":
		narration.show_narration(step.narration_text)

	# Hide any leftover drag arrow.
	overlay.hide_drag_pointer()

	# Resolve highlight node (may be null).
	var node: Node = null
	if step.highlight_node_path != "":
		node = battle_node.get_node_or_null(step.highlight_node_path)
		if node == null:
			push_warning("TutorialManager: highlight_node_path not found: " + step.highlight_node_path)

	if node and node is Control:
		overlay.highlight_node(node as Control)
		if step.show_drag_arrow:
			var node_rect := (node as Control).get_global_rect()
			var start_pos := node_rect.get_center()
			overlay.show_drag_pointer(start_pos, step.drag_arrow_end_pos)
	else:
		overlay.clear_highlight()

	# Apply input gating for this step.
	_apply_step_gating(step, node)

	# Auto-advance for NONE-action steps.
	if step.action_type == TutorialStep.ActionType.NONE:
		if step.auto_advance_delay > 0.0:
			auto_advance_timer.start(step.auto_advance_delay)
		else:
			push_warning("TutorialManager: NONE step with no auto_advance_delay (step %d). Advancing." % current_step_index)
			# Defer so we don't recurse synchronously.
			call_deferred("_advance_to_next_step")
		return

	# Wait-signal binding.
	if step.action_type == TutorialStep.ActionType.WAIT_SIGNAL:
		if step.wait_signal_name != "":
			_connect_to_custom_signal(step.wait_signal_name)
		else:
			push_warning("TutorialManager: WAIT_SIGNAL step with no signal name.")
			call_deferred("_advance_to_next_step")
		return

	# Card-play steps that may have no valid card → start safety timer.
	if step.action_type == TutorialStep.ActionType.PLAY_CARD_TYPE \
			or step.action_type == TutorialStep.ActionType.PLAY_CARD:
		safety_timer.start(card_type_step_safety_timeout)


# ------------------------------------------------------------------------
# Input gating
# ------------------------------------------------------------------------
# The overlay's full-screen InputBlocker absorbs everything by default.
# For interactive steps, we:
#   1. Tell the overlay to stop blocking (so clicks reach the game).
#   2. Disable every UI element EXCEPT the one(s) the step needs.
# For non-interactive steps (narration only), we leave the blocker on
# and don't bother touching individual buttons — nothing can be clicked.

func _apply_step_gating(step: TutorialStep, highlighted_node: Node) -> void:
	_blocked_buttons.clear()
	_hand_disabled_this_step = false

	var needs_interaction := _step_needs_interaction(step)

	if not needs_interaction:
		# Pure narration step: the full-screen blocker handles everything.
		# We do NOT poke individual disabled flags here, so we can't
		# leave anything in a weird state.
		overlay.set_input_blocking(true)
		return

	# Interactive step: let clicks through, but disable everything that
	# isn't the highlighted target.
	overlay.set_input_blocking(false)

	match step.action_type:
		TutorialStep.ActionType.PLAY_CARD, TutorialStep.ActionType.PLAY_CARD_TYPE:
			# Hand must be live, every other button locked.
			_enable_hand()
			_disable_button("BattleUI/EndTurnButton")
			_disable_button("BattleUI/DrawPileButton")
			_disable_button("BattleUI/DiscardPileButton")

		TutorialStep.ActionType.END_TURN:
			# Only end-turn button is live.
			_disable_hand()
			_disable_button("BattleUI/DrawPileButton")
			_disable_button("BattleUI/DiscardPileButton")
			# Make sure EndTurn is enabled — battle_ui flips it off mid-flow.
			_force_enable_button("BattleUI/EndTurnButton")

		TutorialStep.ActionType.CLICK_NODE:
			# Disable everything except the highlighted node, if it's a button.
			_disable_hand()
			_disable_button("BattleUI/EndTurnButton")
			_disable_button("BattleUI/DrawPileButton")
			_disable_button("BattleUI/DiscardPileButton")
			if highlighted_node and highlighted_node is BaseButton:
				_force_enable_button_node(highlighted_node as BaseButton)

		_:
			# WAIT_ENEMY_TURN / WAIT_SIGNAL: block hand, block end-turn.
			_disable_hand()
			_disable_button("BattleUI/EndTurnButton")
			_disable_button("BattleUI/DrawPileButton")
			_disable_button("BattleUI/DiscardPileButton")


func _step_needs_interaction(step: TutorialStep) -> bool:
	match step.action_type:
		TutorialStep.ActionType.PLAY_CARD, \
		TutorialStep.ActionType.PLAY_CARD_TYPE, \
		TutorialStep.ActionType.END_TURN, \
		TutorialStep.ActionType.CLICK_NODE:
			return true
	# WAIT_ENEMY_TURN / WAIT_SIGNAL / NONE: no player interaction expected.
	return false


func _release_step_gating() -> void:
	if auto_advance_timer:
		auto_advance_timer.stop()
	if safety_timer:
		safety_timer.stop()

	# Re-enable everything we disabled so the next step (or completion)
	# starts from a clean slate. The next step will re-disable as needed.
	for btn in _blocked_buttons:
		if is_instance_valid(btn):
			btn.disabled = false
	_blocked_buttons.clear()

	if _hand_disabled_this_step:
		_enable_hand()
		_hand_disabled_this_step = false


# ------------------------------------------------------------------------
# Hand helpers
# ------------------------------------------------------------------------

func _get_hand() -> Node:
	return battle_node.get_node_or_null("BattleUI/Hand")


func _enable_hand() -> void:
	var hand := _get_hand()
	if hand == null:
		return
	# Iterate children directly so the manager doesn't depend on Hand's API
	# (which has historically called nonexistent Control methods like
	# is_hovered()). This is the same behavior as Hand.disable_hand() in
	# reverse, minus the hover-rebroadcast that can crash.
	for card_ui in hand.get_children():
		if "disabled" in card_ui:
			card_ui.disabled = false


func _disable_hand() -> void:
	var hand := _get_hand()
	if hand == null:
		return
	_hand_disabled_this_step = true
	for card_ui in hand.get_children():
		if "disabled" in card_ui:
			card_ui.disabled = true


# ------------------------------------------------------------------------
# Button helpers
# ------------------------------------------------------------------------

func _disable_button(path: String) -> void:
	var n := battle_node.get_node_or_null(path)
	if n is BaseButton:
		var b := n as BaseButton
		if not b.disabled:
			b.disabled = true
			_blocked_buttons.append(b)


func _force_enable_button(path: String) -> void:
	var n := battle_node.get_node_or_null(path)
	if n is BaseButton:
		(n as BaseButton).disabled = false


func _force_enable_button_node(btn: BaseButton) -> void:
	btn.disabled = false


# ------------------------------------------------------------------------
# Event handlers
# ------------------------------------------------------------------------

func _on_player_hand_drawn() -> void:
	# A new hand was drawn. If the current step had the hand disabled,
	# the freshly created CardUI children won't know about it.
	if not is_active or current_step_index < 0:
		return
	if current_step_index >= steps.size():
		return
	var step := steps[current_step_index]
	# Re-apply gating for the current step now that the hand exists.
	_apply_step_gating(step, _resolve_highlight_node(step))


func _on_player_card_drawn() -> void:
	# Same idea — a single card added to the hand. Re-apply gating so
	# the new card respects the current step's disabled state.
	if not is_active or current_step_index < 0:
		return
	if current_step_index >= steps.size():
		return
	var step := steps[current_step_index]
	if _step_needs_interaction(step):
		match step.action_type:
			TutorialStep.ActionType.PLAY_CARD, TutorialStep.ActionType.PLAY_CARD_TYPE:
				_enable_hand()
			_:
				_disable_hand()
	# (Pure-narration steps are covered by the overlay blocker, no action.)


func _on_card_interaction_ended(_card: CardUI) -> void:
	# CardUI resets `disabled = false` on every card whenever any drag/aim
	# ends. We need to clamp the hand back to the current step's intent.
	if not is_active or current_step_index < 0:
		return
	if current_step_index >= steps.size():
		return
	# Defer one frame so this runs AFTER CardUI's reset.
	call_deferred("_reapply_hand_gating_for_current_step")


func _reapply_hand_gating_for_current_step() -> void:
	if not is_active or current_step_index < 0 or current_step_index >= steps.size():
		return
	var step := steps[current_step_index]
	if not _step_needs_interaction(step):
		# Narration-only step. The overlay blocks input anyway, but make
		# sure the hand is also dimmed/disabled for clarity.
		_disable_hand()
		return
	match step.action_type:
		TutorialStep.ActionType.PLAY_CARD, TutorialStep.ActionType.PLAY_CARD_TYPE:
			_enable_hand()
		_:
			_disable_hand()


func _resolve_highlight_node(step: TutorialStep) -> Node:
	if step.highlight_node_path == "":
		return null
	return battle_node.get_node_or_null(step.highlight_node_path)


func _connect_to_custom_signal(signal_name: String) -> void:
	if Events.has_signal(signal_name):
		Events.connect(signal_name, _on_custom_signal_received.bind(signal_name), CONNECT_ONE_SHOT)
	else:
		push_warning("TutorialManager: Signal not found: " + signal_name)
		call_deferred("_advance_to_next_step")


func _on_custom_signal_received(signal_name: String) -> void:
	if current_step_index < 0 or current_step_index >= steps.size():
		return
	var step := steps[current_step_index]
	if step.wait_signal_name == signal_name:
		await get_tree().create_timer(0.5).timeout
		_advance_to_next_step()


func _on_card_played(card: Card) -> void:
	if not is_active or current_step_index < 0:
		return
	if current_step_index >= steps.size():
		return

	var step := steps[current_step_index]

	match step.action_type:
		TutorialStep.ActionType.PLAY_CARD:
			await get_tree().create_timer(0.5).timeout
			_advance_to_next_step()

		TutorialStep.ActionType.PLAY_CARD_TYPE:
			if card.type == step.card_type_required:
				await get_tree().create_timer(0.5).timeout
				_advance_to_next_step()
			# If wrong type was played, the safety timer is still running.


func _on_end_turn_pressed() -> void:
	if not is_active or current_step_index < 0:
		return
	if current_step_index >= steps.size():
		return

	var step := steps[current_step_index]
	if step.action_type == TutorialStep.ActionType.END_TURN:
		await get_tree().create_timer(0.3).timeout
		_advance_to_next_step()


func _on_enemy_turn_ended() -> void:
	if not is_active or current_step_index < 0:
		return
	if current_step_index >= steps.size():
		return

	var step := steps[current_step_index]
	if step.action_type == TutorialStep.ActionType.WAIT_ENEMY_TURN:
		await get_tree().create_timer(0.5).timeout
		_advance_to_next_step()


func _on_auto_advance_timeout() -> void:
	_advance_to_next_step()


func _on_safety_timeout() -> void:
	# Player got stuck on a card-play step (no matching card, no mana, etc.)
	# Force-advance so the tutorial doesn't soft-lock the game.
	push_warning("TutorialManager: safety timeout on step %d — force-advancing." % current_step_index)
	_advance_to_next_step()


func _complete_tutorial() -> void:
	is_active = false

	if tutorial_key != "":
		DialogueState.mark_shown(tutorial_key)
		print("Tutorial '%s' completed and saved!" % tutorial_key)

	_release_step_gating()
	# Make sure the overlay isn't still blocking input.
	if overlay:
		overlay.set_input_blocking(false)

	_disconnect_events()

	if narration:
		narration.hide_narration()
		# Wait briefly — but don't hang forever if the signal never fires.
		var timeout := get_tree().create_timer(0.5)
		await timeout.timeout

	if overlay:
		overlay.hide_overlay()
		await get_tree().create_timer(0.3).timeout
		overlay.queue_free()

	emit_signal("tutorial_completed")
	queue_free()


func skip_tutorial() -> void:
	is_active = false
	if tutorial_key != "":
		DialogueState.mark_shown(tutorial_key)

	_release_step_gating()
	if overlay:
		overlay.set_input_blocking(false)
	_disconnect_events()

	if overlay:
		overlay.queue_free()
	if narration:
		narration.queue_free()

	queue_free()
