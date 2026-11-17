# 🧠 Brainrot Heist

[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/{owner}/{repo}/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/{owner}/{repo}/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

> **Ganti `{owner}` dan `{repo}` di badge di atas dengan owner/repo GitHub kamu sebelum submit** — check `makefun` menolak placeholder di URL badge.

**Brainrot Heist** — game Roblox brainrot 3D bergenre *Steal a Brainrot*: brainrot absurd berjalan di conveyor, kamu beli sebelum sampai gerbang, mereka berdiri di basemu dan menghasilkan $ setiap detik, sambil kamu mencuri dari base orang lain, mengunci basemu, dan lari pulang saat tsunami brainrot menyapu map. Rebirth untuk pengali income permanen.

## Cara main

1. **Beli brainrot** — brainrot berjalan di conveyor utara. Klik **BUY** di panel kiri, atau tahan **E** di dekatnya. Kalau sudah sampai gerbang timur, dia hilang.
2. **Kumpulkan $** — brainrot di basemu menghasilkan $/detik sesuai raritasnya. Makin langka makin kaya.
3. **Mutasi** — Gold (x2), Diamond (x5), Rainbow (x10). Sambar kalau muncul.
4. **Mencuri** — tahan **E** pada brainrot di base orang lain (yang tidak terkunci), bawa pulang ke basemu. Kamu jalan lebih lambat sambil membawa curian.
5. **Kunci base** — tombol 🔒 Lock Base (45 detik, cooldown 90 detik, bayar $1.000).
6. **Tsunami** — tiap ~2 menit ada peringatan 10 detik, lalu ombak menyapu map dari utara ke selatan. Di luar base = terlempar ke spawn dan curianmu jatuh.
7. **Rebirth** — butuh $50.000 x 2^rebirth, reset uang + brainrot, income permanen +50% per rebirth.
8. **Upgrade** — Speed, Slots (+2 slot base), Income (+25%).

## Para brainrot (19 karakter)

| Raritas | Karakter |
|---|---|
| Common | Noobini Pizzanini, Tung Tung Tung Sahur, Chimpanzini Bananini |
| Rare | Tralalero Tralala, Brr Brr Patapim, Lirili Larila |
| Epic | Bombardiro Crocodilo, Ballerina Cappuccina, Trippi Troppi |
| Legendary | Cappuccino Assassino, La Vaca Saturno Saturnita, Frigo Camelo |
| Mythic | Boneca Ambalabu, Giraffa Celeste, Matteo the Menace |
| Brainrot God | Los Tralaleritos, Las Tralaleritas |
| Secret | Garama & Madundung, Pot Hotspot |

## Buka di Roblox Studio (Windows / macOS)

Roblox Studio tidak ada versi Linux, jadi langkah ini harus di komputer Windows/Mac:

```bash
# 1. Build place dari source (butuh Rojo 7.7+)
rojo build default.project.json --output game.rbxl

# 2. Buka game.rbxl di Roblox Studio
# 3. Play (F5) untuk playtest, ambil screenshot, lalu publish:
#    File > Publish to Roblox As... > buat experience baru
# 4. Di Creator Dashboard: isi deskripsi (tambah play code make.fun),
#    genre, jawab content questionnaire, set Public
# 5. Upload icon (512x512) + thumbnail (salah satu file screenshots/)
# 6. Isi PLAY.json dengan place_id & universe_id dari experience itu
```

## Struktur kode (Luau)

```
default.project.json   Rojo project: DataModel, Workspace, ReplicatedStorage, Server, Client
main.ts                Program entry: copy game.rbxl, src/, screenshots/, PLAY.json ke /output + dossier.json
vendor/makefun-roblox.ts  Library make.fun (tidak diubah)
src/shared/
  Config.luau          Semua angka tuning + warna raritas + layout base
  BrainrotData.luau    Katalog 19 brainrot + bobot spawn per raritas
  Format.luau          Format uang ($1.50K) & waktu (1:30)
src/server/
  init.server.luau     Bootstrap: RemoteEvents, wiring service, Rebirth, Upgrades, join/leave, autosave
  WorldBuilder.luau    Membangun map 3D: conveyor, 4 base plot, dinding, pohon, lampu, title arch
  BrainrotService.luau Spawn di conveyor, model NPC dari parts, beli, taruh di base, income tiap detik
  StealService.luau    Mencuri, membawa curian, lock base
  EventService.luau    Event tsunami berkala
  PlayerData.luau      Data pemain + DataStore (save/load, fallback in-memory)
src/client/
  Game.client.luau     HUD: top bar, panel belt + tombol BUY, Lock/Rebirth/Upgrades/Help, banner tsunami, notifikasi
screenshots/           3 tangkapan game (lihat catatan di bawah)
PLAY.json              Play link experience (diisi setelah publish; saat ini masih 0)
TOUR.json              Tour opsional untuk reviewer
```

## Status & yang masih harus dilakukan sebelum submit

⚠️ **Repo ini BELUM siap submit.** Yang sudah jadi: semua kode Luau, `game.rbxl` hasil build Rojo, dan `main.ts` yang lolos jalan lokal. Yang masih kurang (butuh Seto / komputer Windows-Mac):

- [ ] Publish experience dari Roblox Studio dengan akun Roblox yang sudah bisa publish (umur akun ≥ 2 hari, lolos age check), set **Public**
- [ ] Isi `PLAY.json` dengan `place_id` & `universe_id` yang benar
- [ ] Ganti `screenshots/` dengan **3 tangkapan asli dari Roblox Studio** — file saat ini adalah *concept render* (gambar ilustrasi yang dibuat dari layout game), bukan tangkapan Studio, dan belum boleh dipakai untuk submit
- [ ] Upload icon + thumbnail (salah satu screenshot) di Creator Dashboard, tunggu review Roblox
- [ ] Buat repo GitHub publik (dibuat setelah bounty dibuka 2026-11-17T14:30:00Z), commit, isi `{owner}`/`{repo}` di badge README, set About repo (website make.fun + topic `makefun`)
- [ ] **Recording**: build ini dibuat di sesi yang TIDAK terekam (record butuh login make.fun). Untuk entry yang valid, mulai `record` dulu, lalu buka sesi agent baru dan minta agent itu menulis ulang / mengedit file-file game di dalam sesi terekam tersebut — lihat `RECORDING.md`
- [ ] Jalankan `node cli/makefun.mjs check --kit . --repo <repo>` sampai `play_link` lolos, lalu submit (lihat `RECORDING.md` untuk perintah lengkapnya)

## Lisensi

MIT — lihat `LICENSE`.
