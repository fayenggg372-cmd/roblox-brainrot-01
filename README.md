[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/fayenggg372-cmd/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/fayenggg372-cmd/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

# Brainrot Heist

A 3D Steal-a-Brainrot game for Roblox, built for the
[make.fun roblox-brainrot-01 bounty](https://make.fun/bounty/roblox-brainrot-01).

Brainrots ride a conveyor across the north side of the map. Buy one before
it reaches the east gate and it moves to your base, where it earns you cash
every second based on its rarity. Grow rich, lock your base, steal from
rivals — and survive the tsunami.

## Features

- **Conveyor shop:** 19 brainrots in 7 rarities, from Common to Secret.
- **Mutations:** Gold (x2 income), Diamond (x5), Rainbow (x10).
- **Stealing:** press E near a rival's brainrot to grab it — but carrying
  stolen goods slows you down, and the owner can catch you.
- **Lock Base:** lock your base for 45 seconds (90s cooldown) for $1,000,
  +$1,000 more per rebirth.
- **Tsunami:** every ~2 minutes a wave sweeps the map north to south after a
  10-second warning. Anyone outside their base is thrown back to spawn and
  drops whatever they were carrying.
- **Rebirth:** costs $50,000 x 2^rebirth. Resets your cash and brainrots but
  gives a permanent +50% income per rebirth.
- **Upgrades:** Speed, Slots (+2 base slots), and Income (+25%).
- **Selling:** sell any brainrot for half its buy price.
- **Heist Contracts:** 9 session quests (buying, selling, locking, rebirthing,
  upgrading, holding cash, earning income) that pay cash rewards when claimed.
  Progress resets when you leave the game.
- **Brainrot Fusion:** fuse 3 brainrots of the same rarity into 1 random
  brainrot of the next rarity up. Secret brainrots cannot be fused.

## How to play

1. **Buy:** click a brainrot on the conveyor before it reaches the east gate.
2. **Collect:** brainrots on your base earn $ every second — rarer ones earn more.
3. **Mutations:** watch for Gold, Diamond, and Rainbow brainrots; they multiply income.
4. **Steal:** press E near a rival's brainrot to steal it, then run home before
   they catch you (you walk slower while carrying).
5. **Lock your base:** spend $1,000 to lock it for 45 seconds when thieves are near.
6. **Survive the tsunami:** when the warning sounds, get inside your base or
   lose what you are carrying.
7. **Rebirth:** once you can afford $50,000 x 2^rebirth, reset for a permanent
   +50% income boost.
8. **Upgrade:** spend cash on Speed, extra Slots, and Income boosts.
9. **Contracts:** open the Contracts panel, finish quests, and claim cash rewards.
10. **Fusion:** open the Fusion panel, pick 3 slots of the same rarity, and fuse
    them into a stronger brainrot.

## Brainrots

- **Common:** Noobini Pizzanini, Tung Tung Tung Sahur, Chimpanzini Bananini
- **Rare:** Tralalero Tralala, Brr Brr Patapim, Lirili Larila
- **Epic:** Bombardiro Crocodilo, Ballerina Cappuccina, Trippi Troppi
- **Legendary:** Cappuccino Assassino, La Vaca Saturno Saturnita, Frigo Camelo
- **Mythic:** Boneca Ambalabu, Giraffa Celeste, Matteo the Menace
- **Brainrot God:** Los Tralaleritos, Las Tralaleritas
- **Secret:** Garama & Madundung, Pot Hotspot

## Opening in Roblox Studio

1. Install [Rojo](https://rojo.space/) (7.7.1 or newer).
2. Clone this repo and run `rojo build default.project.json --output game.rbxl`.
3. Open `game.rbxl` in Roblox Studio.
4. Press Play to test solo, or publish the place to play with friends.

## Code structure

- `src/shared/Config.luau` — tuning numbers (prices, timers, multipliers).
- `src/shared/BrainrotData.luau` — catalog of all 19 brainrots.
- `src/shared/Format.luau` — money and time formatting.
- `src/server/init.server.luau` — bootstrap: builds the world, starts services.
- `src/server/WorldBuilder.luau` — builds the map, bases, and conveyor.
- `src/server/BrainrotService.luau` — buying, selling, income, placing brainrots.
- `src/server/StealService.luau` — stealing, carrying, locking bases.
- `src/server/EventService.luau` — tsunami events.
- `src/server/PlayerData.luau` — player records, cash, rebirths, upgrades.
- `src/server/QuestService.luau` — Heist Contracts (session quests + rewards).
- `src/server/FusionService.luau` — Brainrot Fusion (3 same-rarity -> 1 higher).
- `src/client/Game.client.luau` — main HUD.
- `src/client/Quests.client.luau` — Contracts panel UI.
- `src/client/Fusion.client.luau` — Fusion panel UI.

## Tips for new players

- Buy cheap Commons early: even a small income stream beats an empty base.
- Save your first $1,000 for a base lock before you start stealing — revenge
  thefts are the most common way to lose a good brainrot.
- Watch the conveyor, not the shop: rare brainrots appear without warning and
  despawn at the east gate, so be ready to click fast.
- Fuse your duplicate Commons and Rares instead of selling them: a fused
  Epic earns far more than the half-price sale of three Commons.
- Claim contract rewards as soon as they complete — the cash can fund your
  next rebirth or upgrade immediately.
- During a tsunami warning, stop chasing steals and get inside your base.

## Development

```sh
# Build the place file
rojo build default.project.json --output game.rbxl

# Live-sync into Studio while editing
rojo serve default.project.json
```

The project uses Rojo to sync `src/` into the place. Server scripts live in
`src/server`, client scripts in `src/client`, and shared modules in
`src/shared`. The entry point is `main.ts`, which bundles the place file,
sources, screenshots, and `PLAY.json` into the submission output.

## Status & to do

- [x] Core loop: conveyor, buying, income, stealing, locking, tsunami, rebirth, upgrades.
- [x] Heist Contracts (QuestService + Quests UI).
- [x] Brainrot Fusion (FusionService + Fusion UI).
- [ ] Publish the place from Roblox Studio (account owner).
- [ ] Fill in `PLAY.json` with the real place/universe id.
- [ ] Replace the concept screenshots with real captures from Roblox Studio.
- [ ] Upload a game icon and thumbnail.

## License

MIT — see [LICENSE](LICENSE).
