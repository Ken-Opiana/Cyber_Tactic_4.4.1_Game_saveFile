class_name IntentTooltip
extends Control

@export var fade_seconds := 0.15
@export var offset_from_mouse := Vector2(-10, 0)  # Offset to the left of mouse
@export var screen_padding := 2.0  # Pixels of breathing room from screen edges

@onready var description_label: Label = %DescriptionLabel
@onready var panel_container: PanelContainer = $PanelContainer

var tween: Tween
var is_visible_now := false


func _ready() -> void:
	Events.intent_tooltip_requested.connect(show_tooltip)
	Events.intent_tooltip_hide_requested.connect(hide_tooltip)
	Events.intent_tooltip_position_updated.connect(update_position)
	modulate = Color.TRANSPARENT
	hide()


func show_tooltip(description: String, mouse_pos: Vector2) -> void:
	is_visible_now = true
	if tween:
		tween.kill()
	
	description_label.text = description
	
	# Let the label re-flow and the panel resize before we measure it,
	# otherwise we'd clamp against the previous tooltip's size.
	await get_tree().process_frame
	
	if not is_visible_now:
		return  # Got hidden mid-await; bail.
	
	_position_on_screen(mouse_pos)
	
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(show)
	tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)


func update_position(mouse_pos: Vector2) -> void:
	if is_visible_now:
		_position_on_screen(mouse_pos)


func hide_tooltip() -> void:
	is_visible_now = false
	if tween:
		tween.kill()
	
	get_tree().create_timer(fade_seconds, false).timeout.connect(hide_animation)


func hide_animation() -> void:
	if not is_visible_now:
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_seconds)
		tween.tween_callback(hide)


# Positions the tooltip relative to the mouse, then clamps it to stay
# fully on-screen on all four edges. The PanelContainer is the actual
# visible rectangle (the root Control has no size of its own here), so
# we measure against its size.
func _position_on_screen(mouse_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = panel_container.size if panel_container else Vector2.ZERO
	
	# Try the preferred side first: to the LEFT of the mouse.
	# offset_from_mouse.x is negative, so we shift the tooltip's right
	# edge to just left of the cursor.
	var pos: Vector2 = mouse_pos + offset_from_mouse - Vector2(tooltip_size.x, 0)
	
	# If that puts us off the left edge, flip to the right of the mouse.
	if pos.x < screen_padding:
		pos.x = mouse_pos.x - offset_from_mouse.x  # Mirror the offset to the right
	
	# If we'd still go off the right edge, clamp to the right edge.
	# This is the case in the screenshot: enemy near the right side, long
	# description, neither left nor right side fits cleanly — so we just
	# slide the tooltip back in until it fits.
	if pos.x + tooltip_size.x > viewport_size.x - screen_padding:
		pos.x = viewport_size.x - tooltip_size.x - screen_padding
	
	# Clamp top/bottom too, in case the mouse is near the top or bottom.
	if pos.y + tooltip_size.y > viewport_size.y - screen_padding:
		pos.y = viewport_size.y - tooltip_size.y - screen_padding
	if pos.y < screen_padding:
		pos.y = screen_padding
	
	global_position = pos
