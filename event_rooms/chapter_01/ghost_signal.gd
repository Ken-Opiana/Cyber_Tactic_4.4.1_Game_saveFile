extends EventRoom

# ─────────────────────────────────────────────────────────────────────────
# GHOST SIGNAL
#
# The Rogue Hacker is pinging the network looking for the player.
# Three responses — each requires a different cardplay archetype:
#
#   1. Trace It Back      → Requires SKILL card. Sacrifice it, gain Rare draftable
#   2. Jam the Signal     → Requires ATTACK card. Sacrifice it, gain gold
#   3. Feed False Coords  → No requirement, costs HP, gain Uncommon draftable + gold
# ─────────────────────────────────────────────────────────────────────────

@onready var texture_rect: TextureRect             = %EventImage
@onready var intro_screen: VBoxContainer           = %IntroScreen
@onready var event_menu: VBoxContainer             = %EventMenu
@onready var event_aftermath: VBoxContainer        = %EventAfterMath
@onready var event_title_label: Label              = %EventTitleLabel
@onready var event_description: RichTextLabel      = %EventDescription
@onready var start_button: EventRoomButton         = %StartButton
@onready var trace_button: EventRoomButton         = %TraceButton
@onready var jam_button: EventRoomButton           = %JamButton
@onready var decoy_button: EventRoomButton         = %DecoyButton
@onready var aftermath_text: RichTextLabel         = %AftermathText

var stats_tracker: RunStatsTracker

# Tuning
const JAM_GOLD_REWARD     := 50
const DECOY_GOLD_REWARD   := 25
const DECOY_HP_PCT        := 0.15

const EVENT_TITLE := "Ghost Signal"
const EVENT_INTRO := \
"""[center]Your bracelet vibrates with an incoming ping.

The signal is slow, patient, persistent. It's not from a trapped user. The pattern matches the Rogue Hacker's communication style.

He's either lost track of you — or he wants you to come find him.

[color=yellow]"Three ways to respond,"[/color] Kortica whispers.
[color=yellow]"Each one says something different to him."[/color][/center]"""


func setup() -> void:
	_show_intro()
	start_button.event_button_callback = _start_event
	trace_button.event_button_callback = _on_trace_pressed
	jam_button.event_button_callback   = _on_jam_pressed
	decoy_button.event_button_callback = _on_decoy_pressed


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
	var deck_too_small := character_stats.deck.cards.size() <= 1
	var has_skill := _player_has_card_of_type(Card.Type.SKILL)
	var has_attack := _player_has_card_of_type(Card.Type.ATTACK)

	# 1. Trace It Back — requires a Skill card
	trace_button.disabled = (not has_skill) or deck_too_small
	trace_button.text = "Trace It Back (sacrifice 1 Skill card, +1 Rare card)"
	if trace_button.disabled:
		trace_button.text += "  —  no Skill card available"

	# 2. Jam the Signal — requires an Attack card
	jam_button.disabled = (not has_attack) or deck_too_small
	jam_button.text = "Jam the Signal (sacrifice 1 Attack card, +%d cache)" % JAM_GOLD_REWARD
	if jam_button.disabled:
		jam_button.text += "  —  no Attack card available"

	# 3. Feed False Coordinates — fallback option, costs HP only
	var hp_cost := _calculate_decoy_hp_cost()
	decoy_button.disabled = character_stats.health <= hp_cost
	decoy_button.text = "Feed False Coordinates (lose %d HP, +%d cache + Uncommon card)" \
			% [hp_cost, DECOY_GOLD_REWARD]
	if decoy_button.disabled:
		decoy_button.text += "  —  too risky"


# ─── CHOICES ──────────────────────────────────────────────────────────

func _on_trace_pressed() -> void:
	var removed: Card = _remove_random_card_of_type(Card.Type.SKILL)
	var reward: Card  = _get_random_draftable_by_rarity(Card.Rarity.RARE)

	var result := "[center][color=cyan]Counter-trace successful.[/color]\n\n"
	if removed:
		result += "Spent: [color=#5cf]%s[/color] — its skill pattern lets you follow his signal back to its source.\n\n" % removed.name

	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "You map his last three movements before the signal cuts. Intel recovered: [color=gold]%s[/color] ([color=gold]Rare[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]" % reward.real_world_text
	else:
		var fallback_gold := 70
		run_stats.gold += fallback_gold
		result += "His trail dissolves before you can pin a sector. You salvage [color=gold]%d cache[/color] in routing data from the attempt." % fallback_gold

	result += "[/center]"
	_show_aftermath(result)


func _on_jam_pressed() -> void:
	var removed: Card = _remove_random_card_of_type(Card.Type.ATTACK)
	run_stats.gold += JAM_GOLD_REWARD

	var result := "[center][color=cyan]Signal jammed.[/color]\n\n"
	if removed:
		result += "Spent: [color=red]%s[/color] — its attack burst floods his frequency with noise.\n\n" % removed.name
	result += "His ping dies in a static wash. The channel goes dark. You recover [color=gold]%d cache[/color] in disrupted packet data from the burst.\n\n" % JAM_GOLD_REWARD
	result += "[color=gray]A signal you can't trace is one you silence.\nJamming buys time at the cost of stealth.[/color][/center]"
	_show_aftermath(result)


func _on_decoy_pressed() -> void:
	var hp_cost := _calculate_decoy_hp_cost()
	character_stats.take_pure_damage(hp_cost)
	run_stats.gold += DECOY_GOLD_REWARD

	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.UNCOMMON)

	var result := "[center][color=cyan]Misdirection.[/color]\n\n"
	result += "You respond with fake coordinates — pointing him toward a dead sector on the far side of the network. The setup costs you [color=red]%d HP[/color] in cycle drain.\n\n" % hp_cost
	result += "While he hunts the lie, you move freely. You collect [color=gold]%d cache[/color] on the way out.\n" % DECOY_GOLD_REWARD

	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Found in an unguarded cache: [color=aqua]%s[/color] ([color=aqua]Uncommon[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]" % reward.real_world_text

	result += "[/center]"
	_show_aftermath(result)


# ─── HELPERS ──────────────────────────────────────────────────────────

func _show_aftermath(text: String) -> void:
	intro_screen.hide()
	event_menu.hide()
	aftermath_text.text = text
	event_aftermath.show()


func _calculate_decoy_hp_cost() -> int:
	return maxi(1, int(round(character_stats.max_health * DECOY_HP_PCT)))


func _player_has_card_of_type(card_type: int) -> bool:
	for card in character_stats.deck.cards:
		if card.type == card_type:
			return true
	return false


func _remove_random_card_of_type(card_type: int) -> Card:
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
