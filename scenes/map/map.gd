class_name Map
extends Node2D

const MAP_ROOM = preload("res://scenes/map/map_room.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")

# How many floors are shown per page.
const FLOORS_PER_PAGE := 6

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D

var map_data: Array[Array]
var floors_climbed: int
var last_room: Room


func generate_new_map() -> void:
	floors_climbed = 0
	map_data = map_generator.generate_map()
	create_map()
	_snap_camera_to_current_page()


func load_map(map: Array[Array], floors_completed: int, last_room_climbed: Room) -> void:
	floors_climbed = floors_completed
	map_data = map
	last_room = last_room_climbed
	create_map()
	
	if floors_climbed > 0:
		unlock_next_rooms()
	else:
		unlock_floor()
	
	_snap_camera_to_current_page()


func create_map() -> void:
	for current_floor: Array in map_data:
		for room: Room in current_floor:
			
			if room.next_rooms.size() > 0:
				_spawn_room(room)
	
	# Boss room has no next room but we need to spawn it.
	var middle := floori(MapGenerator.MAP_WIDTH * 0.5)
	_spawn_room(map_data[MapGenerator.FLOORS-1][middle])
	
	var map_width_pixels := MapGenerator.X_DIST * (MapGenerator.MAP_WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
	visuals.position.y = get_viewport_rect().size.y / 2


func unlock_floor(which_floor: int = floors_climbed) -> void:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room.row == which_floor:
			map_room.available = true


func unlock_next_rooms() -> void:
	for map_room: MapRoom in rooms.get_children():
		if last_room.next_rooms.has(map_room.room):
			map_room.available = true


func show_map() -> void:
	show()
	camera_2d.enabled = true


func hide_map() -> void:
	hide()
	camera_2d.enabled = false


func _spawn_room(room: Room) -> void:
	var new_map_room := MAP_ROOM.instantiate() as MapRoom
	rooms.add_child(new_map_room)
	new_map_room.room = room
	new_map_room.clicked.connect(_on_map_room_clicked)
	new_map_room.selected.connect(_on_map_room_selected)
	_connect_lines(room)
	
	if room.selected and room.row < floors_climbed:
		new_map_room.show_selected()


func _connect_lines(room: Room) -> void:
	if room.next_rooms.is_empty():
		return
		
	for next: Room in room.next_rooms:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(room.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)


func _on_map_room_clicked(room: Room) -> void:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room.row == room.row:
			map_room.available = false


func _on_map_room_selected(room: Room) -> void:
	last_room = room
	floors_climbed += 1
	_snap_camera_to_current_page()
	Events.map_exited.emit(room)


# ---------------------------------------------------------------------------
# Paged camera logic
# ---------------------------------------------------------------------------
# Page 0: floors 1-6   (rows 0-5)   -> camera y =   0
# Page 1: floors 7-12  (rows 6-11)  -> camera y = -240  (6 * Y_DIST)
# Page 2: floors 13-15 (rows 12-14) -> camera y = -480  (12 * Y_DIST)
#
# The page is derived from floors_climbed so loading a save mid-run lands the
# camera on the correct page automatically.

func _get_current_page() -> int:
	var max_page := _get_max_page()
	return clampi(floors_climbed / FLOORS_PER_PAGE, 0, max_page)


func _get_max_page() -> int:
	# ceil(FLOORS / FLOORS_PER_PAGE) - 1
	return ceili(float(MapGenerator.FLOORS) / float(FLOORS_PER_PAGE)) - 1


func _snap_camera_to_current_page() -> void:
	var page := _get_current_page()
	camera_2d.position.y = -page * FLOORS_PER_PAGE * MapGenerator.Y_DIST
