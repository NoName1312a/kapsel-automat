extends Node
## Testspiel: schreibt user://gestartet.txt mit dem eigenen Projektnamen und beendet sich.

func _ready() -> void:
	var f := FileAccess.open("user://gestartet.txt", FileAccess.WRITE)
	f.store_string(ProjectSettings.get_setting("application/config/name"))
	f.close()
	get_tree().quit()
