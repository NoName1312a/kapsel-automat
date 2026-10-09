extends SceneTree
const OUT := "user://"   # Screenshots landen im Godot-Benutzerordner
func _initialize() -> void:
	_run.call_deferred()
func snap(name: String) -> void:
	await create_timer(0.35).timeout
	root.get_viewport().get_texture().get_image().save_png(OUT + name)
func _run() -> void:
	var game = root.get_node("Game")
	game.reset_game()
	game.coins = 2.5e6
	game.levels = {"hamster": 2, "value": 6, "speed": 3, "tray": 1, "combo": 2, "bulk": 1}
	game.stats["capsules_opened"] = 120
	game.goldmarken = 14
	game.goldmarken_total = 30
	game.prestige_levels = {"p_fusion": 1, "p_spuk": 1}
	for id in ["apfel", "birne", "kirsche", "frosch", "ente", "fuchs", "panda", "einhorn", "brezel", "donut", "taco", "mond", "kraken"]:
		game.owned[id] = randi_range(1, 9)
	game.check_progress()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.0).timeout   # Toasts abklingen lassen
	for i in 5:
		main._advance_crank(1.0, true)
	main.machine.jiggle = 0.0
	await create_timer(0.8).timeout
	main.tray[0].content = {"type": "figure", "figure": game.figures["geisterkoenig"], "blessed": false}
	main._open_first_capsule()
	await create_timer(0.7).timeout
	main.machine.crank_angle = 0.6
	await snap("v3_main.png")
	main.ui._toggle_overlay(main.ui.album_panel)
	await snap("v3_album.png")
	main.ui._toggle_overlay(main.ui.ach_panel)
	await snap("v3_ach.png")
	main.ui._toggle_overlay(main.ui.ach_panel)
	var tabs: TabContainer = main.ui.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 2
	game.unlocked_machines = ["standard", "glueck", "spuk"]
	game.select_machine("spuk")
	await snap("v3_spuk.png")
	game.select_machine("glueck")
	tabs.current_tab = 1
	await snap("v3_glueck.png")
	game.stats["golden_built"] = 1
	game.select_machine("standard")
	await snap("v3_golden.png")
	game.reset_game()
	quit()
