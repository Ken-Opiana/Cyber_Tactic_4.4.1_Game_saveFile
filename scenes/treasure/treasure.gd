class_name Treasure
extends Control

@export var thread_handler: ThreadHandler
@export var char_stats: CharacterStats

# The SubViewportContainer that holds the 3D crate — grabbed by node path.
@onready var loot_crate_viewport: SubViewportContainer = $LootCrateViewport

# Resolved in _ready() because AnimationPlayer lives inside an instanced GLB,
# so the %Name shorthand cannot cross the instance boundary.
var animation_player: AnimationPlayer

var found_thread: ThreadPassive
var _is_opening := false
var _is_hovered := false

# Treasure thread pool — loaded from .tres instead of an export.
var treasure_thread_pool: ThreadPool = load("res://threads/thread_pools/shop_thread_pool.tres")


func _ready() -> void:
	# Walk into the GLB instance and find its AnimationPlayer dynamically.
	# This is reliable regardless of the nesting depth inside the GLB.
	var loot_crate: Node = $LootCrateViewport/SubViewport/World3D/LootCrate
	animation_player = loot_crate.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animation_player:
		push_error("Treasure: Could not find AnimationPlayer inside LootCrate GLB. " \
				+ "Check that the AnimationPlayer node exists in the imported asset.")
		return
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("Idle")


func generate_thread() -> void:
	# Uses ThreadPool's built-in filter helper.
	var available_threads := treasure_thread_pool.get_available_threads(char_stats, thread_handler)
	found_thread = RNG.array_pick_random(available_threads)


# ── Animation callbacks ────────────────────────────────────────────────────────

func _on_animation_finished(anim_name: StringName) -> void:
	if _is_opening:
		# "Open" finished → emit the treasure exit signal
		if anim_name == "Open":
			Events.treasure_room_exited.emit(found_thread)
		return
	# After any non-opening animation ends, return to the correct idle state
	if _is_hovered:
		animation_player.play("Shake")
	else:
		animation_player.play("Idle")


# ── Input handlers (connect these signals from LootCrateViewport in the .tscn) ─

func _on_loot_crate_mouse_entered() -> void:
	if _is_opening:
		return
	_is_hovered = true
	animation_player.play("Shake")


func _on_loot_crate_mouse_exited() -> void:
	_is_hovered = false
	if _is_opening:
		return
	animation_player.play("Idle")


func _on_loot_crate_gui_input(event: InputEvent) -> void:
	if _is_opening:
		return
	if event.is_action_pressed("left_mouse"):
		_is_opening = true
		animation_player.play("Open")
