class_name ShopUI1
extends Control

# Emitted when the player clicks the vending machine (triggers zoom-in to UI2).
signal machine_clicked()
# Emitted when the player clicks the Leave button.
signal leave_pressed()

@onready var machine_button: TextureButton = %MachineButton
@onready var leave_button: Button          = %LeaveButton
@onready var viewport_container: SubViewportContainer = %ViewportContainer


func _ready() -> void:
	machine_button.pressed.connect(func(): machine_clicked.emit())
	leave_button.pressed.connect(func(): leave_pressed.emit())


# Called by Shop to show a visual indicator when there are uncollected tray items.
func set_tray_indicator(has_items: bool) -> void:
	var indicator := get_node_or_null("%TrayIndicator")
	if indicator:
		indicator.visible = has_items
