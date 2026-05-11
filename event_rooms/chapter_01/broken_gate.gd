extends EventRoom

# ─────────────────────────────────────────────────────────────────────────
# THE BROKEN GATE
#
# A sealed gate cracked open by the worm attack blocks the path.
# Three ways through, none of them clean:
#
#   1. Blast It Open    → Lose 1 random ATTACK card, gain a Rare draftable card
#   2. Search the Edges → Safe gold pickup (no cost)
#   3. Force the Bracelet → Lose HP, gain an Uncommon draftable card + small gold
# ─────────────────────────────────────────────────────────────────────────

@onready var texture_rect: TextureRect             = %EventImage
@onready var intro_screen: VBoxContainer           = %IntroScreen
@onready var event_menu: VBoxContainer             = %EventMenu
@onready var event_aftermath: VBoxContainer        = %EventAfterMath
@onready var event_title_label: Label              = %EventTitleLabel
@onready var event_description: RichTextLabel      = %EventDescription
@onready var start_button: EventRoomButton         = %StartButton
@onready var blast_button: EventRoomButton         = %BlastButton
@onready var search_button: EventRoomButton        = %SearchButton
@onready var force_button: EventRoomButton         = %ForceButton
@onready var aftermath_text: RichTextLabel         = %AftermathText

# Mirrors the pattern in the quiz events so run.gd's stats_tracker
# assignment lands cleanly without needing changes to event_room.gd
var stats_tracker: RunStatsTracker

# Tuning — change these here, not in the callbacks
const SEARCH_GOLD_REWARD := 25
const FORCE_GOLD_REWARD  := 20
const FORCE_HP_COST_PCT  := 0.15  # 15% of max HP

const EVENT_TITLE := "The Broken Gate"
const EVENT_INTRO := \
"""[center]A sealed gate blocks the only path forward.

The worm attack cracked it open — not enough to walk through, but enough to see what's on the other side. A glowing cache of tools the Rogue Hacker left behind in his rush deeper into the system.

[color=yellow]"Three ways through,"[/color] Kortica says.
[color=yellow]"None of them are clean."[/color][/center]"""


func setup() -> void:
	_show_intro()
	start_button.event_button_callback = _start_event

	# Wire up the three choices now so the button text/disabled state
	# is correct when the menu first appears
	blast_button.event_button_callback  = _on_blast_pressed
	search_button.event_button_callback = _on_search_pressed
	force_button.event_button_callback  = _on_force_pressed


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


# Disable choices the player can't actually fulfill so they aren't
# stuck staring at a dead-end option.
func _refresh_button_states() -> void:
	var has_attack_card := _player_has_card_of_type(Card.Type.ATTACK)
	var deck_too_small  := character_stats.deck.cards.size() <= 1

	blast_button.disabled  = not has_attack_card or deck_too_small
	blast_button.text      = "Blast it open (sacrifice 1 Attack card)"
	if blast_button.disabled:
		blast_button.text += "  —  unavailable"

	search_button.disabled = false
	search_button.text     = "Search the edges (+%d cache)" % SEARCH_GOLD_REWARD

	# Force the bracelet costs HP — block it if it would kill the player
	var hp_cost := _calculate_force_hp_cost()
	force_button.disabled = character_stats.health <= hp_cost
	force_button.text     = "Force the bracelet (lose %d HP, +%d cache + 1 Uncommon card)" \
			% [hp_cost, FORCE_GOLD_REWARD]
	if force_button.disabled:
		force_button.text += "  —  too risky"


# ─── CHOICES ──────────────────────────────────────────────────────────

func _on_blast_pressed() -> void:
	var removed: Card = _remove_random_card_of_type(Card.Type.ATTACK)
	var reward: Card  = _get_random_draftable_by_rarity(Card.Rarity.RARE)

	var result := "[center][color=cyan]Gate shattered.[/color]\n\n"

	if removed:
		result += "Sacrificed: [color=red]%s[/color]\n" % removed.name
	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Recovered from cache: [color=gold]%s[/color]  ([color=gold]Rare[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]" % reward.real_world_text
	else:
		# Fallback if no rare draftable exists — give gold so player isn't punished
		var fallback_gold := 80
		run_stats.gold += fallback_gold
		result += "The cache was already looted, but you found %d cache in the debris." % fallback_gold

	result += "[/center]"
	_show_aftermath(result)


func _on_search_pressed() -> void:
	run_stats.gold += SEARCH_GOLD_REWARD

	var result := "[center][color=cyan]Safe choice.[/color]\n\n"
	result += "You comb through the debris around the gate and pull %d cache worth of data fragments out of the wreckage.\n\n" % SEARCH_GOLD_REWARD
	result += "[color=gray]Sometimes the smart move is the quiet one.[/color][/center]"
	_show_aftermath(result)


func _on_force_pressed() -> void:
	var hp_cost := _calculate_force_hp_cost()
	character_stats.take_pure_damage(hp_cost)
	run_stats.gold += FORCE_GOLD_REWARD

	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.UNCOMMON)

	var result := "[center][color=orange]You forced it open.[/color]\n\n"
	result += "The system fought back. You lost [color=red]%d HP[/color] prying the gate.\n" % hp_cost
	result += "Found %d cache inside.\n" % FORCE_GOLD_REWARD

	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Recovered: [color=aqua]%s[/color]  ([color=aqua]Uncommon[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]" % reward.real_world_text

	result += "[/center]"
	_show_aftermath(result)


# ─── HELPERS ──────────────────────────────────────────────────────────

func _show_aftermath(text: String) -> void:
	intro_screen.hide()
	event_menu.hide()
	aftermath_text.text = text
	event_aftermath.show()


func _calculate_force_hp_cost() -> int:
	return maxi(1, int(round(character_stats.max_health * FORCE_HP_COST_PCT)))


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
