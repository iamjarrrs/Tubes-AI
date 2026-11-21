# Instruksi Copilot untuk Proyek Ini

- Bacalah file dan fungsi terkait sebelum mengubah kode.
- Ubah seminimal mungkin; jangan refactor di luar permintaan.
- Kontrak `KBEngine.tell(percepts)` dan `KBEngine.ask("GOAL")` beserta goal `GOAL_Seek_Buff` serta `GOAL_Direct_Engage` jangan diubah.
- CSP dan Simulated Annealing utama dipanggil dari `GameState.choose_npc_loadout()`; Versus Preview tidak boleh menjalankan SA lagi. Implementasi ada di `scripts/game_state.gd`, `scripts/ai/ai_loadout_manager.gd`, dan `scripts/ai/automated_planner.gd` untuk planner.
- Pertahankan guard `awaiting_battle_start` pada `NPCController._start_battle()` di `scripts/entities/npc_controller.gd`.
- Jangan mengubah `BattleUI._total_stats()`, perhitungan attack/defense/HP, atau Minimax di `scripts/battle_ui.gd`.
- Key stat battle dan percept harus tetap `attack`, `defense`, dan `hp`.
- Pengambilan buff pertahankan satu jalur: `take_item` -> `buff_item.collect(npc)` -> `_on_item_collected()`.
- Battle saat ini dipicu oleh `[B]` atau tombol prompt, bukan deteksi otomatis jarak/sentuhan.
- Decision logic arena ada di `scripts/ai/decision_engine.gd`; pisahkan pemilihan policy/utility dari KB dan automated planner.
- `DIRECT_ENGAGE` saat ini berarti NPC standby menunggu prompt, bukan memulai battle otomatis.
- Jalankan tiga tes Godot yang sudah ada, `scripts/ai/test_decision_engine.gd`, dan `scripts/ai/test_ai_debug_overlay.gd` setelah perubahan yang relevan.

Detail lengkap alur dan batasan ada di `docs/ARSITEKTUR.md`.
