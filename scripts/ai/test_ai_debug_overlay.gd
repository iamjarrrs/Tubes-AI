extends SceneTree

const OVERLAY_SCRIPT := preload("res://scripts/ui/ai_debug_overlay.gd")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var overlay = OVERLAY_SCRIPT.new()
	root.add_child(overlay)
	await process_frame
	overlay.set_ai_debug_data({
		"facts": ["need_buff", "chest_available"],
		"answer": "GOAL_Seek_Buff",
		"plan": ["move_to_chest", "take_item"],
		"step": "move_to_chest",
		"planner_status": "success",
		"replanning": "plan diperbarui",
		"decision": {
			"state": "need_buff_safe",
			"action": "SEEK_BUFF",
			"action_values": {"SEEK_BUFF": 4.0, "DIRECT_ENGAGE": -2.0},
			"belief_success": 0.75,
			"observation": "MC jauh dari buff",
			"reason": "Expected utility mencari buff lebih tinggi",
			"transitions": {
				"SEEK_BUFF": {"buff_secured": 0.75, "need_buff_medium": 0.25},
				"DIRECT_ENGAGE": {"direct_ready": 1.0}
			},
			"rewards": {
				"SEEK_BUFF": {"success": 10.0, "failure": -1.0},
				"DIRECT_ENGAGE": -2.0
			},
			"discount_factor": 0.9,
			"iterations": 8,
			"mc_buff_distance": 180.0,
			"npc_buff_distance": 300.0
		}
	})

	_check(not overlay.panel.visible, "Panel dimulai tertutup")
	overlay._toggle_menu()
	_check(overlay.menu_panel.visible, "Tombol menu membuka dropdown")
	_check(overlay.menu_buttons.size() == 3, "Dropdown hanya memuat KB, Planner, dan Decision")

	overlay._select_section("kb")
	_check(overlay.panel.visible and not overlay.menu_panel.visible, "Memilih KB menampilkan panel dan menutup menu")
	_check(overlay.content_label.text.contains("Goal") and overlay.content_label.text.contains("Fakta"), "Halaman KB menampilkan goal dan fakta")
	_check(not overlay.content_label.text.contains("Utility"), "Halaman KB tidak mencampur data decision")

	overlay._select_section("planner")
	_check(overlay.content_label.text.contains("Rencana") and overlay.content_label.text.contains("move_to_chest"), "Halaman Planner menampilkan rencana")
	_check(not overlay.content_label.text.contains("Fakta"), "Halaman Planner tidak mencampur data KB")

	overlay._select_section("decision")
	_check(overlay.content_label.text.contains("Policy") and overlay.content_label.text.contains("Belief"), "Halaman Decision menampilkan policy dan belief")
	_check(overlay.content_label.text.contains("Transisi") and overlay.content_label.text.contains("Reward"), "Halaman Decision menampilkan model MDP")

	var f3_event := InputEventKey.new()
	f3_event.keycode = KEY_F3
	f3_event.pressed = true
	overlay._unhandled_input(f3_event)
	_check(not overlay.panel.visible, "F3 menyembunyikan halaman aktif")
	overlay._unhandled_input(f3_event)
	_check(overlay.panel.visible, "F3 menampilkan kembali halaman aktif")

	overlay.queue_free()
	await process_frame
	print("AI Debug Overlay tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)