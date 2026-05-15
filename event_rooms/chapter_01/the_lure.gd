extends EventRoom

# ─────────────────────────────────────────────────────────────────────────
# THE LURE
#
# A message arrives on the bracelet, signed "KORTICA_SYSTEM_OFFICIAL."
# The real Kortica isn't broadcasting anything. The message offers a free
# system upgrade — all you have to do is click the verify button.
#
# Three responses:
#
#   1. Click the Link   → 25% legit (Rare card + gold + heal)
#                         75% phishing (curse card + HP loss + small gold)
#
#   2. Verify the Sender → Requires SKILL card. Sacrifice it to safely
#                          authenticate. Reward depends on whether it was
#                          real or phishing — but NO curse, NO HP loss.
#
#   3. Delete It        → Small gold reward. Doesn't reveal the truth.
#                         Safe blanket policy: "delete unsolicited messages."
#
# The roll happens once in setup() so all three branches reference the
# same underlying truth. This keeps the educational message consistent:
# you can't tell from looking — only verification reveals reality.
# ─────────────────────────────────────────────────────────────────────────

const CORRUPTED_FILE_CURSE: Card = preload("res://shared_cards/curses_corrupted_file.tres")

@onready var texture_rect: TextureRect             = %EventImage
@onready var intro_screen: VBoxContainer           = %IntroScreen
@onready var event_menu: VBoxContainer             = %EventMenu
@onready var event_aftermath: VBoxContainer        = %EventAfterMath
@onready var event_title_label: Label              = %EventTitleLabel
@onready var event_description: RichTextLabel      = %EventDescription
@onready var start_button: EventRoomButton         = %StartButton
@onready var click_button: EventRoomButton         = %ClickButton
@onready var verify_button: EventRoomButton        = %VerifyButton
@onready var delete_button: EventRoomButton        = %DeleteButton
@onready var aftermath_text: RichTextLabel         = %AftermathText

var stats_tracker: RunStatsTracker

# Tuning
const LEGITIMATE_CHANCE := 0.25  # 25% the message is real
const CLICK_REAL_GOLD     := 40
const CLICK_REAL_HEAL_PCT := 0.15
const CLICK_FAIL_HP_PCT   := 0.20
const CLICK_FAIL_GOLD     := 10
const VERIFY_REAL_GOLD    := 30
const VERIFY_FAKE_GOLD    := 25
const DELETE_GOLD         := 10

# Set during setup — determines what the message *actually is*
var message_is_legitimate: bool = false

const EVENT_TITLE := "The Lure"
const EVENT_INTRO := \
"""[center]Your bracelet pings.

A message from [color=cyan]KORTICA_SYSTEM_OFFICIAL[/color]:

[color=#ddd]> URGENT — Your bracelet firmware is out of date.
> Click the verification link to receive a free upgrade.
> This offer expires in 60 seconds.[/color]

[color=yellow]The real Kortica is standing next to you.
She hasn't sent you anything.[/color][/center]"""


func setup() -> void:
	# Roll the dice once — the message's true nature is now locked
	message_is_legitimate = randf() < LEGITIMATE_CHANCE

	_show_intro()
	start_button.event_button_callback  = _start_event
	click_button.event_button_callback  = _on_click_pressed
	verify_button.event_button_callback = _on_verify_pressed
	delete_button.event_button_callback = _on_delete_pressed


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
	# 1. Click — always available, but warn the player
	var hp_loss := _calculate_click_fail_hp_cost()
	click_button.disabled = character_stats.health <= hp_loss
	click_button.text = "Click the Link (%d%% legit / %d%% phishing — risk: curse + %d HP)" \
			% [int(LEGITIMATE_CHANCE * 100), int((1 - LEGITIMATE_CHANCE) * 100), hp_loss]
	if click_button.disabled:
		click_button.text += "  —  too risky"

	# 2. Verify — needs a SKILL card and a deck big enough to lose one
	var has_skill := _player_has_card_of_type(Card.Type.SKILL)
	var deck_too_small := character_stats.deck.cards.size() <= 1
	verify_button.disabled = not has_skill or deck_too_small
	verify_button.text = "Verify the Sender (sacrifice 1 Skill card — no curse risk)"
	if verify_button.disabled:
		verify_button.text += "  —  no Skill card available"

	# 3. Delete — always available, small reward
	delete_button.disabled = false
	delete_button.text = "Delete the Message (+%d gold, no further info)" % DELETE_GOLD


# ─── CHOICES ──────────────────────────────────────────────────────────

func _on_click_pressed() -> void:
	if message_is_legitimate:
		_resolve_click_legitimate()
	else:
		_resolve_click_phishing()


func _resolve_click_legitimate() -> void:
	run_stats.gold += CLICK_REAL_GOLD
	var heal_amount := _calculate_heal_amount()
	character_stats.health = mini(character_stats.health + heal_amount, character_stats.max_health)
	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.RARE)

	var result := "[center][color=green]The message was real.[/color]\n\n"
	result += "Against the odds, the firmware upgrade was a legitimate system patch. Your bracelet receives a clean update.\n\n"
	result += "[color=green]+%d HP[/color]\n" % heal_amount
	result += "[color=gold]+%d gold[/color]\n" % CLICK_REAL_GOLD

	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Granted: [color=gold]%s[/color] ([color=gold]Rare[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]\n\n" % reward.real_world_text

	result += "[color=yellow]\"You got lucky,\"[/color] Kortica says.\n"
	result += "[color=yellow]\"Most of the time, that link doesn't end this well.\"[/color][/center]"
	_show_aftermath(result)


func _resolve_click_phishing() -> void:
	var hp_loss := _calculate_click_fail_hp_cost()
	character_stats.take_pure_damage(hp_loss)
	run_stats.gold += CLICK_FAIL_GOLD

	# Inject the curse card — this is the phishing payload
	var curse: Card = CORRUPTED_FILE_CURSE.duplicate()
	character_stats.deck.add_card(curse)

	var result := "[center][color=red]It was phishing.[/color]\n\n"
	result += "The instant you tap the verification button, your bracelet seizes. The 'upgrade' was a payload disguised as a system message. The Rogue Hacker spoofed Kortica's signature to get past your filters.\n\n"
	result += "[color=red]Damage taken: %d HP[/color]\n" % hp_loss
	result += "Recovered from the attacker's staging packet: [color=gold]+%d gold[/color]\n\n" % CLICK_FAIL_GOLD
	result += "Injected into your deck: [color=red]%s[/color] [color=red](Curse)[/color]\n\n" % curse.name
	result += "[color=yellow]\"That's what spoofing does,\"[/color] Kortica says quietly.\n"
	result += "[color=yellow]\"They wear someone you trust like a mask.\nThe message looks right because it's supposed to look right.\"[/color][/center]"
	_show_aftermath(result)


func _on_verify_pressed() -> void:
	var removed: Card = _remove_random_card_of_type(Card.Type.SKILL)

	if message_is_legitimate:
		_resolve_verify_legitimate(removed)
	else:
		_resolve_verify_phishing(removed)


func _resolve_verify_legitimate(removed: Card) -> void:
	run_stats.gold += VERIFY_REAL_GOLD
	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.RARE)

	var result := "[center][color=cyan]Verified clean.[/color]\n\n"
	if removed:
		result += "Spent: [color=#5cf]%s[/color] to authenticate the sender's signature.\n\n" % removed.name
	result += "Cross-checking the cryptographic stamp confirms it — the message was a real system patch. You apply the upgrade safely.\n\n"
	result += "[color=gold]+%d gold[/color]\n" % VERIFY_REAL_GOLD
	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Granted: [color=gold]%s[/color] ([color=gold]Rare[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]\n\n" % reward.real_world_text
	result += "[color=gray]Verification cost you a card.\nIt did not cost you everything else.[/color][/center]"
	_show_aftermath(result)


func _resolve_verify_phishing(removed: Card) -> void:
	run_stats.gold += VERIFY_FAKE_GOLD
	var reward: Card = _get_random_draftable_by_rarity(Card.Rarity.UNCOMMON)

	var result := "[center][color=cyan]Phishing attempt caught.[/color]\n\n"
	if removed:
		result += "Spent: [color=#5cf]%s[/color] to pull the cryptographic signature.\n\n" % removed.name
	result += "The signature is wrong. The header routes through a node Kortica doesn't recognize. The 'KORTICA_SYSTEM_OFFICIAL' tag is a fake — spoofed by someone who knew what to imitate.\n\n"
	result += "You bounce the message back as a flagged trap, capturing the attacker's staging tools in the process.\n\n"
	result += "[color=gold]+%d gold[/color]\n" % VERIFY_FAKE_GOLD
	if reward:
		character_stats.deck.add_card(reward)
		_mark_discovered(reward)
		result += "Recovered: [color=aqua]%s[/color] ([color=aqua]Uncommon[/color])\n\n" % reward.name
		result += "[color=gray]%s[/color]\n\n" % reward.real_world_text
	result += "[color=yellow]\"That's how you do it,\"[/color] Kortica says.\n"
	result += "[color=yellow]\"You check before you click. Every time.\"[/color][/center]"
	_show_aftermath(result)


func _on_delete_pressed() -> void:
	run_stats.gold += DELETE_GOLD

	var result := "[center][color=cyan]Deleted.[/color]\n\n"
	result += "You drag the message into the trash channel without opening it. Whatever it was — real upgrade or buried payload — it's gone.\n\n"
	result += "[color=gold]+%d gold[/color]\n\n" % DELETE_GOLD
	result += "[color=yellow]\"Most messages you didn't ask for aren't worth the risk,\"[/color] Kortica says.\n"
	result += "[color=yellow]\"You'll never know what that one was. That's fine. You're still alive.\"[/color]\n\n"
	result += "[color=gray]The safest policy for unsolicited messages\nis the one that costs you nothing.[/color][/center]"
	_show_aftermath(result)


# ─── HELPERS ──────────────────────────────────────────────────────────

func _show_aftermath(text: String) -> void:
	intro_screen.hide()
	event_menu.hide()
	aftermath_text.text = text
	event_aftermath.show()


func _calculate_click_fail_hp_cost() -> int:
	return maxi(1, int(round(character_stats.max_health * CLICK_FAIL_HP_PCT)))


func _calculate_heal_amount() -> int:
	return maxi(1, int(round(character_stats.max_health * CLICK_REAL_HEAL_PCT)))


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
