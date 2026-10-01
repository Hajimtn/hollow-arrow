# HOLLOW ARROW

A top-down pixel-art boss-rush for Godot 4.7. One arrow. One life. Seven bosses.
Bosses, effects, UI, sound, music, names, lore and maps were made from scratch for this project. The tiles, trees, pillars,
torches and the hero come from **Forest of Dreams by yanin** (see Credits & licences below); everything else we drew is
colour-locked to that pack's 14-colour palette so the whole game shares one look.

## Run

Open the folder in Godot 4.7+ and press F5 (main scene: `scenes/main.tscn`).
The first import generates the `.godot/` cache; all art is in `assets/`, audio is synthesised at start-up.

## Controls

| Action | Input |
|---|---|
| Move | WASD / arrow keys |
| Dodge roll (brief invulnerability) | Space / Shift |
| Shoot the arrow toward the cursor | Left click |
| Recall the arrow | Hold right click (or E / F). Tap = full recall; hold and release = leave it where it is |
| Retry the fight instantly | R |
| Pause | Esc / P |
| Fullscreen | F11 |

### Touch (phones and tablets, landscape)

The on-screen controls appear at the first touch and hide again if a key is pressed. All of them are fixed in place: the **move stick**
bottom left, the **shoot stick** bottom right with a **ROLL** button beside it, pause at the top centre. While the arrow is in hand the
shoot stick aims (drag, **let go to shoot**, a quick tap shoots along the last aim) and a dotted line from the hero shows the shot in the
game, stopping at the first wall. Once the arrow is out, the next touch on the same stick is **RECALL** (hold). Menus, title and cutscenes take plain taps. Portrait shows a "turn your device sideways"
screen and pauses the fight. To try it on a desktop, run with `-- --touch` or open the web build with `?touch=1` (the mouse then acts as a
finger). Code: `scripts/ui/touch_controls.gd`, test: `tools/at.sh touch`.

You have **one arrow** and **one hit point**. You cannot shoot again until the arrow is back in your hand
(walk over it, or recall it). A recalled arrow flies straight back to you and *damages* what it passes through.

## Play in the browser

```bash
tools/export_web.sh     # -> build/web/ and build/hollow-arrow-web.zip (single-threaded, works on any static host, e.g. itch.io)
tools/serve_web.sh      # then open http://localhost:8060
```

## Structure of the game

```
Title -> Hub (The Hollow Court) -> [path -> arena] x 7 -> Ending -> Credits
```

* Bosses 1-5 (Stone Warden, Mirror Knight, The Burrower, Chained Colossus, Sky Hunter) can be fought in any order.
* The Twin Sentinels unlock after 3 of those five have fallen.
* The Ashen Regent's gate opens when all six guardians are dead.
* Each arena entrance is a checkpoint. Death -> ~1.2 s -> the fight restarts with a completely fresh boss.
* Autosave after every boss; CONTINUE returns you to the hub with all progress. Settings are stored separately.

## Boss notes (spoilers)

Every boss has **three forms**. Each hit on the current weak point breaks the armour, the boss evolves (new sprite, new attacks,
tighter timings) and the weak point moves. Phase 3 is deliberately brutal. There are no aim lines or lane/cone previews (`Game.SHOW_AIM_TELEGRAPHS`): read the wind-up animation and the sound; only ground circles that mark where a blast lands remain. Dying anywhere restarts the whole fight.

Every boss has 3 forms; each form has its own attack list (**no attack is reused in another form**), gets faster and denser, and
has exactly one attack that exposes the weak point. Difficulty starts high in phase 1 - there is no warm-up.

| Boss | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|
| **Stone Warden** (Golem) | rocket fist, rock spikes, **roll** (a pillar crash dazes it: crystal shows) | laser, shard volley, **pound** (crystal opens) | fist boomerang, lava rivers, meteor rocks, **overheat** (steam vents: crystal opens, recalled arrow only) |
| **Mirror Knight** (Frost Guardian) | lance, icicle clap, ice wall, **slam** (fist stuck in ice: eye shows) | glacier roll, blizzard, spike line, **roar** (chest opens for the roar frames) | absolute zero, plate volley, shatter dash, **beam** (staggers afterwards: recalled arrow only) - and any arrow that hits its armour is *frozen* for 2.6 s |
| **The Hollow Executioner** (ghost) | condemned (a ring locks on, the scythe falls), scythe sweep, **ring erupt** (it rises out of a lit lantern: eyes open) | wisp swarm (snuffs lanterns), shadow step, spike lanes, **crest erupt** (scythe up briefly) | grave hands, soul harvest, cage drop, **decoy erupts** (recalled arrow only). A ghost: every arrow passes through it unless it flew through lantern light first (a *blessed* arrow) |
| **Chained Colossus** (Demon) | cleaver slam, chain lash, eruption; cut the chains -> face | orb barrage (the horn flames fly and are the weak points), cleaver boomerang, leap slam, fire wave | meteor rain, flame charge, immolation, hellfire spiral; pylons + crown take recalled arrows only |
| **Sky Hunter** (Archer) | snipe, triple, skid, **arrow thief** (it steals your arrow: recall it out of its hands); empty quiver -> it kneels: head | arrow rain, trap arrows, strafe, storm call; kneels: the quiver | cyclone, pin down, shadow snipe, wind volley; kneels ~2 s: head, recalled arrow only |
| **Twin Sentinels** (Wizards) | link beam (a beam blocked by the other twin breaks its ward), rune circles, shadow claws, swap nova | blink storm, **gravity well** (spent afterwards: gem opens), mirror images, claw lattice | **eclipse beams** (spent afterwards, recalled arrow only), moon fall, arcane grid, solar flare |
| **Ashen Regent** (elemental titan) | stone-fire titan: boulder toss, quake line, magma fist; core opens when you strike the **water shrine** | tide elemental: tidal wave, frost orbs, geyser ring; **fire shrine** | void-flame: storm grid, void well, star fall, shadow clones; **both shrines** within 6 s, then a recalled arrow only |

## Lairs

Each boss lives in its own biome, drawn by `tools/gen_arenas.py` (runs after the pack step, so these tiles/props keep their own
palettes) and animated by `scripts/world/ambience.gd`. The path to a lair shares its tileset.

| Boss | Lair | Look | Ambience | Escalation (phase 2 / 3) |
|---|---|---|---|---|
| Stone Warden | Rune sanctum | grey-green flagstones, cyan rune pillars, rune circle under the golem | drifting cyan motes | floor tiles light up cyan, then crack molten orange |
| Mirror Knight | Frozen vault | blue ice, frozen waterfall, ice spires, snow drifts | snow | frost thickens, then mirror-shard fractures |
| Executioner | Candlelit crypt | dark flagstones, tombstones, coffins, gallows, lanterns | drifting soul wisps | dark cracks, then ember cracks; the light goes red |
| Chained Colossus | Foundry | black basalt, lava vents in the wall, iron pylons, anvils | rising embers | lava veins spread, then red-hot |
| Sky Hunter | Aerie | pale mossy stone on a cliff, ruined watchtower, torn banners | leaves, drifting cloud shadows | rain-dark, puddles + lightning; then a lightning-scarred storm |
| Twin Sentinels | Observatory | violet stone, gold ring, sun disc left / moon disc right, warm and cold braziers | twinkling stars | the room dims; the eclipse |

Each lair also **fights back** (`scripts/world/lair.gd`), from the first second:

| Lair | Mechanic |
|---|---|
| Frozen vault | the floor is slippery ice (low friction: rolls slide far) and icicles fall from the ceiling |
| Foundry | lava fissures in the floor erupt in pairs and trios (the cracked tiles are the vents) |
| Aerie | a shifting gale pushes the player and bends the arrow's flight; leaves and cloud shadows show the wind |
| Candlelit crypt | dark; four lanterns lit by arrow. An arrow that flies through lantern light is *blessed* for 3 s and is the only kind that hurts the ghost; its wisps snuff the flames |
| Observatory | sun half: arrows fly and return faster; moon half: slower |
| Rune sanctum | rune pads detonate; the central circle refills stamina |
| The Nexus (final) | four elemental quadrants wake in turn (tiles light up): lava vents, icicles + slippery ice, stone spikes, lightning. Four shrines in the corners are arrow switches |

A boss calls `zone.on_phase(p)` when it enters phase p: the ambience speeds up, a ripple of floor tiles (tile 12 / 13 of the tileset)
spreads out from the boss, and the ground tint shifts (`Zone.PHASE_TINT`). The final arena keeps its hall and gets six banners, one
in the colours of each lair.

## Project layout

```
assets/        generated pixel art (player, bosses, environment, ui) - see tools/
scenes/        main, player, arrow, one scene per boss
scripts/
  systems/     Game (autoload: save, settings, input map, hit-stop), Sfx (procedural audio), Main (menus/zones),
               Fx, WarnFx/RingFx/ChainFx (telegraphs & effects), GameCamera, Autotest (playtest harness)
  world/       Zone (builds hub/paths/arenas at runtime), ZoneData (layouts), Gate, Pillar, CrystalBlock, ExitPortal
  player/      Player
  weapons/     Arrow (HELD / FLYING / GROUND / STUCK / RETURNING)
  bosses/      BossBase + 7 bosses; Hazard, WeakPoint, Armor, RuneSwitch, Projectile building blocks
  ui/          Menu
tools/         gen_*.py (Python + Pillow) regenerate every sprite; at.sh / test_all.sh run the playtests
```

Physics layers: 1 world, 2 player, 3 boss body, 4 hazard, 5 weak point, 6 armour, 7 switch.
Rendering is 480x270 with integer scaling and nearest filtering.

## Regenerating art / running the tests

```bash
python3 tools/gen_all.py          # rebuild every PNG in assets/ (needs Pillow)
tools/test_all.sh                 # headless playtests of every mechanic, every boss, the menus and a full run to the credits
tools/at.sh <scenario> windowed   # run one scenario with a window and screenshots
```

The test harness (`scripts/systems/autotest.gd`) drives the real game with real input actions. Each boss has a scenario
that beats it using actual arrow physics (shots, recalls, bank shots); `flow` walks the whole game from a new game
through every gate to the credits.

## Credits & licences

* **Forest of Dreams** (16x16 top-down asset pack) by **yanin** - https://yaninyunus.itch.io/topdownadventure-forest-of-dreams
  Used under the author's licence: commercial and non-commercial use and modification are allowed, credit is appreciated
  (given here and in the in-game credits), and the pack itself may **not be redistributed**. The original archives are kept only in
  `assets_src/` (ignored by Godot and excluded from exports); the game ships only modified/cropped/tinted derivatives.
  `tools/gen_pack.py` builds those derivatives. Please check the current licence text on the author's page before publishing.
* **Boss sprites** (all in `assets_src/bosspacks/`, only trimmed/halved derivatives ship, built by `tools/gen_boss_pack.py`; the
  weak-point positions per animation frame were measured with `tools/analyze_boss_art.py` -> `data/boss_anchors.json` and
  `scripts/bosses/boss_anchors.gd`):
  Stone Warden = **Mecha-stone Golem 0.1**, Mirror Knight = **Frost Guardian FREE v1.0**, Burrower = **Undead Executioner puppet**,
  Chained Colossus = **Boss Demon Slime FREE v1.0**, Sky Hunter = **ArcherHero**, Twin Sentinels = **Evil Wizard 2** (CC0, per its
  licence file), Ashen Regent = **Golems and elementals** by **batareya** (34 static 64x96 sprites, drawn at 1.5x). **Licences not yet verified** for all of them except Evil Wizard 2: those zips carry no licence file, so check each
  author's page (and credit requirements) before any public release.
* **Frames drawn for this game** (`tools/gen_drawn.py`, because the packs lack them): the Ashen Regent's floating elemental fists and open
  palms (3 forms, tethered to the body by lines), the Demon's fire-breath cone, and the Frost Guardian's arms-raised and clap poses
  (recoloured/shifted from its roar frames, appended as row 5 of `frost.png`). Rougher than the pack art. Still missing: Frost stomp/cast,
  Demon leap/throw poses.
* All other art (bosses, forms, effects, UI, title) is generated by `tools/gen_*.py`; all audio is synthesised at runtime.
