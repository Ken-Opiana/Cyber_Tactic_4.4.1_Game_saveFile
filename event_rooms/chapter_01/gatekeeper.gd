extends EventRoom

# ─────────────────────────────────────────────────────────────────────────
# THE GATEKEEPER
#
# A reprogrammed security checkpoint blocks the corridor. Three options:
#
#   1. Pay the Toll     → Lose ALL gold, safe passage
#   2. Fight Through    → Lose 25% current HP, gain gold + 1 Uncommon card
#   3. Use Phantom Proxy → Remove 1 SKILL card from deck, gain Rare card + gold
# ─────────────────────────────────────────────────────────────────────────

@onready var texture_rect: TextureRect             = %EventImage
@onready var intro_screen: VBoxContainer           = %IntroScreen
@onready var event_menu: VBoxContainer             = %EventMenu
@onready var event_aftermath: VBoxContainer        = %EventAfterMath
@onready var event_title_label: Label              = %EventTitleLabel
@onready var event_description: RichTextLabel      = %EventDescription
@onready var start_button: EventRoomButton         = %StartButton
@onready var pay_button: EventRoomButton           = %PayButton
@onready var fight_button: EventRoomButton         = %FightButton
@onready var proxy_button: EventRoomButton         = %ProxyButton
@onready var aftermath_text: RichTextLabel         = %AftermathText

var stats_tracker: RunStatsTracker

# Tuning
const FIGHT_HP_COST_PCT  := 0.25  # 25% of CURRENT HP
const FIGHT_GOLD_REWARD  := 60
const PROXY_GOLD_REWARD  := 30

const EVENT_TITLE := "The Gatekeeper"
const EVENT_INTRO := \
"""[center]The corridor narrows. At the end stands a corrupted security checkpoint — a system protocol the Rogue Hacker reprogrammed and left to guard the path.

It responds to three things: payment, force, or a valid credential.

[color=yellow]"It still checks identities,"[/color] Kortica says quietly.
[color=yellow]"It just doesn't know whose side it's on anymore."[/color][/center]"""


func setup() -> void:
	_show_intro()
	start_button.event_button_callback = _start_event
	pay_button.event_button_callback   = _on_pay_pressed
	fight_button.event_button_callback = _on_fight_pressed
	proxy_button.event_button_callback = _on_proxy_pressed


func _show_intro() -> void:
	event_title_label.text = EVENT_TITLE
	event_description.text = EVENT_INTRO
	intro_screen.show()
	event_menu.hide()
	event_aftermath.hide()


func _start_event() -> void:
	intro_screen.hide()
	event_aftermath.hide()
	event_menu.show()
	_refresh_button_states()


func _refresh_button_states() -> void:
	# 1. Pay the toll — only enabled if player actually has gold
	pay_button.disabled = run_stats.gold <= 0
	pay_button.text = "Pay the toll (lose all %d cache)" % run_stats.gold
	if pay_button.disabled:
		pay_button.text = "Pay the toll  —  no credits"

	# 2. Fight — blocked if it would kill the player
	var hp_cost := _calculate_fight_hp_cost()
	fight_button.disabled = character_stats.health <= hp_cost
	fight_button.text = "Fight your way through (lose %d HP, +%d gold + Uncommon card)" \
			% [hp_cost, FIGHT_GOLD_REWARD]
	if fight_button.disabled:
		fight_button.text += "  —  too risky"

	# 3. Phantom Proxy — requires a Skill card AND a deck of more than 1
	var has_skill := _player_has_card_of_type(Card.Type.SKILL)
	var deck_too_small := character_stats.deck.cards.size() <= 1
	proxy_button.disabled = not has_skill or deck_too_small
	proxy_button.text = "Use Phantom Proxy (sacrifice 1 Skill card, +%d cache + Rare card)" % PROXY_GOLD_REWARD
	if proxy_button.disabled:
		proxy_button.text += "  —  no Skill card available"


# ─── CHOICES ──────────────────────────────────────────────────────────

func _on_pay_pressed() -> void:
	var paid := run_stats.gold
	run_stats.gold = 0

	var result := "[center][color=cyan]Safe passage.[/color]\n\n"
	result += "You hand over [color=gold]%d cache[/color] — every credit you have. " % paid
	result += "The Gatekeeper scans the transfer, pauses, and steps aside.\n\n"
	result += "[color=gray]A checkpoint that accepts bribes isn't really a checkpoint.\n"
	result += "It's just a door with a price tag.[/color][/center]"
	_show_aftermath(result)


func _on_fight_pressed() -> void:
	var hp_cost := _calculate_fight_hp_cost()
	character_stats.take_pure_damage(hp_cost)
	run_stats.gold += FIGHT_GOLD_REWARD

	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.UNCOMMON)

	var result := "[center][color=orange]You forced it down.[/color]\n\n"
	result += "The Gatekeeper hit hard before it went offline. You took [color=red]%d damage[/color].\n" % hp_cost
	result += "Recovered [color=gold]%d cache[/color] from its stored data.\n" % FIGHT_GOLD_REWARD

	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Found in its cache: [color=aqua]%s[/color]  ([color=aqua]Uncommon[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]" % reward.real_world_text

	result += "[/center]"
	_show_aftermath(result)


func _on_proxy_pressed() -> void:
	var removed: Card = _remove_random_card_of_type(Card.Type.SKILL)
	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.RARE)
	run_stats.gold += PROXY_GOLD_REWARD

	var result := "[center][color=cyan]Clean pass.[/color]\n\n"
	if removed:
		result += "Spent: [color=#5cf]%s[/color] — its credentials masked your identity.\n" % removed.name
	result += "The Gatekeeper scanned a valid user. Green light. It stepped aside.\n"
	result += "Found in its pocket: [color=gold]%d cache[/color]\n" % PROXY_GOLD_REWARD

	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Recovered: [color=gold]%s[/color]  ([color=gold]Rare[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]" % reward.real_world_text
	else:
		var fallback_gold := 50
		run_stats.gold += fallback_gold
		result += "An extra %d cache lay in the pocket too.\n" % fallback_gold

	result += "[/center]"
	_show_aftermath(result)


# ─── HELPERS ──────────────────────────────────────────────────────────

func _show_aftermath(text: String) -> void:
	intro_screen.hide()
	event_menu.hide()
	aftermath_text.text = text
	event_aftermath.show()


func _calculate_fight_hp_cost() -> int:
	return maxi(1, int(round(character_stats.health * FIGHT_HP_COST_PCT)))


func _player_has_card_of_type(card_type: Card.Type) -> bool:
	for card in character_stats.deck.cards:
		if card.type == card_type:
			return true
	return false


func _remove_random_card_of_type(card_type: Card.Type) -> Card:
	var matches: Array[Card] = []
	for card in character_stats.deck.cards:
		if card.type == card_type:
			matches.append(card)
	if matches.is_empty():
		return null
	var picked: Card = matches.pick_random()
	character_stats.deck.remove_card(picked)
	return picked


func _get_random_draftable_by_rarity(rarity: int) -> Card:
	if not character_stats.draftable_cards:
		return null
	var matches: Array[Card] = []
	for card in character_stats.draftable_cards.cards:
		if card.rarity == rarity:
			matches.append(card)
	if matches.is_empty():
		return null
	return (matches.pick_random() as Card).duplicate()


func _mark_discovered(card: Card) -> void:
	if not CardLibrary.is_discovered(card.id):
		CardLibrary.discovered_cards.append(card.id)
