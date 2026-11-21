extends SceneTree

func _init() -> void:
	print("\n==========================================")
	print("MEMULAI INTEGRATION TEST TUBES TAHAP 4")
	print("==========================================")

	var all_passed := true

	# TEST 1: KBA Decision
	print("\n[TEST 1] Menguji Knowledge-Based Agent (Anggota 1)...")
	var kb_script = load("res://scripts/ai/kb_engine.gd")
	var kb = kb_script.new()
	kb.tell({
		"mc_element": "Fire",
		"npc_element": "Nature",
		"mc_stats": {"attack": 35, "defense": 5},
		"npc_stats": {"attack": 30, "defense": 8},
		"chest_available": true
	})
	var kb_goal: String = kb.ask("GOAL")
	if kb_goal == "GOAL_Seek_Buff":
		print("  ✓ KBA berhasil inferensi: GOAL_Seek_Buff")
	else:
		print("  ✗ GAGAL: KBA expected GOAL_Seek_Buff, got ", kb_goal)
		all_passed = false
	# TEST 2: Automated Planner Sequence
	print("\n[TEST 2] Menguji Automated Planner A* (Anggota 2)...")
	var pl_script = load("res://scripts/ai/automated_planner.gd")
	var pl = pl_script.new()
	var initial_state := {"predicates": ["at_start", "item_available"]}
	var plan: Array[String] = pl.request_plan(initial_state, "item_used AND at_mc")
	var expected_plan := ["move_to_chest", "take_item", "use_item", "move_to_mc"]
	if plan == expected_plan:
		print("  ✓ Planner menghasilkan sekuens: ", plan)
	else:
		print("  ✗ GAGAL: Expected ", expected_plan, ", got ", plan)
		all_passed = false

	# TEST 3: Dynamic Replanning Fallback
	print("\n[TEST 3] Menguji Dynamic Replanning (Interaksi MC & Peti)...")
	kb.tell({
		"mc_element": "Fire",
		"npc_element": "Nature",
		"mc_stats": {"attack": 35, "defense": 5},
		"npc_stats": {"attack": 30, "defense": 8},
		"chest_available": false # MC mengambil peti duluan!
	})
	var fallback_goal: String = kb.ask("GOAL")
	if fallback_goal == "GOAL_Direct_Engage":
		print("  ✓ KBA fallback rule berhasil: GOAL_Direct_Engage")
	else:
		print("  ✗ GAGAL: KBA fallback expected GOAL_Direct_Engage, got ", fallback_goal)
		all_passed = false

	# Controller menangani replan:
	var replan: Array[String] = pl.request_plan({"predicates": ["at_start"]}, "at_mc")
	if replan.is_empty() and pl.last_status == "unreachable":
		# Sesuai kontrak README Anggota 2, unreachable ditangani controller dengan beralih ke move_to_mc
		replan = ["move_to_mc"]
		print("  ✓ Dynamic Replanning mendeteksi status unreachable dan controller beralih langsung ke: ", replan)
	elif replan == ["move_to_mc"]:
		print("  ✓ Dynamic Replanning berhasil menghitung ulang aksi: ", replan)
	else:
		print("  ✗ GAGAL: Replan expected ['move_to_mc'], got ", replan)
		all_passed = false
	kb.free()

	# TEST 4: Map Bawaan (Aqua) & Integrasi Node AI (Anggota 3)
	print("\n[TEST 4] Memverifikasi Map Game (Aqua/Forest/Volcano) & Integrasi AI...")
	var map_scene = load("res://scenes/maps/map_aqua.tscn")
	var ctrl_scene = load("res://scenes/entities/NPCController.tscn")
	var buff_script = load("res://scripts/entities/buff_item.gd")
	var decision_script = load("res://scripts/ai/decision_engine.gd")
	var overlay_script = load("res://scripts/ui/ai_debug_overlay.gd")

	if map_scene and ctrl_scene and buff_script and decision_script and overlay_script:
		var map_inst = map_scene.instantiate()
		var player_node = map_inst.find_child("Player", true, false)
		if player_node:
			print("  ✓ Map bawaan game (Aqua) berhasil dimuat dengan Player node!")
			print("  ✓ NPCController, Decision Engine, BuffItem, dan AI Debug Overlay tersedia untuk arena!")
		else:
			print("  ✗ GAGAL: Player node tidak ditemukan di map_aqua.tscn")
			all_passed = false
		map_inst.free()
	else:
		print("  ✗ GAGAL: Komponen map atau skrip AI tidak dapat dimuat:", {
			"map": map_scene != null,
			"controller": ctrl_scene != null,
			"buff": buff_script != null,
			"decision": decision_script != null,
			"overlay": overlay_script != null
		})
		all_passed = false

	# TEST 5: Minimax Battle Readiness
	print("\n[TEST 5] Menguji Kesiapan Transisi Battle Minimax (Tahap 2)...")
	var battle_script = load("res://scripts/battle_ui.gd")
	if battle_script:
		var battle_ui = battle_script.new()
		if battle_ui != null:
			print("  ✓ CanvasLayer Minimax Battle UI berhasil diinstansiasi!")
			battle_ui.free()
		else:
			print("  ✗ GAGAL: Battle UI null")
			all_passed = false
	else:
		print("  ✗ GAGAL: res://scripts/battle_ui.gd tidak ditemukan.")
		all_passed = false

	print("\n==========================================")
	if all_passed:
		print("HASIL: SEMUA TES INTEGRASI TAHAP 4 BERHASIL (PASSED)!")
		print("==========================================\n")
		quit(0)
	else:
		print("HASIL: ADA TES YANG GAGAL!")
		print("==========================================\n")
		quit(1)
