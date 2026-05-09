class_name Shop
extends Control

# ── Scene references ───────────────────────────────────────────────────────────
const SHOP_UI1_SCENE := preload("res://scenes/shop/shop_ui1.tscn")
const SHOP_UI2_SCENE := preload("res://scenes/shop/shop_ui2.tscn")

# ── Exports (assigned in shop.tscn, same as before) ───────────────────────────
@export var shop_threads: Array[ThreadPassive]
@export var char_stats: CharacterStats
@export var run_stats: RunStats
@export var thread_handler: ThreadHandler

@onready var ui_container: Control        = %UIContainer
@onready var modifier_handler: ModifierHandler = $ModifierHandler

# ── Active UI nodes ────────────────────────────────────────────────────────────
var _ui1: ShopUI1 = null
var _ui2: ShopUI2 = null

# ── Session state ──────────────────────────────────────────────────────────────
var _card_ids: Array[String]        = []
var _card_prices: Array[int]        = []
var _sold_card_ids: Array[String]   = []
var _thread_ids: Array[String]      = []
var _thread_prices: Array[int]      = []
var _sold_thread_ids: Array[String] = []
var _slot_codes: Array[String]      = []
var _tray_card_ids: Array[String]   = []
var _tray_thread_ids: Array[String] = []

# Tracks whether the CouponsThread discount has already been applied this visit.
# Prevents the save/load exploit from stacking discounts repeatedly.
var _coupon_applied: bool = false

# ── Transition state ───────────────────────────────────────────────────────────
var _transitioning: bool = false


func _ready() -> void:
	Events.shop_thread_bought.connect(_on_shop_thread_bought_modifier_check)
	_show_ui1()


# ── Public population API (called by Run) ──────────────────────────────────────

func populate_shop() -> void:
	_generate_shop_cards()
	_generate_shop_threads()
	_generate_slot_codes()


func restore_from_save(
		card_ids: Array[String],   card_prices: Array[int],   sold_card_ids: Array[String],
		thread_ids: Array[String], thread_prices: Array[int], sold_thread_ids: Array[String],
		slot_codes: Array[String]       = [],
		tray_card_ids: Array[String]    = [],
		tray_thread_ids: Array[String]  = [],
		coupon_applied: bool            = false
) -> void:
	_card_ids         = card_ids.duplicate()
	_card_prices      = card_prices.duplicate()
	_sold_card_ids    = sold_card_ids.duplicate()
	_thread_ids       = thread_ids.duplicate()
	_thread_prices    = thread_prices.duplicate()
	_sold_thread_ids  = sold_thread_ids.duplicate()
	_tray_card_ids    = tray_card_ids.duplicate()
	_tray_thread_ids  = tray_thread_ids.duplicate()
	_coupon_applied   = coupon_applied

	# If slot codes weren't saved (old save format), generate new ones.
	if slot_codes.is_empty():
		_generate_slot_codes()
	else:
		_slot_codes = slot_codes.duplicate()

	# Only re-apply modifier prices if the coupon hasn't been applied yet.
	# This prevents the save/load exploit from stacking discounts.
	if not _coupon_applied:
		for i in _card_prices.size():
			_card_prices[i] = _get_updated_shop_cost(_card_prices[i])
		for i in _thread_prices.size():
			_thread_prices[i] = _get_updated_shop_cost(_thread_prices[i])

	_refresh_ui1_tray_indicator()


# ── State getters (called by Run._save_run()) ──────────────────────────────────

func get_card_ids()          -> Array[String]: return _card_ids
func get_card_prices()       -> Array[int]:    return _card_prices
func get_sold_card_ids()     -> Array[String]:
	if _ui2: return _ui2.get_sold_card_ids()
	return _sold_card_ids
func get_thread_ids()        -> Array[String]: return _thread_ids
func get_thread_prices()     -> Array[int]:    return _thread_prices
func get_sold_thread_ids()   -> Array[String]:
	if _ui2: return _ui2.get_sold_thread_ids()
	return _sold_thread_ids
func get_slot_codes()        -> Array[String]:
	if _ui2: return _ui2.get_slot_codes()
	return _slot_codes
func get_tray_card_ids()     -> Array[String]:
	if _ui2: return _ui2.get_tray_card_ids()
	return _tray_card_ids
func get_tray_thread_ids()   -> Array[String]:
	if _ui2: return _ui2.get_tray_thread_ids()
	return _tray_thread_ids
func get_coupon_applied()    -> bool: return _coupon_applied


# ── UI1 ────────────────────────────────────────────────────────────────────────

func _show_ui1() -> void:
	_cleanup_ui2()

	_ui1 = SHOP_UI1_SCENE.instantiate() as ShopUI1
	ui_container.add_child(_ui1)

	_ui1.machine_clicked.connect(_on_machine_clicked)
	_ui1.leave_pressed.connect(_on_leave_pressed)

	_refresh_ui1_tray_indicator()

	# Fade in.
	_ui1.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_ui1, "modulate:a", 1.0, 0.3)


func _refresh_ui1_tray_indicator() -> void:
	if _ui1:
		var has_items := not _tray_card_ids.is_empty() or not _tray_thread_ids.is_empty()
		_ui1.set_tray_indicator(has_items)


# ── UI2 ────────────────────────────────────────────────────────────────────────

func _show_ui2() -> void:
	_cleanup_ui1()

	_ui2 = SHOP_UI2_SCENE.instantiate() as ShopUI2
	ui_container.add_child(_ui2)

	# Inject dependencies.
	_ui2.char_stats       = char_stats
	_ui2.run_stats        = run_stats
	_ui2.thread_handler   = thread_handler
	_ui2.modifier_handler = modifier_handler
	_ui2.set_available_threads(shop_threads)

	_ui2.back_pressed.connect(_on_ui2_back_pressed)
	_ui2.tray_collected.connect(_on_tray_collected)

	# Sync latest sold IDs from previous UI2 session (if any).
	_ui2.populate(
		_card_ids, _card_prices, _sold_card_ids,
		_thread_ids, _thread_prices, _sold_thread_ids,
		_slot_codes,
		_tray_card_ids, _tray_thread_ids
	)

	# Zoom-in effect: start small, tween to full size.
	_ui2.scale   = Vector2(0.5, 0.5)
	_ui2.pivot_offset = _ui2.size * 0.5
	_ui2.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_ui2, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ui2, "modulate:a", 1.0, 0.3)


# ── Crossfade helpers ──────────────────────────────────────────────────────────

func _on_machine_clicked() -> void:
	if _transitioning:
		return
	_transitioning = true

	# Snapshot sold state from UI2 if somehow already open (safety).
	_sync_sold_state()

	# Fade out UI1, then show UI2.
	if _ui1:
		var tween := create_tween()
		tween.tween_property(_ui1, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func():
			_transitioning = false
			_show_ui2()
		)
	else:
		_transitioning = false
		_show_ui2()


func _on_ui2_back_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true

	# Snapshot state from UI2 before destroying it.
	_sync_sold_state()
	_tray_card_ids   = _ui2.get_tray_card_ids().duplicate()
	_tray_thread_ids = _ui2.get_tray_thread_ids().duplicate()
	_slot_codes      = _ui2.get_slot_codes().duplicate()

	# Zoom-out effect on UI2, then show UI1.
	if _ui2:
		_ui2.pivot_offset = _ui2.size * 0.5
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_ui2, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(_ui2, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(func():
			_transitioning = false
			_show_ui1()
		)
	else:
		_transitioning = false
		_show_ui1()


func _sync_sold_state() -> void:
	if _ui2:
		_sold_card_ids   = _ui2.get_sold_card_ids().duplicate()
		_sold_thread_ids = _ui2.get_sold_thread_ids().duplicate()


# ── Tray collection ────────────────────────────────────────────────────────────

func _on_tray_collected(card_ids: Array[String], thread_ids: Array[String]) -> void:
	# Add cards to deck.
	for cid in card_ids:
		var card := _find_card(cid)
		if card:
			char_stats.deck.add_card(card)

	# Add threads to handler and handle CouponsThread modifier.
	for tid in thread_ids:
		var thread := _find_thread(tid)
		if thread:
			thread_handler.add_thread(thread)
			if thread is CouponsThread and not _coupon_applied:
				_coupon_applied = true
				var coupons_thread := thread as CouponsThread
				coupons_thread.add_shop_modifier(self)
				_update_item_costs()

	_tray_card_ids.clear()
	_tray_thread_ids.clear()
	_refresh_ui1_tray_indicator()


# ── Leave ──────────────────────────────────────────────────────────────────────

func _on_leave_pressed() -> void:
	Events.shop_exited.emit()


# ── Cleanup helpers ────────────────────────────────────────────────────────────

func _cleanup_ui1() -> void:
	if _ui1:
		_ui1.queue_free()
		_ui1 = null


func _cleanup_ui2() -> void:
	if _ui2:
		_ui2.queue_free()
		_ui2 = null


# ── Shop generation ────────────────────────────────────────────────────────────

func _generate_shop_cards() -> void:
	_card_ids.clear()
	_card_prices.clear()

	var available_cards: Array[Card] = char_stats.draftable_cards.duplicate_cards()
	RNG.array_shuffle(available_cards)
	var shop_card_array: Array[Card] = available_cards.slice(0, 4)

	for card: Card in shop_card_array:
		var base_price := RNG.instance.randi_range(100, 300)
		_card_ids.append(card.id)
		_card_prices.append(_get_updated_shop_cost(base_price))


func _generate_shop_threads() -> void:
	_thread_ids.clear()
	_thread_prices.clear()

	var available_threads := shop_threads.filter(
		func(thread: ThreadPassive):
			return thread.can_appear_as_reward(char_stats) and not thread_handler.has_thread(thread.id)
	)
	RNG.array_shuffle(available_threads)
	var shop_threads_array: Array[ThreadPassive] = available_threads.slice(0, 4)

	for thread: ThreadPassive in shop_threads_array:
		var base_price := RNG.instance.randi_range(100, 300)
		_thread_ids.append(thread.id)
		_thread_prices.append(_get_updated_shop_cost(base_price))


func _generate_slot_codes() -> void:
	_slot_codes.clear()
	var used: Array[String] = []
	# 4 card codes + 4 thread codes = 8 total.
	for _i in 8:
		var code := _make_unique_code(used)
		_slot_codes.append(code)
		used.append(code)


func _make_unique_code(used: Array[String]) -> String:
	const LETTERS := "ABCD"   # must match the letter buttons on the keypad
	const DIGITS  := "0123456789"
	var code := ""
	var attempts := 0
	while true:
		attempts += 1
		# Format: AB12 — 2 letters then 2 digits.
		code  = LETTERS[RNG.instance.randi() % LETTERS.length()]
		code += LETTERS[RNG.instance.randi() % LETTERS.length()]
		code += DIGITS[RNG.instance.randi() % DIGITS.length()]
		code += DIGITS[RNG.instance.randi() % DIGITS.length()]
		if code not in used or attempts > 1000:
			break
	return code


# ── Modifier / cost helpers ────────────────────────────────────────────────────

func _get_updated_shop_cost(original_cost: int) -> int:
	return modifier_handler.get_modified_value(original_cost, Modifier.Type.SHOP_COST)


func _update_item_costs() -> void:
	for i in _card_prices.size():
		_card_prices[i] = _get_updated_shop_cost(_card_prices[i])
	for i in _thread_prices.size():
		_thread_prices[i] = _get_updated_shop_cost(_thread_prices[i])
	# Update prices on existing slot nodes directly — do NOT call populate()
	# as that would rebuild all slots and visually restock sold items.
	if _ui2:
		_ui2.refresh_prices(_card_prices, _thread_prices)


# ── Modifier event (CouponsThread applied before tray collection) ──────────────
func _on_shop_thread_bought_modifier_check(_thread: ThreadPassive, _cost: int) -> void:
	# Intentionally left minimal — modifier application happens in _on_tray_collected
	# when the player actually picks up the item from the tray.
	pass


# ── Find helpers ───────────────────────────────────────────────────────────────

func _find_card(id: String) -> Card:
	for card: Card in char_stats.draftable_cards.cards:
		if card.id == id:
			return card
	return null


func _find_thread(id: String) -> ThreadPassive:
	for t: ThreadPassive in shop_threads:
		if t.id == id:
			return t
	return null
