extends EventRoom

# ─────────────────────────────────────────────────────────────────────────
# THE LOCKED FILES
#
# Ransomware has hit your sector. Three responses:
#
#   1. Pull the Plug   → Lose small gold + 1 random non-attack card (safe)
#   2. Pay the Ransom  → Lose 50 gold (guaranteed safety, but funds the attacker)
#   3. Call the Bluff  → 30% gain small gold / 70% lose HP + 1 random card
# ─────────────────────────────────────────────────────────────────────────

@onready var texture_rect: TextureRect             = %EventImage
@onready var intro_screen: VBoxContainer           = %IntroScreen
@onready var event_menu: VBoxContainer             = %EventMenu
@onready var event_aftermath: VBoxContainer        = %EventAfterMath
@onready var event_title_label: Label              = %EventTitleLabel
@onready var event_description: RichTextLabel      = %EventDescription
@onready var start_button: EventRoomButton         = %StartButton
@onready var pull_plug_button: EventRoomButton     = %PullPlugButton
@onready var pay_button: EventRoomButton           = %PayButton
@onready var bluff_button: EventRoomButton         = %BluffButton
@onready var aftermath_text: RichTextLabel         = %AftermathText

var stats_tracker: RunStatsTracker

# Tuning
const RANSOM_COST          := 50
const PULL_PLUG_GOLD_LOSS  := 15
const BLUFF_SUCCESS_CHANCE := 0.30   # ransomware rarely bluffs — that's the lesson
const BLUFF_HP_PCT         := 0.30
const BLUFF_GOLD_REWARD    := 20

const EVENT_TITLE := "The Locked Files"
const EVENT_INTRO := \
"""[center]Alarms.

Every file in this sector just got wrapped in a digital padlock. A message scrolls across your bracelet:

[color=red]"Pay 50 cache within 3 minutes or your files get deleted.
— GHOST"[/color]

[color=yellow]"Three real options,"[/color] Kortica says.
[color=yellow]"None of them are easy."[/color][/center]"""


func setup() -> void:
	_show_intro()
	start_button.event_button_callback     = _start_event
	pull_plug_button.event_button_callback = _on_pull_plug_pressed
	pay_button.event_button_callback       = _on_pay_pressed
	bluff_button.event_button_callback     = _on_bluff_pressed


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
	# 1. Pull the plug — safe, needs at least one card in deck to lose
	var deck_too_small := character_stats.deck.cards.size() <= 1
	pull_plug_button.disabled = deck_too_small
	pull_plug_button.text = "Pull the Plug (lose %d cache + 1 card)" % PULL_PLUG_GOLD_LOSS
	if pull_plug_button.disabled:
		pull_plug_button.text += "  —  deck too small"

	# 2. Pay the ransom — needs enough gold
	pay_button.disabled = run_stats.gold < RANSOM_COST
	pay_button.text = "Pay the Ransom (-%d cache, guaranteed safe)" % RANSOM_COST
	if pay_button.disabled:
		pay_button.text += "  —  not enough cache"

	# 3. Call the bluff — always available but warns the player
	var hp_cost := _calculate_bluff_hp_cost()
	bluff_button.disabled = character_stats.health <= hp_cost
	bluff_button.text = "Call the Bluff (%d%% chance to win, otherwise lose %d HP + 1 card)" \
			% [int(BLUFF_SUCCESS_CHANCE * 100), hp_cost]
	if bluff_button.disabled:
		bluff_button.text += "  —  too risky"


# ─── CHOICES ──────────────────────────────────────────────────────────

func _on_pull_plug_pressed() -> void:
	var lost := mini(PULL_PLUG_GOLD_LOSS, run_stats.gold)
	run_stats.gold -= lost

	# Prefer to drop a non-attack card — the player's "files" go first
	var removed: Card = _remove_random_card_excluding_type(Card.Type.ATTACK)
	if removed == null:
		removed = _remove_random_card()

	var result := "[center][color=cyan]Containment.[/color]\n\n"
	result += "You ripped your connection from the network before the lock finished propagating. The ransomware kept running — but in an isolated bubble.\n\n"
	if removed:
		result += "Lost to the disconnect: [color=red]%s[/color]\n" % removed.name
	result += "Recovery cost: [color=red]%d cache[/color]\n\n" % lost
	result += "[color=gray]Isolation beats negotiation every time.\nYou lost a little — you would have lost everything if you waited.[/color][/center]"
	_show_aftermath(result)


func _on_pay_pressed() -> void:
	run_stats.gold -= RANSOM_COST

	var result := "[center][color=cyan]You paid GHOST.[/color]\n\n"
	result += "Transferred [color=gold]%d cache[/color]. The decryption key arrives. Files released.\n\n" % RANSOM_COST
	result += "[color=yellow]Kortica is quiet for a long moment.[/color]\n\n"
	result += "[color=yellow]\"You just funded the next person they hit. And they marked you as a payer. They'll be back.\"[/color]\n\n"
	result += "[color=gray]Paying ransoms works once.\nIt almost never works twice.[/color][/center]"
	_show_aftermath(result)


func _on_bluff_pressed() -> void:
	var success := randf() < BLUFF_SUCCESS_CHANCE

	if success:
		run_stats.gold += BLUFF_GOLD_REWARD

		var result := "[center][color=green]The timer ran out — and nothing happened.[/color]\n\n"
		result += "You held steady, file by file, while the countdown burned to zero. GHOST was bluffing this time — or didn't follow through.\n\n"
		result += "Recovered from the leftover staging area: [color=gold]+%d cache[/color]\n\n" % BLUFF_GOLD_REWARD
		result += "[color=yellow]\"Don't make a habit of this,\"[/color] Kortica says quietly.\n"
		result += "[color=yellow]\"Most of them aren't bluffing.\"[/color][/center]"
		_show_aftermath(result)
	else:
		var hp_cost := _calculate_bluff_hp_cost()
		character_stats.take_pure_damage(hp_cost)
		var removed: Card = _remove_random_card()

		var result := "[center][color=red]The timer hit zero.[/color]\n\n"
		result += "GHOST wasn't bluffing. The deletion cascade tore through your sector before you could pull back.\n\n"
		result += "You took [color=red]%d damage[/color].\n" % hp_cost
		if removed:
			result += "Lost in the wipe: [color=red]%s[/color]\n\n" % removed.name
		result += "[color=gray]A countdown on a screen isn't a negotiation.\nIt's a timer on a deletion script that's already running.[/color][/center]"
		_show_aftermath(result)


# ─── HELPERS ──────────────────────────────────────────────────────────

func _show_aftermath(text: String) -> void:
	intro_screen.hide()
	event_menu.hide()
	aftermath_text.text = text
	event_aftermath.show()


func _calculate_bluff_hp_cost() -> int:
	return maxi(1, int(round(character_stats.health * BLUFF_HP_PCT)))


func _remove_random_card() -> Card:
	if character_stats.deck.cards.is_empty():
		return null
	var picked: Card = character_stats.deck.cards.pick_random()
	character_stats.deck.remove_card(picked)
	return picked


func _remove_random_card_excluding_type(card_type: int) -> Card:
	var matches: Array[Card] = []
	for card in character_stats.deck.cards:
		if card.type != card_type:
			matches.append(card)
	if matches.is_empty():
		return null
	var picked: Card = matches.pick_random()
	character_stats.deck.remove_card(picked)
	return picked
