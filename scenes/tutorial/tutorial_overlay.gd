class_name TutorialOverlay
extends CanvasLayer

# A full-screen Control that absorbs all clicks/drags when the tutorial is
# gating input. We swap its mouse_filter between STOP (block everything) and
# IGNORE (let interactions through) depending on the step.
@onready var input_blocker: Control = $InputBlocker
@onready var dim_rect: ColorRect = $InputBlocker/DimRect
@onready var highlight_border: ReferenceRect = $HighlightBorder

var highlighted_node: Control = null
var pulse_tween: Tween
var tutorial_pointer: Node2D = null

# Optional dim level when fully blocking input. 0.0 disables the dim entirely.
const BLOCK_DIM_ALPHA := 0.35


func _ready() -> void:
	# CanvasLayers do not take input themselves. The InputBlocker Control
	# beneath us is what actually absorbs mouse events.
	layer = 100
	hide()

	# Default: block everything. The manager opens "holes" per step.
	_set_full_block(true)

	highlight_border.hide()
	highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Highlight should render on top of the blocker.
	highlight_border.z_index = 1

	# Tutorial pointer (arrow) is purely visual, must not catch input.
	var pointer_scene := preload("res://scenes/tutorial/tutorial_pointer.tscn")
	tutorial_pointer = pointer_scene.instantiate()
	add_child(tutorial_pointer)


func show_overlay() -> void:
	show()


func hide_overlay() -> void:
	if pulse_tween:
		pulse_tween.kill()
	hide()
	highlight_border.hide()
	highlighted_node = null


# --- Input gating ---------------------------------------------------------
# The blocker has two modes:
#   - "full block": every click is swallowed, nothing in the game is reachable.
#   - "pass through": clicks fall through to the game UI (used during steps
#     where the player must actually interact, e.g. dragging a card).
#
# When passing through we still want a visual dim, so we keep the ColorRect
# visible but flip its mouse_filter to IGNORE so it doesn't catch events.

func set_input_blocking(blocking: bool) -> void:
	_set_full_block(blocking)


func _set_full_block(blocking: bool) -> void:
	if not is_node_ready():
		await ready
	if blocking:
		input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		dim_rect.color = Color(0, 0, 0, BLOCK_DIM_ALPHA)
	else:
		input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_rect.color = Color(0, 0, 0, 0)


func highlight_node(node: Control) -> void:
	if not node or not is_instance_valid(node):
		clear_highlight()
		return

	highlighted_node = node
	_update_highlight_border()
	_start_pulse_animation()


func clear_highlight() -> void:
	if pulse_tween:
		pulse_tween.kill()
	highlight_border.hide()
	highlighted_node = null
	if tutorial_pointer:
		tutorial_pointer.call("hide_pointer")


func _update_highlight_border() -> void:
	if not highlighted_node or not is_instance_valid(highlighted_node):
		return

	var node_rect := highlighted_node.get_global_rect()
	var padding := 10.0
	highlight_border.global_position = node_rect.position - Vector2(padding, padding)
	highlight_border.size = node_rect.size + Vector2(padding * 2, padding * 2)
	highlight_border.show()


func _start_pulse_animation() -> void:
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(highlight_border, "modulate:a", 0.3, 0.6)
	pulse_tween.tween_property(highlight_border, "modulate:a", 1.0, 0.6)


func _process(_delta: float) -> void:
	if highlighted_node and is_instance_valid(highlighted_node):
		_update_highlight_border()
	elif highlighted_node and not is_instance_valid(highlighted_node):
		# Highlighted node was freed (e.g. card played, enemy died).
		clear_highlight()


func show_drag_pointer(start_pos: Vector2, end_pos: Vector2) -> void:
	if tutorial_pointer:
		tutorial_pointer.call("show_pointer", 1, start_pos, end_pos)


func hide_drag_pointer() -> void:
	if tutorial_pointer:
		tutorial_pointer.call("hide_pointer")
