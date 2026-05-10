class_name BattleReward
extends Control

const CARD_REWARDS = preload("res://scenes/ui/card_rewards.tscn")
const REWARD_BUTTON = preload("res://scenes/ui/reward_button.tscn")
const GOLD_ICON := preload("res://art/Cache10.png")
const GOLD_TEXT := "%s cache"
const CARD_ICON := preload("res://art/rarity.png")
const CARD_TEXT := "New Card"

@export var run_stats: RunStats
@export var character_stats: CharacterStats
@export var thread_handler: ThreadHandler

@onready var rewards: VBoxContainer = %Rewards
@onready var claim_all_button: Button = %ClaimAllButton
@onready var continue_button: Button = %ContinueButton
@onready var feedback_label: Label = %FeedbackLabel

var card_reward_total_weight := 0.0
var card_rarity_weights := {
	Card.Rarity.COMMON: 0.0,
	Card.Rarity.UNCOMMON: 0.0,
	Card.Rarity.RARE: 0.0
}

var pending_gold := 0
var pending_threads: Array[ThreadPassive] = []
var has_card_reward := false
var rewards_claimed := false
var rewards_exited := false


func _ready() -> void:
	for node: Node in rewards.get_children():
		node.queue_free()
	
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Initially hide continue button and feedback
	continue_button.hide()
	feedback_label.hide()


func add_gold_reward(amount: int) -> void:
	pending_gold += amount
	
	var gold_reward := REWARD_BUTTON.instantiate() as RewardButton
	gold_reward.reward_icon = GOLD_ICON
	gold_reward.reward_text = GOLD_TEXT % amount
	# Don't connect pressed - it will be claimed by Claim All button
	rewards.add_child.call_deferred(gold_reward)


func add_thread_award(thread: ThreadPassive) -> void:
	if not thread:
		return
	
	pending_threads.append(thread)
	
	var thread_reward := REWARD_BUTTON.instantiate() as RewardButton
	thread_reward.reward_icon = thread.icon
	thread_reward.reward_text = thread.thread_name
	# Don't connect pressed - it will be claimed by Claim All button
	rewards.add_child.call_deferred(thread_reward)


func add_card_reward() -> void:
	has_card_reward = true
	
	var card_reward := REWARD_BUTTON.instantiate() as RewardButton
	card_reward.reward_icon = CARD_ICON
	card_reward.reward_text = CARD_TEXT
	# Don't connect pressed - card selection will be shown by Claim All button
	rewards.add_child.call_deferred(card_reward)


func _on_claim_all_pressed() -> void:
	if rewards_claimed:
		return
	
	rewards_claimed = true
	claim_all_button.hide()
	
	# Clear all reward buttons from display
	for node: Node in rewards.get_children():
		node.queue_free()
	
	# Claim all gold
	if pending_gold > 0:
		_claim_gold()
	
	# Claim all threads
	for thread in pending_threads:
		_claim_thread(thread)
	
	# Show feedback animation
	await _show_feedback_animation()
	
	# If there's a card reward, show card selection
	if has_card_reward:
		_show_card_rewards()
	else:
		# No card reward, just show continue button
		continue_button.show()


func _claim_gold() -> void:
	if run_stats:
		run_stats.gold += pending_gold


func _claim_thread(thread: ThreadPassive) -> void:
	if thread_handler:
		thread_handler.add_thread(thread)


func _show_feedback_animation() -> void:
	feedback_label.show()
	feedback_label.modulate = Color.TRANSPARENT
	
	var feedback_text := ""
	
	if pending_gold > 0:
		feedback_text += "+%d Cache\n" % pending_gold
	
	for thread in pending_threads:
		feedback_text += "+%s\n" % thread.thread_name
	
	feedback_label.text = feedback_text.strip_edges()
	
	# Fade in animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(feedback_label, "modulate", Color.WHITE, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(feedback_label, "modulate", Color.TRANSPARENT, 0.3)
	
	await tween.finished
	feedback_label.hide()


func _show_card_rewards() -> void:
	if not run_stats or not character_stats:
		continue_button.show()
		return
	
	var card_rewards := CARD_REWARDS.instantiate() as CardRewards
	add_child(card_rewards)
	card_rewards.card_reward_selected.connect(_on_card_reward_taken)
	
	var card_reward_array: Array[Card] = []
	var available_cards: Array[Card] = character_stats.draftable_cards.duplicate_cards()
	
	# Generate only the number of cards specified by run_stats.card_rewards
	for i in run_stats.card_rewards:
		_setup_card_chances()
		var roll := RNG.instance.randf_range(0.0, card_reward_total_weight)
		
		for rarity: Card.Rarity in card_rarity_weights:
			if card_rarity_weights[rarity] > roll:
				_modify_weights(rarity)
				var picked_card := _get_random_available_card(available_cards, rarity)
				card_reward_array.append(picked_card)
				available_cards.erase(picked_card)
				break

	card_rewards.rewards = card_reward_array
	card_rewards.show()


func _setup_card_chances() -> void:
	card_reward_total_weight = run_stats.common_weight + run_stats.uncommon_weight + run_stats.rare_weight
	card_rarity_weights[Card.Rarity.COMMON] = run_stats.common_weight
	card_rarity_weights[Card.Rarity.UNCOMMON] = run_stats.common_weight + run_stats.uncommon_weight
	card_rarity_weights[Card.Rarity.RARE] = card_reward_total_weight


func _modify_weights(rarity_rolled: Card.Rarity) -> void:
	if rarity_rolled == Card.Rarity.RARE:
		run_stats.rare_weight = RunStats.BASE_RARE_WEIGHT
	else:
		run_stats.rare_weight = clampf(run_stats.rare_weight + 0.3, run_stats.BASE_RARE_WEIGHT, 5.0)


func _get_random_available_card(available_cards: Array[Card], with_rarity: Card.Rarity) -> Card:
	var all_possible_cards := available_cards.filter(
		func(card: Card):
			return card.rarity == with_rarity
	)
	return RNG.array_pick_random(all_possible_cards)


func _on_card_reward_taken(card: Card) -> void:
	if rewards_exited:
		return
	rewards_exited = true
	
	if card and character_stats:
		character_stats.deck.add_card(card)
		Events.card_reward_selected.emit(card)
	
	# Card reward is the final step — exit battle directly instead of
	# showing a redundant Continue button.
	Events.battle_reward_exited.emit()


func _on_continue_pressed() -> void:
	if rewards_exited:
		return
	rewards_exited = true
	Events.battle_reward_exited.emit()
