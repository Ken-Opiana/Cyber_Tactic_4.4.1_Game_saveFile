class_name ShopUI2
extends Control

signal back_pressed()
signal tray_collected(card_ids: Array[String], thread_ids: Array[String])

const SHOP_CARD_SCENE   = preload("res://scenes/shop/shop_card.tscn")
const SHOP_THREAD_SCENE = preload("res://scenes/shop/shop_thread.tscn")
const SHOP_CARD_UI      = preload("res://scenes/ui/card_menu_ui.tscn")
const SHOP_THREAD_UI    = preload("res://scenes/thread_handler/thread_ui.tscn")

# ── Injected by Shop ───────────────────────────────────────────────────────────
var char_stats: CharacterStats
var run_stats: RunStats
var thread_handler: ThreadHandler
var modifier_handler: ModifierHandler
var _all_threads: Array[ThreadPassive] = []

# ── Slot data ──────────────────────────────────────────────────────────────────
var _slot_codes: Array[String]      = []
var _card_ids: Array[String]        = []
var _card_prices: Array[int]        = []
var _sold_card_ids: Array[String]   = []
var _thread_ids: Array[String]      = []
var _thread_prices: Array[int]      = []
var _sold_thread_ids: Array[String] = []
var _tray_card_ids: Array[String]   = []
var _tray_thread_ids: Array[String] = []

# ── Runtime slot scene instances ───────────────────────────────────────────────
var _card_slots: Array[ShopCard]     = []
var _thread_slots: Array[ShopThread] = []

# ── Node references ────────────────────────────────────────────────────────────
@onready var card_slot_container: HBoxContainer   = %CardSlotContainer
@onready var thread_slot_container: HBoxContainer = %ThreadSlotContainer
@onready var keypad: ShopKeypad                   = %Keypad
@onready var tray_area: Button                    = %TrayArea
@onready var tray_contents: HBoxContainer         = %TrayContents
@onready var tray_label: Label                    = %TrayLabel
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopUp


func _ready() -> void:
	# tray_area.pressed is connected via .tscn — do NOT connect again here.
	keypad.code_entered.connect(_on_code_entered)
	_refresh_tray_ui()


# ── Public API ─────────────────────────────────────────────────────────────────

func populate(
		card_ids: Array[String],   card_prices: Array[int],   sold_card_ids: Array[String],
		thread_ids: Array[String], thread_prices: Array[int], sold_thread_ids: Array[String],
		slot_codes: Array[String],
		tray_card_ids: Array[String], tray_thread_ids: Array[String]
) -> void:
	_card_ids         = card_ids.duplicate()
	_card_prices      = card_prices.duplicate()
	_sold_card_ids    = sold_card_ids.duplicate()
	_thread_ids       = thread_ids.duplicate()
	_thread_prices    = thread_prices.duplicate()
	_sold_thread_ids  = sold_thread_ids.duplicate()
	_slot_codes       = slot_codes.duplicate()
	_tray_card_ids    = tray_card_ids.duplicate()
	_tray_thread_ids  = tray_thread_ids.duplicate()
	_build_slots()
	_rebuild_tray_visuals()


func set_available_threads(threads: Array[ThreadPassive]) -> void:
	_all_threads = threads

func get_slot_codes()      -> Array[String]: return _slot_codes
func get_tray_card_ids()   -> Array[String]: return _tray_card_ids
func get_tray_thread_ids() -> Array[String]: return _tray_thread_ids
func get_sold_card_ids()   -> Array[String]: return _sold_card_ids
func get_sold_thread_ids() -> Array[String]: return _sold_thread_ids


# Updates price labels on existing slot nodes without rebuilding them.
# Called by Shop after coupon discount is applied.
func refresh_prices(card_prices: Array[int], thread_prices: Array[int]) -> void:
	_card_prices   = card_prices.duplicate()
	_thread_prices = thread_prices.duplicate()
	for i in _card_slots.size():
		if _card_slots[i] and i < _card_prices.size():
			_card_slots[i].update_price(_card_prices[i])
	for i in _thread_slots.size():
		if _thread_slots[i] and i < _thread_prices.size():
			_thread_slots[i].update_price(_thread_prices[i])
	_refresh_affordability()


# ── Slot building using shop_card.tscn / shop_thread.tscn ─────────────────────

func _build_slots() -> void:
	for child in card_slot_container.get_children():
		child.queue_free()
	for child in thread_slot_container.get_children():
		child.queue_free()
	_card_slots.clear()
	_thread_slots.clear()

	for i in 4:
		var code  := _slot_codes[i] if i < _slot_codes.size() else "????"
		var price := _card_prices[i] if i < _card_prices.size() else 0
		var sold  := (_card_ids[i] in _sold_card_ids) if i < _card_ids.size() else false

		if sold:
			# Slot was already bought — skip it entirely, leave the space empty.
			_card_slots.append(null)
			continue

		var slot := SHOP_CARD_SCENE.instantiate() as ShopCard
		card_slot_container.add_child(slot)
		_card_slots.append(slot)

		if i < _card_ids.size():
			var card := _find_card(_card_ids[i])
			if card:
				slot.setup(card, price, code)
				if card_tooltip_popup and slot.card_container.get_child_count() > 0:
					var card_ui := slot.card_container.get_child(0) as CardMenuUI
					if card_ui:
						card_ui.tooltip_requested.connect(card_tooltip_popup.show_tooltip)

	for i in 4:
		var ci    := i + 4
		var code  := _slot_codes[ci] if ci < _slot_codes.size() else "????"
		var price := _thread_prices[i] if i < _thread_prices.size() else 0
		var sold  := (_thread_ids[i] in _sold_thread_ids) if i < _thread_ids.size() else false

		if sold:
			# Slot was already bought — skip it entirely.
			_thread_slots.append(null)
			continue

		var slot := SHOP_THREAD_SCENE.instantiate() as ShopThread
		thread_slot_container.add_child(slot)
		_thread_slots.append(slot)

		if i < _thread_ids.size():
			var thread := _find_thread(_thread_ids[i])
			if thread:
				slot.setup(thread, price, code)

	_refresh_affordability()

	_refresh_affordability()


# ── Keypad logic ───────────────────────────────────────────────────────────────

func _on_code_entered(code: String) -> void:
	var result := _resolve_code(code)
	match result:
		"INVALID":
			keypad.play_fail_sfx()
			keypad.show_message("INVALID CODE")
			keypad.clear_input()
		"SOLD":
			keypad.play_fail_sfx()
			keypad.show_message("SOLD OUT")
			keypad.clear_input()
		"NO_FUNDS":
			keypad.play_fail_sfx()
			keypad.show_message("INSUFFICIENT\nFUNDS")
			keypad.clear_input()
		_:
			_process_purchase(result)


func _resolve_code(code: String) -> String:
	code = code.to_upper()
	for i in _card_ids.size():
		if i < _slot_codes.size() and _slot_codes[i] == code:
			if _card_ids[i] in _sold_card_ids:
				return "SOLD"
			if run_stats.gold < (_card_prices[i] if i < _card_prices.size() else 0):
				return "NO_FUNDS"
			return "card:%d" % i
	for i in _thread_ids.size():
		var ci := i + 4
		if ci < _slot_codes.size() and _slot_codes[ci] == code:
			if _thread_ids[i] in _sold_thread_ids:
				return "SOLD"
			if run_stats.gold < (_thread_prices[i] if i < _thread_prices.size() else 0):
				return "NO_FUNDS"
			return "thread:%d" % i
	return "INVALID"


func _process_purchase(result: String) -> void:
	var parts := result.split(":")
	var kind  := parts[0]
	var idx   := parts[1].to_int()

	keypad.show_message("DISPENSING...", 0.0)
	keypad.play_success_sfx()

	if kind == "card":
		var price := _card_prices[idx]
		run_stats.gold -= price
		_sold_card_ids.append(_card_ids[idx])
		_tray_card_ids.append(_card_ids[idx])
		_animate_drop_card(idx)
		Events.shop_card_bought.emit(_find_card(_card_ids[idx]), price)
	else:
		var price := _thread_prices[idx]
		run_stats.gold -= price
		_sold_thread_ids.append(_thread_ids[idx])
		_tray_thread_ids.append(_thread_ids[idx])
		_animate_drop_thread(idx)
		Events.shop_thread_bought.emit(_find_thread(_thread_ids[idx]), price)

	# Remove the slot node entirely instead of showing SOLD OUT.
	if kind == "card" and idx < _card_slots.size():
		_card_slots[idx].queue_free()
		_card_slots[idx] = null
	elif kind == "thread" and idx < _thread_slots.size():
		_thread_slots[idx].queue_free()
		_thread_slots[idx] = null

	# Update remaining slot colors since gold decreased.
	_refresh_affordability()

	await get_tree().create_timer(1.2).timeout
	keypad.show_message("ENJOY!", 1.0)
	keypad.clear_input()


# ── Affordability colors ───────────────────────────────────────────────────────

func _refresh_affordability() -> void:
	var gold := run_stats.gold if run_stats else 0
	for slot in _card_slots:
		if slot:
			slot.update_affordability(gold)
	for slot in _thread_slots:
		if slot:
			slot.update_affordability(gold)


# ── Drop animation ─────────────────────────────────────────────────────────────

func _animate_drop_card(idx: int) -> void:
	if idx >= _card_slots.size():
		return
	var slot      := _card_slots[idx]
	var container := slot.card_container
	if container and container.get_child_count() > 0:
		_do_drop_animation(container.get_child(0))


func _animate_drop_thread(idx: int) -> void:
	if idx >= _thread_slots.size():
		return
	var slot      := _thread_slots[idx]
	var container := slot.thread_container
	if container and container.get_child_count() > 0:
		_do_drop_animation(container.get_child(0))


func _do_drop_animation(item_node: Control) -> void:
	var start_pos := item_node.global_position
	var tray_pos  := tray_area.global_position + tray_area.size * 0.5 - Vector2(16, 16)

	var canvas := _get_drop_canvas()
	var ghost  := item_node.duplicate() as Control
	canvas.add_child(ghost)
	ghost.global_position = start_pos
	item_node.visible     = false

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ghost, "global_position", tray_pos, 0.45)
	tween.tween_callback(func():
		ghost.queue_free()
		_rebuild_tray_visuals()
	)


func _get_drop_canvas() -> CanvasLayer:
	var root     := get_tree().root
	var existing := root.get_node_or_null("DropAnimationLayer")
	if existing:
		return existing as CanvasLayer
	var layer   := CanvasLayer.new()
	layer.name  = "DropAnimationLayer"
	layer.layer = 10
	root.add_child(layer)
	return layer


# ── Tray ───────────────────────────────────────────────────────────────────────

func _refresh_tray_ui() -> void:
	if tray_contents:
		_rebuild_tray_visuals()


func _rebuild_tray_visuals() -> void:
	for child in tray_contents.get_children():
		child.queue_free()

	var has_items := not _tray_card_ids.is_empty() or not _tray_thread_ids.is_empty()
	tray_label.visible    = not has_items
	tray_contents.visible = has_items
	tray_area.disabled    = not has_items

	for cid in _tray_card_ids:
		var card := _find_card(cid)
		if card:
			var card_ui := SHOP_CARD_UI.instantiate() as CardMenuUI
			tray_contents.add_child(card_ui)
			card_ui.card = card

	for tid in _tray_thread_ids:
		var thread := _find_thread(tid)
		if thread:
			var thread_ui := SHOP_THREAD_UI.instantiate() as ThreadUI
			tray_contents.add_child(thread_ui)
			thread_ui.thread_passive = thread


func _on_tray_pressed() -> void:
	if _tray_card_ids.is_empty() and _tray_thread_ids.is_empty():
		return
	tray_collected.emit(_tray_card_ids.duplicate(), _tray_thread_ids.duplicate())
	_tray_card_ids.clear()
	_tray_thread_ids.clear()
	_rebuild_tray_visuals()


# ── Back ───────────────────────────────────────────────────────────────────────

func _on_back_button_pressed() -> void:
	back_pressed.emit()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _find_card(id: String) -> Card:
	if not char_stats:
		return null
	for card: Card in char_stats.draftable_cards.cards:
		if card.id == id:
			return card
	return null


func _find_thread(id: String) -> ThreadPassive:
	for t: ThreadPassive in _all_threads:
		if t.id == id:
			return t
	return null
