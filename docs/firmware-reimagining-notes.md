# HexBoard Firmware Map: Tuning, Layout, and Color Pipelines

This repository is currently a single-firmware-file codebase: `src/HexBoard.ino` (plus build/readme files).
This document maps how tuning, layout, and color state are selected and how they generate runtime behavior.

## 1. Where Core Data Is Defined

### Tuning definitions
- Tuning IDs are fixed enums/macros (`TUNING_12EDO` ... `TUNING_GAMMA`, `TUNINGCOUNT`) in `src/HexBoard.ino:302`.
- `tuningDef` includes:
  - display name
  - `cycleLength` (period length)
  - `stepSize` (cents per step)
  - per-tuning key choices (`SelectOptionInt keyChoices[]`)
  in `src/HexBoard.ino:368`.
- The full tuning table is hardcoded in `tuningOptions[]` at `src/HexBoard.ino:424`.

### Layout definitions
- `layoutDef` includes:
  - display name
  - orientation hint (`isPortrait`)
  - anchor hex (`hexMiddleC`)
  - interval vectors (`acrossSteps`, `dnLeftSteps`)
  - owning tuning index (`tuning`)
  in `src/HexBoard.ino:462`.
- The full layout table is hardcoded in `layoutOptions[]` at `src/HexBoard.ino:486`.
- `layoutCount` is derived from array size at `src/HexBoard.ino:678`.

### Color/palette definitions
- Color modes are fixed constants (`RAINBOW_MODE`, `TIERED_COLOR_MODE`, etc.) at `src/HexBoard.ino:253`.
- `colorDef` and `paletteDef` are defined at `src/HexBoard.ino:873` and `src/HexBoard.ino:899`.
- Palette lookup table `palette[]` is hardcoded per tuning at `src/HexBoard.ino:927`.

## 2. Runtime State Model (What Is Actually Selected)

### Preset/current selection object
- Runtime musical selection is stored in global `current` (`presetDef`) with:
  - `tuningIndex`
  - `layoutIndex`
  - `scaleIndex`
  - `keyStepsFromA`
  - `transpose`
  in `src/HexBoard.ino:1118` and initialized at `src/HexBoard.ino:1158`.
- `presetDef` helper methods (`tuning()`, `layout()`, `scale()`, `layoutsBegin()`, `keyDegree()`, etc.) drive most selection logic in `src/HexBoard.ino:1127`.

### Per-button generated state
- Every physical key is represented by `buttonDef h[BTN_COUNT]` in `src/HexBoard.ino:1409`.
- Generated fields include:
  - geometric position (`coordRow`, `coordCol`)
  - musical mapping (`stepsFromC`, `note`, `bend`, `frequency`)
  - scale membership (`inScale`)
  - cached LED colors (`LEDcodeRest`, `LEDcodePlay`, `LEDcodeDim`, `LEDcodeOff`, `LEDcodeAnim`)
  in `src/HexBoard.ino:1281`.

## 3. Boot/Load Path (How Selection Is Restored)

- On setup, firmware does:
  1. `load_settings()`
  2. `setupMenu()`
  3. `syncSettingsToRuntime()`
  in `src/HexBoard.ino:6560` and `src/HexBoard.ino:6566`.

### Persistence layer
- Settings keys are enumerated in `SettingKey` at `src/HexBoard.ino:4547`.
- Factory defaults are in `factoryDefaults[]` at `src/HexBoard.ino:4614`.
- Disk file is `/settings.dat` in LittleFS with header + profile arrays (`load_settings()`/`save_settings()`) at `src/HexBoard.ino:4699` and `src/HexBoard.ino:4752`.
- Debounced autosave is `markSettingsDirty()` + `checkAndAutoSave()` at `src/HexBoard.ino:4790` and `src/HexBoard.ino:4797`.

### Applying loaded settings
- `syncSettingsToRuntime()` copies persisted bytes into runtime vars and then runs the full apply pipeline at `src/HexBoard.ino:5898`.
- The apply sequence inside sync is:
  1. `showOnlyValidLayoutChoices()`
  2. `showOnlyValidScaleChoices()`
  3. `showOnlyValidKeyChoices()`
  4. `updateLayoutAndRotate()`
  5. `refreshMidiRouting()`
  6. `resetSynthFreqs()`
  at `src/HexBoard.ino:5980`.

## 4. Tuning Selection and Generation Flow

### Selection UI
- Tuning menu items are generated from `tuningOptions[]` in `createTuningMenuItems()` at `src/HexBoard.ino:6167`.
- Each item callback is `changeTuning(...)`.

### What happens on tuning change
- `changeTuning(...)` performs a coordinated reset in `src/HexBoard.ino:6125`:
  1. set new `current.tuningIndex`
  2. reset layout to first valid layout via `current.layoutsBegin()`
  3. reset scale to index 0 ("None")
  4. reset key to tuning default C via `current.tuning().spanCtoA()`
  5. persist those values
  6. refresh visible menu options
  7. regenerate layout/mapping and MIDI routing

### Pitch generation from tuning
- `assignPitches()` (called after layout/transpose/tuning changes) computes note outputs in `src/HexBoard.ino:4374`:
  - uses `current.pitchRelToA4(h[i].stepsFromC)`
  - converts to MIDI-space via `stepsToMIDI(...)`
  - computes frequency with `MIDItoFreq(...)`
  - sets note + bend (or extended-channel mapping when standard microtonal mode is active)
  - rebuilds `midiNoteToHexIndices` lookup for external MIDI visualization.

## 5. Layout Selection and Generation Flow

### Selection UI and filtering
- Layout menu items are generated from `layoutOptions[]` in `createLayoutMenuItems()` at `src/HexBoard.ino:6173`.
- Available layouts are filtered to current tuning by `showOnlyValidLayoutChoices()` in `src/HexBoard.ino:6013`.
- On explicit layout change, callback `changeLayout(...)` stores `CurrentLayout` and calls `updateLayoutAndRotate()` in `src/HexBoard.ino:6059`.

### Base geometry
- `setupGrid()` initializes per-button coordinates and marks command buttons in `src/HexBoard.ino:1447`.
- Core mapping coordinates are:
  - `coordRow = i / 10`
  - `coordCol = 2 * (i % 10) + parity(row)`
  in `src/HexBoard.ino:1449`.

### Layout generation math
- `updateLayoutAndRotate()` calls `applyLayout()` and then updates display orientation in `src/HexBoard.ino:6048`.
- `applyLayout()` in `src/HexBoard.ino:4473`:
  1. starts with selected layout vectors (`acrossSteps`, `dnLeftSteps`)
  2. optionally applies mirror transforms (`mirrorUpDown`, `mirrorLeftRight`)
  3. applies N hex rotations (`layoutRotation` loop)
  4. for each playable hex, computes `stepsFromC` relative to `hexMiddleC` anchor using row/col offsets
  5. runs `applyScale()` then `assignPitches()`.

This means layout generation is fundamentally a vector transform + anchor offset system; everything else (scale gating, MIDI notes, LED palettes) derives from resulting `stepsFromC`.

## 6. Color Selection and Generation Flow

### Selection UI
- Color mode menu is `menuItemColor` with options in `optionByteColor[]` at `src/HexBoard.ino:5684`.
- Brightness controls:
  - rest brightness (`menuItemRestLedLevel`) `src/HexBoard.ino:5732`
  - dim brightness (`menuItemDimLedLevel`) `src/HexBoard.ino:5749`
  - global brightness (`menuItemBright`) `src/HexBoard.ino:5760`
- These callbacks persist setting values and call `setLEDcolorCodes` as post-change hook.

### Color generation algorithm
- `setLEDcolorCodes()` is the main color synthesis function at `src/HexBoard.ino:1617`.
- For each playable hex:
  1. compute `paletteIndex = stepsFromC mod cycleLength`
  2. optionally remap to key-centered degree when `paletteBeginsAtKeyCenter` is true
  3. choose `setColor` by `colorMode`:
     - `TIERED`: direct lookup from `palette[current.tuningIndex]`
     - `RAINBOW`: linear hue across cycle
     - `RAINBOW_OF_FIFTHS`: hue permutation based on per-tuning fifth mapping
     - `PIANO_ALT`, `PIANO`, `PIANO_INCANDESCENT`: diatonic proximity/tint-based logic
     - `ALTERNATE`: interval-class style hue/saturation math
  4. derive and cache five LED codes:
     - rest (`LEDcodeRest`)
     - pressed (`LEDcodePlay`, via `tint()`)
     - out-of-scale dim (`LEDcodeDim`, via `shade()`)
     - off (`LEDcodeOff`)
     - animation (`LEDcodeAnim` initially play color)

- `getLEDcode(...)` converts HSV-like values to NeoPixel color with global brightness scaling and gamma in `src/HexBoard.ino:1607`.

### Runtime LED output path
- `animateLEDs()` marks animation flags each frame by selected animation mode in `src/HexBoard.ino:4328`.
- `applyNotePixelColor(...)` picks which cached color to display based on state priority in `src/HexBoard.ino:1927`.
- `lightUpLEDs()` writes note pixels + command/wheel overlays and flushes strip in `src/HexBoard.ino:1945`.

## 7. Coupling and Reimagining Implications

### Current architectural characteristics
- Strongly table-driven domain (tunings/layouts/palettes are static compile-time arrays).
- Selection and generation are tightly coupled in one file and global state.
- Same callbacks both mutate persistence and trigger generation.
- Single source of truth for musical placement is `stepsFromC`; this is the right seam for future modularization.

### High-value seams for a rewrite
- Separate into explicit modules:
  - `TuningCatalog` (definitions + validation)
  - `LayoutEngine` (`stepsFromC` generation)
  - `ScaleEngine` (`inScale` generation)
  - `PitchEngine` (MIDI note/channel/bend/frequency)
  - `ColorEngine` (color synthesis + caching)
  - `SettingsStore` (profile persistence)
- Define deterministic pipeline contract:
  - `selection state -> grid mapping -> pitch map -> color map`
- Replace implicit callback side effects with staged recompute flags (layout-dirty, pitch-dirty, color-dirty).
- Consider externalizing tuning/layout/palette catalogs to data files for faster iteration.

## 8. Practical Rewrite Notes

- Keep `stepsFromC` as canonical intermediate representation; it currently bridges all three requested domains cleanly.
- Preserve menu filtering behavior by tuning (`showOnlyValidLayoutChoices`, `showOnlyValidScaleChoices`, `showOnlyValidKeyChoices`) because it prevents invalid combinations.
- Preserve boot sync order from `syncSettingsToRuntime()`; changing order can create inconsistent menu/render state.
- If reworking color modes, keep cache model (`LEDcode*`) or performance may regress due to per-frame full recomputation.
