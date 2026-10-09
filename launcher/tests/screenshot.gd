extends SceneTree
## Startet den Launcher, wartet und speichert ein Bildschirmfoto.
## godot --path launcher -s res://tests/screenshot.gd -- --config=<cfg> <out.png> [druecke_hauptknopf]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[1]
	var scene: Control = load("res://launcher.tscn").instantiate()
	root.add_child(scene)
	await create_timer(2.0).timeout
	if args.size() > 2:
		scene._on_main_pressed()
		await create_timer(0.15).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
