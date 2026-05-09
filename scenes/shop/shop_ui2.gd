class_name ShopUI2
extends Control

signal back_pressed()
signal tray_collected(card_ids: Array[String], thread_ids: Array[String])

const SHOP_CARD_SCENE   = preload("res://scenes/shop/shop_card.tscn")
const SHOP_THREAD_SCENE = preload("res://scenes/shop/shop_thread.tscn")

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
	# Tray is decorative only now — items auto-claim on purchase.
	tray_area.disabled = true
	tray_contents.visible = false
	if tray_label:
		tray_label.visible = true


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

	# Legacy save migration: if a save from the old click-to-claim flow has items
	# stuck in the tray, claim them immediately on shop entry so they aren't lost.
	if not tray_card_ids.is_empty() or not tray_thread_ids.is_empty():
		call_deferred("_emit_legacy_claim", tray_card_ids.duplicate(), tray_thread_ids.duplicate())

	_build_slots()


func _emit_legacy_claim(card_ids: Array[String], thread_ids: Array[String]) -> void:
	tray_collected.emit(card_ids, thread_ids)


func set_available_threads(threads: Array[ThreadPassive]) -> void:
	_all_threads = threads

func get_slot_codes()      -> Array[String]: return _slot_codes
# Tray arrays are always empty under the auto-claim flow — kept for save compat.
func get_tray_card_ids()   -> Array[String]: return [] as Array[String]
func get_tray_thread_ids() -> Array[String]: return [] as Array[String]
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
				# No tooltip wiring needed — ThreadUI emits Events.thread_tooltip_requested
				# directly from its own _on_gui_input, and the Run scene listens for it.

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
		var card_id := _card_ids[idx]
		run_stats.gold -= price
		_sold_card_ids.append(card_id)
		Events.shop_card_bought.emit(_find_card(card_id), price)
		# Claim immediately — straight to inventory, no tray.
		tray_collected.emit([card_id] as Array[String], [] as Array[String])
	else:
		var price := _thread_prices[idx]
		var thread_id := _thread_ids[idx]
		run_stats.gold -= price
		_sold_thread_ids.append(thread_id)
		Events.shop_thread_bought.emit(_find_thread(thread_id), price)
		# Claim immediately — straight to inventory, no tray.
		tray_collected.emit([] as Array[String], [thread_id] as Array[String])

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


# ── Tray (decorative only) ─────────────────────────────────────────────────────

func _on_tray_pressed() -> void:
	# Tray click is no longer used — items are auto-claimed on purchase.
	# Method kept because the signal is wired in the .tscn.
	pass


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
