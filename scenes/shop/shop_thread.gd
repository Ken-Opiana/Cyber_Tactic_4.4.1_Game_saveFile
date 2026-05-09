class_name ShopThread
extends VBoxContainer

const THREAD_UI = preload("res://scenes/thread_handler/thread_ui.tscn")

@export var thread: ThreadPassive : set = set_thread

@onready var thread_container: CenterContainer = %ThreadContainer
@onready var price_label: Label                = %PriceLabel
@onready var code_label: Label                 = %CodeLabel

var gold_cost: int = 0


func _ready() -> void:
	pass


# Called by ShopUI2 after instantiation to set all slot data at once.
func setup(p_thread: ThreadPassive, p_cost: int, p_code: String) -> void:
	gold_cost = p_cost
	code_label.text  = p_code
	price_label.text = str(p_cost)
	thread = p_thread


# Call this whenever the player's gold changes to update price label color.
func update_price(new_cost: int) -> void:
	gold_cost = new_cost
	if not _is_sold():
		price_label.text = str(new_cost)


func update_affordability(current_gold: int) -> void:
	if _is_sold():
		return
	if current_gold >= gold_cost:
		price_label.remove_theme_color_override("font_color")
	else:
		price_label.add_theme_color_override("font_color", Color.RED)


func _is_sold() -> bool:
	return price_label.text.is_empty()


func mark_as_sold() -> void:
	# Clear the thread visual and show SOLD OUT text in its place.
	for child in thread_container.get_children():
		child.queue_free()

	var sold_label        := Label.new()
	sold_label.text        = "SOLD\nOUT"
	sold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sold_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	sold_label.add_theme_color_override("font_color", Color.RED)
	sold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sold_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	thread_container.add_child(sold_label)

	price_label.text = ""


func set_thread(new_thread: ThreadPassive) -> void:
	if not is_node_ready():
		await ready

	thread = new_thread

	for child in thread_container.get_children():
		child.queue_free()

	var new_thread_ui := THREAD_UI.instantiate() as ThreadUI
	thread_container.add_child(new_thread_ui)
	new_thread_ui.thread_passive = thread
