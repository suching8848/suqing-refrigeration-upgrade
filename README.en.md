# SuQing’s Refrigeration Upgrades Mod / 蘇清的冷藏升级模组

[中文](README.md) · [English](README.en.md)

Project Zomboid **Build 42.21 single-player candidate 1.0.0-rc.2-perf.1**. Mod ID: `SuQingRefrigerationUpgrade_4221`.

Install permanent refrigeration on existing standard wearable storage equipment while keeping original capacity, weight reduction, weight, appearance, equipment slots, fluid components and storage filters. Ordinary Container Upgrades and Backpack Super Upgrades are optional; this mod can coexist with them. Food is not rejuvenated.

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

Cooling normalized temperature from ambient 1 to 0.2 takes about 20 game minutes; hot food takes longer. Native warming resumes when disabled. Existing rc.1 upgrade records, switches and battery ledgers remain valid without repayment.

The SuQing Refrigeration sandbox page offers a master switch (on by default) and spoilage speed **0–100%, default 20%**, relative to the world's base spoilage speed. Zero preserves current freshness; 100 restores ambient speed without reversing age. Native fridges, freezing and multiple refrigerated layers do not multiply the effect. It does not actively freeze food, repair burnt/poisoned/contaminated food or change cooking state or remaining portions. No old-save sandbox editor is provided.

Standard wearable `InventoryContainer` items are detected automatically. Ammo, holster, key and wallet filters remain. For custom filters, first place a food the container actually accepts inside, inspect its menu, then empty it before installing. An apple being rejected is not treated as proof that every food is rejected. Virtual stores and clothing pockets without real inventory containers are outside general support. Narrow adapter API: `SuQingRefrigeration.RegisterContainer(fullType, true/false)`.

## Disabling and validation limits

Disabling does not refund payment or delete equipment, food or upgrade records. Food ages normally while disabled; records can be recognized when re-enabled. For complete removal, keep the mod active, remove each upgrade in-game, save/exit, then disable. No world-file overwrite is needed.

Historical feedback confirmed rc.1 cooling and switching on a legendary backpack. rc.2/perf.1 native crafting, temperature transitions, world unloading, vehicles, special conversions, pause/sleep/fast-forward and actual performance still need focused in-game acceptance. Development records include offline Kahlua and installed-game native-class regression. Simulated workload improvements do not establish FPS gains. Multiplayer and dedicated servers are untested.

This Git preparation preserves the development package and does not install it or alter personal saves. See [Testing and maintenance](docs/TESTING.md), [Asset provenance](docs/ASSETS.md) and [Changelog](CHANGELOG.md).

## Related projects and setup snapshot

[All eight mod and patch repositories](docs/project-index.md) · [Current 205-ID enabled order](docs/current-single-player-modlist.md) · [Author’s Steam collection](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

The source index covers 37 Mod IDs. The Steam collection does not include separately installed local patches; select entries using each project’s requirements and conditional integration notes. Enabled state does not establish in-game acceptance of every project or new version.
