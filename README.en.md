# SuQing’s Refrigeration Upgrades Mod / 蘇清的冷藏升级模组

[中文](README.md) · [English](README.en.md)

Project Zomboid **Build 42.21 / 42.22.2 single-player candidate 1.0.0-rc.2-perf.8**. Mod ID: `SuQingRefrigerationUpgrade_4221`.

Install permanent refrigeration on existing standard wearable storage equipment while keeping original capacity, weight reduction, weight, appearance, equipment slots, fluid components and storage filters. Ordinary Container Upgrades and Backpack Super Upgrades are optional; this mod can coexist with them. Food is not rejuvenated.

## Performance and the optional Java companion (2026-11-07)

**Lua mode can impose substantial CPU cost with large refrigerated food inventories, including while inventory panels are closed. For high-capacity portable storage or hundreds of refrigerated foods, [SuQing's Refrigeration Performance Patch](https://steamcommunity.com/sharedfiles/filedetails/?id=3834960443) is recommended.** Ordinary tools, weapons and materials do not receive per-item cooling settlement. Discovery still traverses items/nested containers; sustained work mainly follows tracked `Food` instances, rather than UI category names.

The base remains independently usable without Java. The companion is a separate Workshop item, ID `SuQingRefrigerationNative_4221`, version0.1.0-rc.1. It requires this base1.0.0-rc.2-perf.8 and [ZombieBuddy2.3.4](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853); B42.21.0 single-player only. Order: ZombieBuddy → Refrigeration Upgrades → Freshness Lunchbox (if used) → Performance Patch.

Native food scheduling owns aging, cold temperature and freezing/thawing and stops the Lua full-food Tick loop. The master switch, existing items, payment records, costs and save schema remain. Java mode uses vanilla `FridgeFactor` / `FoodRotSpeed`; custom `RotSpeedPercent` is Lua-only. Lua mode retains its roughly20-game-minute cooling transition and custom age cap, so transition timing need not be identical across backends.

Approve the JAR through normal ZombieBuddy prompts. Fully exit and restart after adding, replacing, disabling or removing Java; never replace a running JAR. The patch reads ZB's private `Loader.g_instrumentation` without modifying the game JAR or disabling approval. Exact version/JAR/Food-bytecode gates reject unreviewed combinations. Legacy Lua flushes before confirmed native activation ends the old loop. Absence/mismatch before activation retains Lua; later faults have explicit deactivation/restart boundaries. See [backend notes](native-backend/README.md).

User single-player testing and two fresh logs confirm native takeover, the old Lua sweep stopping and normal save/exit, with a reported subjective improvement. No controlled same-load FPS percentage or multiplayer acceptance is claimed.

On B42.22.2, Lua display coalescing supports the Workshop CleanUI 2.10.5 42.22 branch and its audited optional inventory wrappers (Transfer Performance 1.2.4, Proximity Selection 1.0.3, Search Enhancement 0.1.4-rc.3). Unknown renderers, Snake Utils and actual actions use immediate settlement. Active Java takeover retains native food aging.

## perf.7 display-demand snapshots (2026-11-07)

Background food maintains only the weak container ownership needed by discovery. Complete display signatures are collected for food that used the display entry within500 real milliseconds. First display or expired interest settles strictly before creating an exact signature; subsequent drawing still checks physical values, ledger, ownership, time and epoch. Interest lives in the existing memo, avoiding another per-food weak-table lookup.

Native aging, cooling caps, freezing/thawing, transfers, switches, saving and ledger-replacement semantics remain. The571-food×8-Tick model avoids13704 getters with identical per-item age/heat/lastAged. Paired real-Food method benchmarks had lower medians in three JVMs, but reused one Food: they are not571 native foods, a loaded world or an FPS test. User performance acceptance remains pending. This revision is Lua-only, with no added Java patch or dependency.

## perf.6 deferred render-wrapper chain (2026-11-07)

The perf.5 user session still reported `unreviewed renderer source` with zero display reuse. Its earlier native-metadata preflight constructed the performance-wrapper outer function without executing the complete registration sequence; it did not establish compatibility with the actual final renderer.

This revision supports the reviewed proximity-selection 1.0.1 and search-enhancement 0.1.1 wrappers, matching active versions and native-selected42 branches. Search installs on a deferred first normal OnTick. Display waits for two normal Ticks and two observations of the same function before installation. A paused startup remains strict until unpaused. Logs include the actual closure source, first line and stop reason. Unknown versions/paths or later replacements still disable reuse. Food settlement and values are unchanged; offline checks do not establish live activation or FPS gains.

## perf.5 native-selected branches and numeric memo fix (2026-11-07)

Uses the game's own ChooseGameInfo selection: P4 42.15/3.8.1, CleanUI42.19/2.10.4, local Pinyin42/1.1 and inventory performance42/1.2.2. P4 support is paired precisely to reviewed3.8.1/42.15 or old2.14.1/42; unknown versions, mismatched directories and sources remain strict.

Ledger and native physical values now use separate exact memo snapshots, so Lua double0.2 versus Java float0.20000000298023224 is not mistaken for an external edit. No epsilon is used: tiny ledger edits, physical changes and non-display calls still settle immediately. Native Food and actual updateAge display-path fixtures pass. The same real-metadata Install preflight rejects before and enables after the fix without a game/world/UI run. Food calculations, caches and item rules remain.

## perf.4 display version-gate fix (2026-11-07)

The real Core.getVersionNumber returns42.21; the log-oriented getGameAndBuildVersion returns42.21.0. Accept these two exact equivalent version forms and require build42.21.0 so display reuse can enable, while rejecting other builds/versions/suffixes and preserving real query errors. Successful installation now prints ASCII compat/game/source evidence. Cache, settlement, protection, budgets and gameplay values remain unchanged fromperf.3. Native Core readback and47 display cases/157 assertions pass; live activation and FPS still require user startup.

## perf.3 performance maintenance (2026-11-07)

Cooling state is cached per direct container for at most one game minute. Known transfers, switches, installation/removal, loading and configuration changes invalidate it immediately. Transfers settle the old environment before moving and establish the new entry anchor afterwards; whole-bag moves process the affected food subtree. Native aging, freezing/thawing and the cooling cap still run each Tick, retaining spoilage rates and the roughly20-game-minute heat transition.

Only audited vanilla/CleanUI2.10.4 inventory drawing and reviewed wrappers may reuse an already completed settlement at the same world time, for no more than500 real milliseconds. Age, heat, lastAged, container, record fields and epoch must match. Actions, unknown callers and changed state remain strict. Later renderer replacements disable display coalescing safely.

Fallback discovery tries to start each real second without restarting a pending queue, bounded to32 entries or about1ms per frame. The pre-world changed-process-list protection remains. Saving forces strict settlement; failures are reported without advancing its completion timestamp. Runtime caches/memos do not change IDs, payment records, save schema, capacity or graphics. Foreign cooling-state edits bypassing known events can take up to the one-minute review to appear; polling does not prove an unknown transfer time.

This is a local single-player candidate. Offline checks and user FPS acceptance are recorded separately. The current source companion is Lunchbox0.1.0-rc.8-perf.8, whose exact gates support audited Coolingperf.1–8; unknown versions remain rejected.

## Installation and requirements

Exit the game and retain save/old-version backups. Copy the whole `mods/SuQingRefrigerationUpgrade_4221` folder into your user's `Zomboid/mods`, preserving `42` and `common`. Enable it first in a separate single-player test save. Do not install the repository root or duplicate Mod IDs.

There is no mandatory third-party mod requirement. `loadModAfter` supplies optional ordering hints for ordinary container upgrades, EX, CleanUI and Neat Crafting; it does not require those mods. Equipment still comes from the game or its original mod.

See [SuQing’s Patch Collection](https://github.com/suching8848/suqing-project-zomboid-patches) for related local compatibility maintenance. Refrigeration does not mandate a particular patch from that repository. Select only applicable patches for your installed source mods; do not enable the entire collection. Native equipment swaps and special conversions still require in-game acceptance.

## Use

1. Unequip the target and remove it from both hands. Put it in main inventory and empty all items and any fluid component.
2. Prepare non-favorite materials: **6 batteries, 4 electric wires, 4 electronics scrap and 2 small metal sheets**. Batteries count as physical objects; partial charge is accepted. There is no additional skill threshold or continuing consumable cost.
3. Native crafting → **SuQing Refrigeration → Install SuQing refrigeration**. Success enables cooling with unlimited runtime; cancellation consumes nothing.
4. Right-click upgraded equipment to **Enable cooling / Disable cooling**. It may be worn when toggled, but must belong to the character's main inventory. There is no right-click install/removal or custom tooltip overlay.
5. Unequip and empty/drain again before removal in the same crafting category. Recover **50% of recorded actual payment: 3 batteries, 2 wires, 2 scrap and 1 small metal sheet**. Battery charge follows payment evidence instead of becoming full.

The target may be favorited; favorite materials are not consumed. Original ordinary/super-capacity records and other ModData remain.

## Temperature, sandbox and supported containers

In Lua mode, cooling normalized temperature from ambient 1 to 0.2 takes about 20 game minutes; hot food takes longer. Native warming resumes when disabled. Existing rc.1 upgrade records, switches and battery ledgers remain valid without repayment.

In Lua mode, the SuQing Refrigeration sandbox page offers a master switch (on by default) and spoilage speed **0–100%, default 20%**, relative to the world's base spoilage speed. Zero preserves current freshness; 100 restores ambient speed without reversing age. Native fridges, freezing and multiple refrigerated layers do not multiply the effect. It does not actively freeze food, repair burnt/poisoned/contaminated food or change cooking state or remaining portions. No old-save sandbox editor is provided.

Standard wearable `InventoryContainer` items are detected automatically. Ammo, holster, key and wallet filters remain. For custom filters, first place a food the container actually accepts inside, inspect its menu, then empty it before installing. An apple being rejected is not treated as proof that every food is rejected. Virtual stores and clothing pockets without real inventory containers are outside general support. Narrow adapter API: `SuQingRefrigeration.RegisterContainer(fullType, true/false)`.

## Disabling and validation limits

Disabling does not refund payment or delete equipment, food or upgrade records. Food ages normally while disabled; records can be recognized when re-enabled. For complete removal, keep the mod active, remove each upgrade in-game, save/exit, then disable. No world-file overwrite is needed.

Historical feedback confirmed rc.1 cooling and switching on a legendary backpack. rc.2/perf.1 native crafting, temperature transitions, world unloading, vehicles, special conversions, pause/sleep/fast-forward and actual performance still need focused in-game acceptance. Development records include offline Kahlua and installed-game native-class regression. Simulated workload improvements do not establish FPS gains. Multiplayer and dedicated servers are untested.

This Git preparation preserves the development package and does not install it or alter personal saves. See [Testing and maintenance](docs/TESTING.md), [Asset provenance](docs/ASSETS.md) and [Changelog](CHANGELOG.md).

## Related projects and setup snapshot

[Ten source repositories and 42 Mod IDs](docs/project-index.md) · [Single-player enabled snapshot: 205 IDs on 2026-11-02 01:10 UTC+08:00](docs/current-single-player-modlist.md) · [Author’s Steam collection](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

The source index covers 42 Mod IDs. The Steam collection does not include separately installed local patches; select entries using each project’s requirements and conditional integration notes. Enabled state does not establish in-game acceptance of every project or new version.
