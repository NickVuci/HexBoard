# Phase 0 Fixture Harness

This document describes the Phase 0 migration harness added for deterministic legacy mapping dumps.

## Purpose

Phase 0 adds a compile-time debug harness that:
- keeps normal firmware behavior unchanged when disabled
- emits deterministic per-button fixture data as CSV on serial when enabled
- supports baseline capture and diff checks before Phase 1+

## Compile Flags

These flags are compile-time only and default to disabled in `src/HexBoard.ino`.

| Flag | Default | Meaning |
|---|---|---|
| `HEX_PHASE0_ENABLE` | `0` | Master switch for all Phase 0 code. |
| `HEX_PHASE0_DUMP_ON_BOOT` | `0` | Emit fixture automatically during boot. |
| `HEX_PHASE0_APPLY_BASELINE_PRESET` | `1` | Force a deterministic runtime preset before dumping. |
| `HEX_PHASE0_FIXTURE_TAG` | `"phase0-legacy"` | Tag used in sentinel lines and CSV first column. |

## Fixture Output Contract

Sentinels:
- `PHASE0_FIXTURE_BEGIN:<tag>`
- `PHASE0_FIXTURE_END:<tag>`

CSV header:
- `fixture_tag,button_index,is_playable,coord_row,coord_col,steps_from_c,in_scale,note,bend,frequency_hz,led_rest,led_play,led_dim,led_off,led_anim`

Only playable buttons are emitted (`!h[i].isCmd`), with fixed frequency formatting to 6 decimals.

## Build Instructions

### 1) Standard build (Phase 0 disabled)

```powershell
make
```

Output artifact:
- `build/build.ino.uf2`

### 2) Phase 0 dump build (enabled on boot)

```powershell
make HEX_PHASE0=1
```

Optional toggles:

```powershell
make HEX_PHASE0=1 HEX_PHASE0_DUMP_ON_BOOT=1 HEX_PHASE0_APPLY_BASELINE_PRESET=1
```

## Flash + Capture

1. Put the board in UF2 bootloader mode.
2. Copy `build/build.ino.uf2` to the `RPI-RP2` drive.
3. Capture fixture:

```powershell
powershell -ExecutionPolicy Bypass -File tools\fixtures\capture-phase0.ps1 -Port COM3
```

If only one COM port is present, `-Port` can be omitted.

## Baseline and Diff

Create baseline after first approved capture:

```powershell
Copy-Item fixtures\current\phase0-legacy.csv fixtures\baseline\phase0-legacy.csv -Force
```

Run diff check:

```powershell
powershell -ExecutionPolicy Bypass -File tools\fixtures\diff-phase0.ps1
```

## Troubleshooting

- No begin/end sentinel found:
  - Confirm Phase 0 flags were enabled at compile time.
  - Ensure you are connected to the correct COM port.
  - Increase timeout in capture script (`-TimeoutSeconds 60`).
- Multiple COM ports:
  - Pass `-Port COMx` explicitly.
- Unexpected diffs:
  - Rebuild and reboot once more.
  - Verify baseline and current files use the same firmware build.
