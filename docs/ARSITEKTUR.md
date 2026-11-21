# Arsitektur dan Kondisi Kode Saat Ini

## Ringkasan

Game ini memilih map, membentuk loadout MC, membentuk loadout NPC melalui CSP dan Simulated Annealing, menampilkan Versus Preview, lalu menjalankan Knowledge-Based Agent, Decision Engine, dan Automated Planner sebelum pertarungan. Decision Engine memakai MDP dan Value Iteration untuk memilih policy, serta memperbarui belief peluang NPC mendapatkan buff dari jarak relatif MC/NPC ke buff dan status ketersediaannya. Kondisi kode saat ini: NPC mendekati MC hingga sekitar 32 px sebelum draft dimulai, NPC memakai ramuan melalui satu jalur controller, dan battle dimulai melalui prompt `[B]` atau tombol prompt.

## BAGIAN YANG JANGAN DIUBAH TANPA ALASAN KUAT

- Kontrak Knowledge-Based Agent: `KBEngine.tell(percepts)` dan `KBEngine.ask("GOAL")` beserta goal `GOAL_Seek_Buff` dan `GOAL_Direct_Engage`. Implementasi ada di `scripts/ai/kb_engine.gd`, fungsi `_init()`, `tell()`, dan `ask()`.
- CSP dan Simulated Annealing: pemilihan accessory memanggil `choose_npc_loadout()` di `scripts/item_selection_ui.gd`, `_on_item_selected()`. Implementasi pembentukan NPC ada di `scripts/game_state.gd`, `choose_npc_loadout()`, `get_item_catalog()`, `_compatible_items()`, dan `_score_npc_candidate()`. Implementasi loadout terpisah juga tersedia di `scripts/ai/ai_loadout_manager.gd`, khususnya `get_valid_combinations()`, `evaluate_fitness()`, dan `run_simulated_annealing()`. Versus Preview hanya membaca `game_state.npc_loadout` dan tidak menjalankan SA ulang: `scripts/versus_preview_ui.gd`, `_ready()`.
- Guard `_start_battle()` di `scripts/entities/npc_controller.gd`: battle hanya dimulai jika `awaiting_battle_start` bernilai true. `_start_battle()` mengubah status itu menjadi false sebelum membuat `BattleUI`.
- Perhitungan stat dan keputusan Minimax: jangan mengubah `BattleUI._total_stats()`, `_choose_npc_action_minimax()`, atau `_minimax_value()` di `scripts/battle_ui.gd`.
- Key stat tetap `attack`, `defense`, dan `hp` pada percepts serta perhitungan battle.
- Pengambilan buff NPC: aksi planner `take_item` memanggil `buff_item.collect(npc)` di `_execute_instant_action()`; sinyal `collected` diproses `_on_item_collected()` di `scripts/entities/npc_controller.gd`. Pengumpulan fisik dan sinyalnya ada di `scripts/entities/buff_item.gd`, `collect()` dan `_on_body_entered()`.
- Decision Engine berada di `scripts/ai/decision_engine.gd`; integrasinya tidak mengubah kontrak KB. Action `DIRECT_ENGAGE` berarti NPC berhenti dan menunggu prompt/`[B]` sesuai perilaku saat ini, bukan memulai battle otomatis.

## 1. Alur game dari awal sampai battle

1. **Portal dan pemilihan map.** `Tiled_files/map_portal.gd`, `_on_body_entered()`, mendeteksi pemain dan membuka map selector. `_select_map()` di `Tiled_files/map_selector.gd` memanggil `GameState.start_map_draft()`.
2. **Memuat scene dan NPC mendekati MC.** `GameState.start_map_draft()` di `scripts/game_state.gd` mereset base stat dan loadout, memuat scene, membuat NPC bernama `BattleNPC`, dan menunggu jarak NPC-MC kurang dari sekitar 32 px. Pergerakan awal NPC memakai A* di `_physics_process()` milik `Tiled_files/npc.gd`; setelah jarak terpenuhi, posisi gerak dihentikan dan UI element dibuka.
3. **Draft element.** `scripts/element_selection_ui.gd`, `_on_element_selected()`, menyimpan pilihan Fire, Nature, atau Water ke `game_state.mc_loadout["element"]`, lalu membuka UI weapon.
4. **Draft weapon, armor, dan accessory.** `scripts/item_selection_ui.gd`, `_on_item_selected()`, menyimpan pilihan ke kategori MC dan menolak item jika weight gabungan melewati `MAX_LOADOUT_WEIGHT = 65` yang dideklarasikan di `scripts/game_state.gd`.
5. **Pembentukan NPC loadout.** Pemilihan accessory memanggil `choose_npc_loadout()` di `_on_item_selected()`. Fungsi ini di `scripts/game_state.gd` membangun domain item kompatibel, melakukan pencarian kombinasi, dan menyimpan `npc_loadout`.
6. **Versus Preview.** `_ready()` di `scripts/versus_preview_ui.gd` membaca `game_state.mc_loadout` dan `game_state.npc_loadout` serta menampilkan kartu/stat. Versus Preview tidak menjalankan SA ulang. Tombol `LANJUT KE ARENA` memanggil `_on_start_battle_pressed()`, lalu `GameState.start_ai_planning_stage()` menutup fase draft/preview.
7. **Memulai NPCController.** `start_ai_planning_stage()` di `scripts/game_state.gd` menambahkan scene `NPCController.tscn`. `_ready()` di `scripts/entities/npc_controller.gd` membuat `BuffItem`, mengaktifkan AI overlay, mengubah NPC menjadi planner-controlled, mengaktifkan gerak, dan memanggil `_replan()` pertama.
8. **Knowledge-Based reasoning.** `_build_percepts()` di `NPCController` mengumpulkan element, stat akhir MC/NPC, dan `chest_available`. `_replan()` memanggil `KBEngine.tell(percepts)` lalu `KBEngine.ask("GOAL")`.
9. **Decision Under Uncertainty.** `NPCController._replan()` memberikan hasil goal KB, ketersediaan item, dan status buff NPC ke `scripts/ai/decision_engine.gd`. Engine menghitung policy MDP dengan Value Iteration untuk state `need_buff_safe`, `need_buff_medium`, dan `need_buff_risky`, membandingkan expected utility `SEEK_BUFF` dan `DIRECT_ENGAGE`, serta memakai discount factor `0.9`.
10. **Bayesian update.** Controller mengubah jarak relatif MC dan NPC ke buff menjadi observasi `mc_far`, `mc_medium`, atau `mc_near`. Belief hanya diperbarui ketika kategori observasi berubah agar frame berulang tidak dihitung sebagai evidence independen. Observasi `item_taken` menurunkan peluang sukses dan memaksa policy direct karena arena hanya memiliki satu buff.
11. **Automated Planner dan perilaku.** Untuk policy `SEEK_BUFF`, controller meminta planner menyusun rencana `move_to_chest`, `take_item`, `use_item`, `move_to_mc`; controller menjadikan langkah `move_to_mc` sebagai standby setelah buff sesuai perilaku saat ini. Untuk policy `DIRECT_ENGAGE`, NPC berhenti dan menampilkan prompt. Controller meminta rencana ulang jika observasi mengubah action policy, serta menghapus prompt dan menonaktifkan guard battle jika policy kembali ke `SEEK_BUFF`. Jika NPC sudah mengambil buff, controller tetap meneruskan urutan `use_item` sebelum standby. Planner tetap berada di `scripts/ai/automated_planner.gd` dan domainnya di `data/domain_planning.json`.
12. **Memulai battle.** Battle dimulai melalui `_unhandled_input()` saat pemain menekan `[B]` atau melalui tombol prompt yang memanggil `_start_battle()` di `scripts/entities/npc_controller.gd`. `_start_battle()` mengunci gerak dan memuat `scripts/battle_ui.gd` sebagai CanvasLayer.

## 2. Statistik

- Base stat MC dan NPC: `attack = 30`, `defense = 0`, `hp = 100`, pada `scripts/game_state.gd`.
- Stat akhir battle dihitung oleh `BattleUI._total_stats()` di `scripts/battle_ui.gd`: attack = base attack + `atk` atau `power`; defense = base defense + `def` atau `defense`; hp = base hp + item `hp`.
- Weight loadout adalah jumlah weight weapon, armor, dan accessory. Maksimum 65 melalui `MAX_LOADOUT_WEIGHT` di `scripts/game_state.gd` dan pengecekan di `scripts/item_selection_ui.gd`.
- Ramuan menambah +10 attack tepat sekali pada base stat pengambil: MC pada `_on_item_collected()` dan NPC saat `_execute_instant_action("use_item")` di `scripts/entities/npc_controller.gd`.
- Siklus element: Fire > Nature > Water > Fire.
- `KB Engine` memakai konstanta `ELEMENT_SUPER_EFFECTIVE = 1.25` dan `ELEMENT_NOT_VERY_EFFECTIVE = 0.85` di `scripts/ai/kb_engine.gd`.
- `BattleUI` memakai `SUPER_EFFECTIVE = 1.25` dan `NOT_VERY_EFFECTIVE = 0.85` di `scripts/battle_ui.gd`.
- `AI Loadout Manager.calculate_power()` memakai multiplier unggul 1.25 dan lemah 0.85 di `scripts/ai/ai_loadout_manager.gd`.
- Effective damage perkiraan KB dihitung `_effective_damage()` sebagai `max(1, attack × multiplier − defense × 0.5)`.

## 3. Knowledge Base

- Rule disimpan di `data/npc_kb.json` sebagai objek JSON dengan id, priority, if, then, dan desc.
- Loader dan forward chaining ada di `scripts/ai/kb_engine.gd`, fungsi `_load_knowledge_base()`, `_premises_match()`, `ask()`, dan `_select_goal_from_rules()`.
- `tell(percepts)` membersihkan dan membangun ulang `fact_base` serta `active_rules`.
- `ask("GOAL")` menjalankan forward chaining sampai tidak ada fakta baru dan mengembalikan satu goal.
- Kalah element atau effective damage menambahkan `need_buff`; peti tersedia menghasilkan `GOAL_Seek_Buff`.
- Unggul atau setara element dan effective damage menghasilkan `GOAL_Direct_Engage`.
- Fallback `need_buff + chest_unavailable -> GOAL_Direct_Engage` memiliki priority 1000.

## 4. Automated Planner

- Implementasi: `scripts/ai/automated_planner.gd`, fungsi `request_plan()` dan `update_request()`.
- Domain aksi: `data/domain_planning.json`.
- Pencarian A* sinkron memakai predicate state dan aksi yang ditambah/dihapus.
- `GOAL_Seek_Buff` memerlukan `item_used` dan `at_mc`; `GOAL_Direct_Engage` dipetakan ke `at_mc`.

## 5. Decision Engine

- Implementasi: `scripts/ai/decision_engine.gd`; controller mengirim status kebutuhan buff, ketersediaan item, dan kepemilikan buff.
- State keputusan: `need_buff_safe`, `need_buff_medium`, `need_buff_risky`, `buff_secured`, `buff_unavailable`, dan `direct_ready`.
- Action dibandingkan: `SEEK_BUFF` dan `DIRECT_ENGAGE`. Nilai state dihitung dengan Value Iteration, maksimum 100 iterasi, toleransi `0.0001`, dan discount factor `0.9`.
- Transition model eksplisit: `SEEK_BUFF` bercabang ke `buff_secured` sesuai belief dan ke state risiko berikutnya saat gagal; `DIRECT_ENGAGE` menuju `direct_ready`. Reward sukses buff `+10`, direct engage `-2` pada state butuh buff, dan reward gagal makin negatif pada state risiko lebih tinggi.
- Prior belief keberhasilan mengambil buff adalah `0.65`. Evidence jarak memakai likelihood tetap untuk `mc_far`, `mc_medium`, dan `mc_near`; `item_taken` menjadi evidence kuat bahwa NPC tidak lagi dapat memperoleh buff.
- Observasi jarak di controller membandingkan jarak MC dan NPC terhadap buff, bukan hanya jarak MC absolut. Bucket yang sama tidak dihitung berkali-kali setiap frame.
- `DIRECT_ENGAGE` adalah keputusan strategi arena; untuk versi saat ini controller standby dan tetap menunggu tombol prompt/`[B]`. Planner tidak menentukan probabilitas atau utility.
- Tes mandiri: `scripts/ai/test_decision_engine.gd` menguji update belief, pengulangan observasi, utility, pergantian policy saat MC mendekat, dan kondisi buff tersedia/tidak tersedia.
- Tes UI overlay: `scripts/ai/test_ai_debug_overlay.gd` menguji dropdown, pergantian halaman tanpa campur data, tampilan model MDP, dan shortcut F3.

## 6. AI Debug Overlay

- Overlay aktif adalah `scripts/ui/ai_debug_overlay.gd`, node bernama `AIDebugOverlay` pada `scenes/ui/ai_debug_overlay.tscn`. F3 membuka/tutup panel lewat `_unhandled_input()`.
- `scripts/game_state.gd`, `start_map_draft()`, membuat node `GameplayDebugOverlay` dari scene aktif tersebut. Perhatian: `scripts/gameplay_debug_overlay.gd` adalah overlay lama dan tidak dipakai sebagai overlay AI aktif saat ini.
- Overlay membaca status Peti dari `controller.item_available` dan menampilkan Ada/Diambil.
- Field Buff menampilkan `Dipakai` bila `npc_buff_used=true`, `Ya` bila `has_npc_buff=true`, dan `Tdk` jika tidak ada keduanya.
- Bagian Decision menampilkan state, policy aktif, expected utility kedua action, belief keberhasilan, observasi terakhir, jarak MC/NPC ke buff, alasan keputusan, discount factor, dan jumlah iterasi Value Iteration.

## 7. Cara menjalankan tes

Dari root proyek:

```bash
godot --headless --path . --script res://scripts/ai/test_kb_engine.gd
godot --headless --path . --script res://scripts/ai/test_automated_planner.gd
godot --headless --path . --script res://scripts/ai/test_decision_engine.gd
godot --headless --path . --script res://scripts/ai/test_ai_debug_overlay.gd
godot --headless --path . --script res://scripts/ai/test_tahap4_integration.gd
```

Ekspektasi: KB Engine 5 lulus, Automated Planner 3 lulus, Decision Engine 25 lulus, AI Debug Overlay 12 lulus, dan integration test lulus.

## 8. Aturan untuk AI assistant

- Baca file dan fungsi yang terkait sebelum mengubah kode.
- Ubah seminimal mungkin dan hanya sesuai permintaan.
- Jangan mengubah kontrak KB, CSP/SA utama, perhitungan BattleUI, atau Minimax tanpa permintaan eksplisit.
- Decision logic baru berada di `scripts/ai/decision_engine.gd`; jangan mencampur utility/policy ke dalam KB atau planner.
- Jangan menambah pemanggilan SA kedua pada Versus Preview.
- Pertahankan satu jalur pengambilan buff.
- Pertahankan pemicu battle melalui `[B]`/tombol prompt.
- Jalankan empat tes Godot setelah perubahan terkait dan laporkan hasil apa adanya.
