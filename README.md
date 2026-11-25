# Meio BiS Extras

Forever Leveling BiS's windows easier to use, and its verdicts on your Character frame.

For WoW Forever.

![The Character frame: before, only your gear; with MeioBiSExtras and the patch, each slot
shows BiS or how close the item is to the best you can get now](docs/before-after.png)

## What it does

Works on install, in Forever Leveling BiS's windows:

- Item tooltips compare with what you wear, without Shift
- Alt-click an item for its Wowhead Forever link, ready to copy
- Its window and the Auction House come to the front when you click them

With a small patch to Forever Leveling BiS
([steps](https://github.com/MeioNeiz/MeioBiSExtras#forever-leveling-bis-patch)):

- Open your Character frame and each slot says how your item stands for your main spec:
  BiS, or its % of the best you can get now, in Forever Leveling BiS's colours
- Best in slot lists BoE first, or the sources in any order you pick

Settings: Esc > Options > AddOns > MeioBiSExtras.

- `/bisorder <sources>`: list these first on Best in slot, e.g. `/bisorder quest boe`
  (quest, dungeon, crafted, boe, vendor, pvp); `/reload` to apply
- `/bisorder reset`: back to BoE, Quest, Dungeon, Crafted
- `/bisorder settings`: the Settings panel
- `/bisorder help`: every command

## Install

You need [Forever Leveling BiS](https://www.curseforge.com/projects/1719370). Use your addon
manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully; then add the patch
below for slot standing and source order.

### Forever Leveling BiS patch

Forever Leveling BiS doesn't let other addons read its verdicts or change its source order,
so those two need a small patch to it; the tooltips, Alt-click and window layering work
without it. This repository's installer adds it:

1. Install PowerShell 7: `winget install Microsoft.PowerShell` in a terminal.
2. Download [this repository](https://github.com/MeioNeiz/MeioBiSExtras) (green **Code**
   button, **Download ZIP**) and extract it.
3. Close WoW, open a terminal in that folder and run
   `pwsh -ExecutionPolicy Bypass -File mods.ps1`
   (add `-AddOns "<your _forever_\Interface\AddOns folder>"` if WoW is installed elsewhere).
4. Start WoW; the Character frame shows each slot's standing.

The installer copies the addon, edits only the Forever Leveling BiS files the patches name
(`patches\61-flbis-source-order.patch`, `patches\64-flbis-api-verdicts.patch`, every new
line marked `LOCAL FIX`), keeps a backup of each in `backups\`, and changes nothing if
Forever Leveling BiS's code has moved on. Without MeioBiSExtras the patched addon behaves
exactly as before. A Forever Leveling BiS update undoes the patch: run the installer again.
To undo it: `pwsh -ExecutionPolicy Bypass -File mods.ps1 revert 61-flbis-source-order`
(and `64-flbis-api-verdicts`), or reinstall Forever Leveling BiS.

Made and tested with Forever Leveling BiS v1.4.4.

## Feedback

Bugs and ideas: [GitHub issues](https://github.com/MeioNeiz/MeioBiSExtras/issues)

## More Meio addons

[Meio Trainer Compare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio Auto Rank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio Meter Hover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Plates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio Stats](https://addons.wago.io/addons/meiostats) | [Meio Bags](https://addons.wago.io/addons/meiobags) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes) | [Meio Tooltip Fold](https://addons.wago.io/addons/meiotooltipfold) | [Meio Auto Run Turn](https://addons.wago.io/addons/meioautorunturn) | [Meio Mail](https://addons.wago.io/addons/meiomail) | [Meio QoL](https://addons.wago.io/addons/meioqol) | [Meio TSM Browse](https://addons.wago.io/addons/tsmbrowse)

## Licence

[MIT](LICENSE)
