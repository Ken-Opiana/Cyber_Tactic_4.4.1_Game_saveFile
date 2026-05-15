extends Node

# Holds CodexEntry resources by id
var entries: Dictionary = {}

const _FORCE_INCLUDE_CODEX := [
	preload("res://custom_resources/codex/malware_codex.tres"),
	preload("res://custom_resources/codex/virus_codex.tres"),
	preload("res://custom_resources/codex/trojan_codex.tres"),
	preload("res://custom_resources/codex/hacker_codex.tres")
]

signal entry_unlocked(id: String)

func _ready():
	load_all_entries()
	load_state()


func load_all_entries() -> void:
	entries.clear()
	var dir = DirAccess.open("res://resources/codex")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := "res://resources/codex/%s" % file_name
				var res = ResourceLoader.load(path)
				if res:
					entries[res.id] = res
				else:
					printerr("CodexManager: FAILED to load resource:", path)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Fallback: if nothing loaded, use forced preloads (ensures exported builds have entries)
	if entries.size() == 0:
		for r in _FORCE_INCLUDE_CODEX:
			if r and r is Resource:
				entries[r.id] = r
		print("CodexManager: loaded entries via _FORCE_INCLUDE_CODEX, count:", entries.size())


# Unlock and save state (now uses MetaProgression instead of SaveGame)
func unlock(id: String) -> void:
	if entries.has(id) and not entries[id].is_unlocked:
		entries[id].is_unlocked = true
		emit_signal("entry_unlocked", id)
		save_state()


# Persist to MetaProgression (permanent across all runs)
func save_state() -> void:
	var meta = MetaProgression.load_meta()
	
	# Clear and rebuild the codex list
	meta.codex_discovered.clear()
	for eid in entries.keys():
		if entries[eid].is_unlocked:
			meta.codex_discovered.append(eid)
	
	meta.save_meta()


# Restore from MetaProgression
func load_state() -> void:
	var meta = MetaProgression.load_meta()
	
	print("CodexManager: Loading state from MetaProgression, unlocked count:", meta.codex_discovered.size())
	
	for eid in meta.codex_discovered:
		print("  Unlocking codex entry:", eid)
		if entries.has(eid):
			entries[eid].is_unlocked = true
