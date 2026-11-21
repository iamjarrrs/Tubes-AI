# Tubes AI — Tahap 4

Game Godot 4 ini menggabungkan pembuatan loadout, penalaran berbasis pengetahuan, perencanaan aksi, dan pertarungan berbasis Minimax. Pemain memilih map dan equipment, sedangkan NPC membentuk loadout dan menentukan keputusan arena dari keadaan permainan.

## Fitur Utama

- Pemilihan map Aqua, Forest, dan Volcano.
- Pemilihan element, weapon, armor, dan accessory dengan batas weight 65.
- CSP dan Simulated Annealing untuk membentuk loadout NPC.
- Versus Preview sebelum tahap AI arena.
- A* untuk navigasi NPC pada tahap awal dan pergerakan planner.
- Knowledge-Based Agent dengan forward chaining untuk menghasilkan goal.
- Automated Planner yang menyusun rencana aksi melalui pencarian A* sinkron.
- Decision Engine berbasis MDP, Value Iteration, dan Bayesian belief update untuk memilih policy arena.
- Ramuan yang menambah +10 attack kepada pengambil.
- Battle dengan attack, guard, heal, multiplier element, dan NPC Minimax kedalaman 2.
- AI Debug Overlay yang dapat dibuka atau ditutup dengan F3.

## Alur Gameplay Singkat

1. Masuk portal dan pilih salah satu map.
2. NPC mendekati MC hingga jarak sekitar 32 px lalu draft dibuka.
3. Pilih element, weapon, armor, dan accessory untuk MC.
4. Sistem membentuk `npc_loadout` dan menampilkannya pada Versus Preview.
5. Tekan `LANJUT KE ARENA` untuk memulai tahap AI arena.
6. KB mengevaluasi kondisi; Decision Engine menghitung policy buff atau direct engage memakai Value Iteration dan belief atas peluang mendapatkan buff.
7. Planner menjalankan policy. Jarak relatif MC/NPC ke buff dan status item menjadi observasi; policy dihitung ulang jika belief mengubah pilihan aksi.
8. Overlay AI menampilkan fakta, rencana, policy, expected utility, belief, dan observasi terakhir melalui tombol `F3`.
9. NPC menunggu prompt atau `[B]` untuk memulai pertarungan; battle tidak dimulai otomatis karena jarak.

## Menjalankan Game

Buka folder proyek dengan Godot 4, lalu tekan **Run** di editor.

Atau jalankan dari root proyek:

```bash
godot --path .
```

Versi headless:

```bash
godot --headless --path .
```

## Menjalankan Tes

```bash
godot --headless --path . --script res://scripts/ai/test_kb_engine.gd
godot --headless --path . --script res://scripts/ai/test_automated_planner.gd
godot --headless --path . --script res://scripts/ai/test_decision_engine.gd
godot --headless --path . --script res://scripts/ai/test_ai_debug_overlay.gd
godot --headless --path . --script res://scripts/ai/test_tahap4_integration.gd
```

## Struktur Folder Penting

- `scripts/` — logika game, battle, UI, dan sistem AI.
- `scripts/ai/` — KB Engine, Decision Engine, Automated Planner, Loadout Manager, dan tes.
- `scripts/entities/` — NPCController, NPC arena, player, dan ramuan.
- `scripts/ui/` — AI Debug Overlay.
- `scenes/` — scene map dan antarmuka.
- `Tiled_files/` — portal, map selector, player, NPC, dan navigasi A*.
- `data/` — knowledge base dan domain planning JSON.
- `docs/ARSITEKTUR.md` — dokumentasi teknis dan kondisi kode saat ini.

Untuk detail arsitektur, kontrak sistem, dan batasan pengembangan, lihat [Dokumentasi Arsitektur](docs/ARSITEKTUR.md).
