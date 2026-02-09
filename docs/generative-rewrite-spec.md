# Generative Tuning and Layout Rewrite Spec

This spec defines concrete data types and function boundaries to replace fixed tuning and layout tables with generated runtime data.

## 1. Core Types

```cpp
// Limits sized for RP2040 RAM safety and deterministic serialization.
constexpr uint8_t MAX_INTERVALS = 16;
constexpr uint8_t MAX_LAYOUT_CANDIDATES = 24;

enum class LayoutFamily : uint8_t {
  BosanquetWilsonTerpstra = 0,
  HarmonicTable = 1,
  FullGamut = 2
};

// One user-selected interval role for generator scoring.
struct IntervalRole {
  int16_t steps = 0;     // interval in EDO steps, signed allowed
  bool enabled = false;
};

// Canonical generated tuning used by pitch/scale/color engines.
struct GeneratedTuning {
  uint16_t edo = 12;
  float stepSizeCents = 100.0f;   // 1200.0 / edo
  uint8_t intervalCount = 0;
  int16_t intervals[MAX_INTERVALS] = {0};
  bool valid = false;
};

// One candidate layout produced by the search engine.
struct LayoutCandidate {
  LayoutFamily family = LayoutFamily::BosanquetWilsonTerpstra;
  int8_t acrossSteps = 1;
  int8_t dnLeftSteps = -2;
  uint8_t hexMiddleC = 65;
  float score = -1.0f;
  uint8_t coverage = 0;           // playable-note coverage metric
  uint8_t spanPenalty = 0;        // lower is better
  bool valid = false;
};

// User-configurable generation inputs (menu-backed).
struct GeneratorConfig {
  uint16_t edo = 12;
  LayoutFamily family = LayoutFamily::BosanquetWilsonTerpstra;

  // Roles used differently per family but shared storage keeps UI simple.
  IntervalRole primary;
  IntervalRole secondary;
  IntervalRole tertiary;

  // Search controls.
  int8_t minVector = -24;
  int8_t maxVector = 24;
  uint8_t maxCandidates = 8;
};

// Runtime selection replaces tuningIndex/layoutIndex coupling.
struct GeneratedSelection {
  GeneratedTuning tuning;
  LayoutCandidate chosenLayout;
  LayoutCandidate candidates[MAX_LAYOUT_CANDIDATES] = {};
  uint8_t candidateCount = 0;
  uint8_t chosenCandidateIndex = 0;
};
```

## 2. Function Signatures

```cpp
// ----- Tuning generation -----

bool generateTuningFromConfig(const GeneratorConfig& cfg, GeneratedTuning& out);

// Optional helper: convert ratio to nearest EDO steps and return cents error.
int16_t quantizeRatioToEdoSteps(float ratio, uint16_t edo, float& centsErrorOut);

// Normalize intervals to [0, edo) while preserving role meaning.
void normalizeIntervals(GeneratedTuning& tuning);

// ----- Layout generation -----

void generateLayoutCandidates(
  const GeneratorConfig& cfg,
  const GeneratedTuning& tuning,
  LayoutCandidate* out,
  uint8_t outCapacity,
  uint8_t& outCount
);

float scoreLayoutCandidate(
  const LayoutCandidate& c,
  const GeneratorConfig& cfg,
  const GeneratedTuning& tuning
);

bool chooseBestLayout(
  const LayoutCandidate* candidates,
  uint8_t candidateCount,
  uint8_t& chosenIndexOut
);

// ----- Runtime apply path -----

// Copies selected generated values into current runtime state.
void applyGeneratedSelection(const GeneratedSelection& generated);

// Rebuilds stepsFromC from generated layout vectors, then reuses existing pipeline.
void applyGeneratedLayout();

// Full recompute entry point for UI callbacks.
bool regenerateFromGeneratorConfig(
  const GeneratorConfig& cfg,
  GeneratedSelection& generated,
  bool keepCurrentCandidateIfPossible
);

// ----- Compatibility bridge -----

// Keeps old code paths callable while migration is in progress.
void updateLayoutAndRotate_Generated();
void assignPitches_Generated();
void applyScale_Generated();
void setLEDcolorCodes_Generated();
```

## 3. Settings V2 Schema (Replace Fixed Enum Slots)

```cpp
struct SettingsV2 {
  uint8_t version = 2;

  GeneratorConfig generator;
  uint8_t chosenCandidateIndex = 0;

  // Existing independent controls kept as-is.
  int16_t keyStepsFromA = -9;
  int16_t transposeSteps = 0;
  bool scaleLock = false;
  uint8_t colorMode = 0;
  uint8_t restLedBrightness = 255;
  uint8_t dimLedBrightness = 255;
  uint8_t globalBrightness = 110;

  // Optional: store last generated result to avoid cold-start regeneration.
  GeneratedSelection cachedGenerated;
};
```

Migration policy:
- If old settings file is found, map legacy tuning/layout to nearest generated config defaults.
- Save immediately as V2 after successful boot conversion.

## 4. How This Works in Simple Terms

1. You choose an EDO.
2. You choose interval targets (the musical intervals you care about).
3. You choose one layout family (BWT, Harmonic Table, or Full Gamut).
4. Firmware generates several possible layouts and scores them.
5. It picks the best one (or you pick from top candidates).
6. That chosen layout is converted into the same `stepsFromC` map used today.
7. Existing systems then continue as normal:
- scale membership
- MIDI notes and bends
- LED colors

So the big change is only how tuning and layout are produced. Everything downstream can stay mostly the same.

## 5. Family-Specific Role Defaults

Recommended defaults when user has not set roles:

- Bosanquet-Wilson-Terpstra:
- primary = nearest fifth-like interval
- secondary = nearest third-like interval

- Harmonic Table:
- primary = fifth-like interval
- secondary = major/minor third-like interval

- Full Gamut:
- primary = 1 step
- secondary = octave-equivalent spread helper (auto-picked)

## 6. Minimal Integration Plan (Code Order)

1. Add new structs and generator functions behind a compile flag.
2. Add new menu page for generator config and a "Generate" action.
3. Route `applyLayout` math to generated vectors when generative mode is enabled.
4. Route tuning math (`cycleLength`, `stepSize`) to `GeneratedTuning`.
5. Switch persistence to Settings V2 with migration.
6. Remove static `tuningOptions[]` and `layoutOptions[]` only after parity testing.

## 7. Direct Mapping to Current Functions

- Replace legacy selection callbacks:
- `changeTuning(...)`
- `changeLayout(...)`

with one generated callback flow:
- `onGeneratorConfigChanged()` -> `regenerateFromGeneratorConfig(...)` -> `applyGeneratedSelection(...)`

- Keep these compute stages (internals updated to read generated state):
- `applyLayout()`
- `applyScale()`
- `assignPitches()`
- `setLEDcolorCodes()`

This keeps risk low while replacing the old static tuning/layout selection model completely.
