# Generative Firmware Migration Plan (Reference)

This document is the canonical implementation plan for safely replacing static tuning/layout selection with the new generative method.

Related docs:
- `docs/firmware-reimagining-notes.md`
- `docs/generative-rewrite-spec.md`

## Goal

Replace legacy static tuning/layout tables with a generated pipeline based on:
- user-selected EDO
- user-selected interval targets
- selected layout family (Bosanquet-Wilson-Terpstra, Harmonic Table, Full Gamut)

Do this incrementally, with validation gates and rollback options at every phase.

## Safety Strategy

We will not do a hard cutover. We will:
1. Keep legacy and generative paths side-by-side.
2. Add deterministic validation outputs first.
3. Ship changes behind feature flags.
4. Remove legacy only after parity and soak validation.

## Phase Plan

| Phase | Change Set | Validation | Exit Gate | Rollback |
|---|---|---|---|---|
| 0 | Add migration flags and debug dump harness | Build succeeds; legacy behavior unchanged | Baseline fixtures captured from legacy path | Disable new flag |
| 1 | Add new data structs only (`GeneratedTuning`, `GeneratorConfig`, `LayoutCandidate`, `GeneratedSelection`) | Build succeeds; no runtime behavior change | No code path depends on new structs yet | Remove or ignore new structs |
| 2 | Implement pure generator math (interval normalize/quantize, candidate search, scoring) | Deterministic outputs for fixed inputs across reboots | Candidate ranking stable for fixed seeds/config | Stop calling generator math |
| 3 | Add generated apply function (`applyGeneratedLayout`) but keep legacy active | A/B compare `stepsFromC` with equivalent legacy vectors | `stepsFromC` parity for baseline equivalent cases | Route back to legacy apply path |
| 4 | Abstract tuning reads (`cycleLength`, `stepSize`) behind active accessors | Legacy mode output unchanged (fixture diff = none) | Full parity in legacy mode | Revert accessor use sites |
| 5 | Add generator UI page (EDO, intervals, family, Generate) without removing old menus | UI stable, no crashes, legacy menus still usable | New page usable; old flow unaffected | Hide generator page |
| 6 | Wire generated selection into full runtime apply chain | End-to-end note mapping + scales + LEDs work in generative mode | Manual matrix passes in both modes | Switch default back to legacy |
| 7 | Add Settings V2 + migration from legacy settings | Boot migration works with existing settings file; persistence stable | Reboot and save/load pass in both modes | Keep dual-read and write legacy fallback |
| 8 | Make generative mode default; keep legacy fallback for one release cycle | Soak/regression testing on real device(s) | No critical regressions observed | Flip default to legacy |
| 9 | Remove static tuning/layout selection code | Build + flash smoke tests pass | Legacy path not needed anymore | Keep removal on separate branch until stable |

## Validation Harness Requirements

Implement this before behavior changes:
1. Deterministic mapping dump for a fixed test state.
2. Dump fields per playable button:
- `stepsFromC`
- `inScale`
- `note`
- `bend`
- `frequency`
- active LED color code state
3. Save baseline fixtures from legacy path for known presets.
4. Re-run and diff fixtures after each phase.

## Manual Test Matrix (Run Every Phase That Touches Runtime)

1. Boot with no settings file.
2. Boot with existing settings file.
3. Legacy tuning/layout changes.
4. Generative tuning/layout generation and selection.
5. Key change and transpose.
6. Scale lock on/off.
7. MIDI in/out behavior including note on/off.
8. Color mode + brightness changes.
9. Save, reboot, verify restoration.

## High-Risk Areas

These must be changed with extra caution:
1. Settings sync order in `src/HexBoard.ino:5898`.
2. Apply chain coupling around `src/HexBoard.ino:4473`.
3. Settings enum/index persistence model at `src/HexBoard.ino:4547`.
4. Selection callbacks with side effects:
- `src/HexBoard.ino:6125` (`changeTuning`)
- `src/HexBoard.ino:6059` (`changeLayout`)

## Implementation Rules

1. Keep each phase in a dedicated commit.
2. Never combine schema migration and behavioral rewrites in one commit.
3. Require fixture diff review before advancing phases.
4. Keep legacy fallback available until Phase 9 exit gate is met.
5. If a phase fails validation, revert to prior gate and fix before continuing.

## Definition of Done

Migration is complete only when:
1. Generative mode is default and stable.
2. Settings V2 migration is verified on real old settings files.
3. Manual matrix passes on target hardware.
4. Legacy static tuning/layout code is removed.
5. This plan doc is updated with final implementation notes and deviations.

## Progress Log Template

Use this section as implementation proceeds.

### Phase Status

- Phase 0: pending
- Phase 1: pending
- Phase 2: pending
- Phase 3: pending
- Phase 4: pending
- Phase 5: pending
- Phase 6: pending
- Phase 7: pending
- Phase 8: pending
- Phase 9: pending

### Notes

- _Add date + summary for each phase completion, validation evidence, and any deviations._
