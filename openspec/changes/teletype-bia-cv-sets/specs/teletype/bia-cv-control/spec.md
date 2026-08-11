## Purpose

Defines Teletype scene behavior for driving a monophonic Noise Engineering Bia from grid-origin MIDI notes: one shared trigger output, pattern-backed CV preset sets per note, live TXI/encoder editing (Phase 3), and deferred TXo envelope extension (Phase 2).

## ADDED Requirements

### Requirement: MIDI input routing (Phase 1)

The Teletype init script SHALL assign **script 1** to receive **MIDI Note On** events (type 1) via `MI.$ 1 1`. No other MIDI event types are required for Phase 1 operation.

#### Scenario: Scene load wires Note On to script 1

- **WHEN** the scene is recalled and the init script runs
- **THEN** incoming USB MIDI Note On events invoke script 1

---

### Requirement: Channel and note filtering (Phase 1)

Script 1 SHALL process Note On events on **MIDI channel 1** with raw note numbers **1, 2, or 3**, remapped to preset index **`I1 = MI.N - 1`** (rows **0, 1, 2**). Events with **`I1 ≥ 3`** (raw **`MI.N ≥ 4`**) SHALL be ignored with no trigger pulse and no CV update.

#### Scenario: Valid note on channel 1

- **WHEN** a Note On arrives for MIDI note 1, 2, or 3 on channel 1
- **THEN** the note-response behavior runs (trigger + CV preset load from row `MI.N - 1`)

#### Scenario: Note out of range

- **WHEN** a Note On arrives for raw note 4 or higher on MIDI channel 1
- **THEN** no trigger is emitted, CV outputs are not updated, and previously set CV values are unchanged

#### Scenario: Wrong MIDI channel

- **WHEN** a Note On arrives on any channel other than 1
- **THEN** the event is ignored

---

### Requirement: Monophonic trigger output (Phase 1)

When script 1 processes one or more accepted Note On events in a single invocation, the scene SHALL emit **at most one** trigger pulse on **Teletype trigger output 1** (`TR.P 1`) for that invocation, regardless of how many accepted events appear in the batch.

#### Scenario: Single accepted note fires TR 1 once

- **WHEN** exactly one accepted note (1, 2, or 3 on channel 1) is processed in a script invocation
- **THEN** `TR.P 1` executes exactly once

#### Scenario: Multiple accepted notes in one batch fire TR 1 once

- **WHEN** two or more accepted notes on channel 1 arrive in the same batch
- **THEN** `TR.P 1` executes exactly once for that script invocation

---

### Requirement: Four CV outputs per note preset (Phase 1)

For each accepted Note On event, the scene SHALL set **CV 1, CV 2, CV 3, and CV 4** by reading four values from pattern memory at row **`I1`** and converting each with the **`VV`** op before output.

#### Scenario: MIDI note 1 loads row 0

- **WHEN** MIDI note 1 on channel 1 is accepted (`I1 = 0`)
- **THEN** CV 1–4 are set from `PN 0 0`, `PN 1 0`, `PN 2 0`, `PN 3 0` respectively

#### Scenario: MIDI note 2 loads row 1

- **WHEN** MIDI note 2 on channel 1 is accepted (`I1 = 1`)
- **THEN** CV 1–4 are set from `PN 0 1`, `PN 1 1`, `PN 2 1`, `PN 3 1` respectively

#### Scenario: MIDI note 3 loads row 2

- **WHEN** MIDI note 3 on channel 1 is accepted (`I1 = 2`)
- **THEN** CV 1–4 are set from `PN 0 2`, `PN 1 2`, `PN 2 2`, `PN 3 2` respectively

---

### Requirement: Pattern storage layout (Phase 1)

Preset CV values SHALL be stored to match **Teletype Tracker layout**: pattern **index** (row) = preset index **`I1` (0, 1, 2)**; pattern **bank** (column) = CV output slot (0–3 for CV 1–4).

| Row (`I1`) | MIDI note | CV 1 (bank 0) | CV 2 (bank 1) | CV 3 (bank 2) | CV 4 (bank 3) |
|------------|-----------|---------------|---------------|---------------|---------------|
| 0          | 1         | `PN 0 0`      | `PN 1 0`      | `PN 2 0`      | `PN 3 0`      |
| 1          | 2         | `PN 0 1`      | `PN 1 1`      | `PN 2 1`      | `PN 3 1`      |
| 2          | 3         | `PN 0 2`      | `PN 1 2`      | `PN 2 2`      | `PN 3 2`      |

The play script SHALL read presets with `CV n VV PN n-1 I1` for `n` ∈ {1..4}.

Values SHALL be readable and editable in Tracker without a vertical index-offset scheme (no `* MI.N 4` base on bank 0 only).

#### Scenario: Horizontal Tracker edit for row 0

- **WHEN** a user sets row 0 to `200  100  500  500` across the four Tracker columns and MIDI note 1 fires
- **THEN** CV 1–4 reflect those four values (after `VV` conversion)

#### Scenario: Tracker edit persists

- **WHEN** a user changes bank 1 at row 1 and MIDI note 2 fires
- **THEN** CV 2 reflects the updated value

---

### Requirement: Batched Note On handling (Phase 1)

When multiple Note On events arrive before script 1 runs, script 1 SHALL iterate all pending Note On events (using indexed MIDI ops and a loop over `MI.NL`). For each **accepted** event (channel 1, `I1` 0–2), it SHALL update CV 1–4 from that note’s preset set. After processing the batch, if at least one event was accepted, it SHALL fire **`TR.P 1` exactly once**.

#### Scenario: Two valid notes in one batch

- **WHEN** MIDI notes 1 and 3 on channel 1 arrive in the same batch
- **THEN** `TR.P 1` fires once, CV 1–4 are updated for row 0 then row 2 during the loop, and the final CV values match row 2’s preset set

#### Scenario: Batch with no accepted notes

- **WHEN** a batch contains only rejected events (e.g. raw note 5 on channel 1)
- **THEN** `TR.P 1` does not fire and CV outputs are unchanged

---

### Requirement: Default pattern values (Phase 1)

The shipped scene SHALL initialize the twelve preset cells (Tracker rows 0–2, banks 0–3) to **0** (`VV` 0 = 0 V).

#### Scenario: Fresh scene CV output before tuning

- **WHEN** the scene is loaded with default pattern data and an accepted note event occurs before any edits
- **THEN** CV 1–4 are set to 0 V

---

### Requirement: Teletype script size limits (Phase 1)

Every script block in the scene (`#1`–`#8`, `#M`, `#I`) SHALL contain **at most 6 non-empty command lines**. Every command line SHALL be **at most 31 characters**. No single command SHALL exceed **16 space-separated words**.

When logic exceeds these limits, the scene SHALL split across multiple scripts using **`$F1` / `$F2`**, **`$S1`**, **`$L1`**, **`SCRIPT`**, and **`BREAK`** without changing observable MIDI→TR+CV behaviour.

#### Scenario: Script 1 within line budget

- **WHEN** the Phase 1 scene is inspected
- **THEN** script 1 contains no more than 6 non-empty lines

#### Scenario: Long CV preset logic uses a helper script

- **WHEN** batch MIDI handling and four `CV … VV PN` assignments cannot fit in one script
- **THEN** the entry script calls a helper script (e.g. `$F1 2 - MI.N 1`) and remains within the 6-line limit

---

### Requirement: No i2c2midi dependency (Phase 1)

The Phase 1 scene SHALL NOT use I2C2MIDI operators (`I2M.*`). Outbound note or CC transmission via i2c2midi is out of scope.

#### Scenario: Scene contains no I2M ops

- **WHEN** the Phase 1 scene is inspected
- **THEN** no `I2M` operators appear in any script

---

### Requirement: Edit preset selection (Phase 3)

The scene SHALL store the active edit preset in global variable **`Y`**:

- **`Y = -1`**: **NONE** — no preset selected for editing.
- **`Y ∈ {0, 1, 2}`**: preset row selected for editing.

The scene SHALL map the Teletype **PARAM** knob to preset index **`Y ∈ {-1, 0, 1, 2}`** using **`PARAM.SCALE -1 2`** in the init script. **`Y = -1`** is NONE; **`Y ∈ {0, 1, 2}`** selects pattern rows 0–2.

Script 3 SHALL read **`Y PARAM`** on each metro tick and refresh the dashboard only when **`Y`** differs from global **`T`** (last processed value).

The scene SHALL NOT use variable **`O`** for PARAM or preset state — **`O`** is Teletype’s auto-increment counter.

#### Scenario: Knob zones select presets

- **WHEN** the user moves the PARAM knob through its scaled range
- **THEN** **`Y`** takes values **−1, 0, 1, or 2** corresponding to knob position (NONE, preset 0, 1, 2)

#### Scenario: Dashboard updates on zone change only

- **WHEN** **`Y PARAM`** equals **`T`** on a metro tick
- **THEN** script 3 exits without re-printing the dashboard

#### Scenario: Scene loads with safe default

- **WHEN** the scene is recalled
- **THEN** **`Y`** and **`T`** are **−1** and the dashboard shows NONE until the knob moves to another zone

---

### Requirement: TXI knob editing (Phase 3)

When **`Y ≥ 0`**, **TELEXi PARAM inputs 1–4** SHALL map to CV 1–4 of preset row **`Y`**:

- TXI PARAM 1 → `PN 0 Y` (CV 1)
- TXI PARAM 2 → `PN 1 Y` (CV 2)
- TXI PARAM 3 → `PN 2 Y` (CV 3)
- TXI PARAM 4 → `PN 3 Y` (CV 4)

When a TXI input changes, the scene SHALL write the new value (in **`VV` units**) to the corresponding pattern cell and update the live dashboard.

When **`Y = -1` (NONE)**, TXI input changes SHALL NOT modify pattern memory.

#### Scenario: TXI knob adjusts CV 2 of preset 1

- **WHEN** `Y = 1` and the user moves TXI PARAM 2
- **THEN** `PN 1 1` is updated and the dashboard reflects the new value

#### Scenario: NONE prevents accidental edits

- **WHEN** `Y = -1` and the user moves any TXI PARAM control
- **THEN** no pattern cells change

#### Scenario: Edited value used on next note hit

- **WHEN** the user sets `PN 0 0` via TXI PARAM 1 and MIDI note 1 fires
- **THEN** CV 1 reflects the edited value

---

### Requirement: Live dashboard (Phase 3)

The scene SHALL enable **LIVE.DASH** and use **PRINT** ops to display:

1. The currently selected edit preset (**NONE** or row **0–2**).
2. The four CV values (`PN 0 Y` … `PN 3 Y`) for the selected preset when **`Y ≥ 0`**.

The dashboard SHALL refresh when:

- The user changes preset selection via the PARAM encoder.
- A TXI knob updates a CV value while a preset is selected.

#### Scenario: Dashboard shows selected preset values

- **WHEN** the user selects preset 2 via the encoder
- **THEN** the dashboard displays preset 2 and the four values from `PN 0 2` … `PN 3 2`

#### Scenario: Dashboard shows NONE

- **WHEN** `Y = -1`
- **THEN** the dashboard indicates NONE and does not show editable preset CV values (or shows placeholders indicating no selection)

#### Scenario: Dashboard updates on TXI change

- **WHEN** `Y = 0` and TXI PARAM 3 changes
- **THEN** the dashboard CV 3 readout updates to match the new `PN 2 0` value

---

### Requirement: MIDI play unaffected by edit UI (Phase 3)

MIDI Note On handling (scripts 1–2) SHALL behave per Phase 1 requirements regardless of edit selection state. Selecting a preset or editing via TXI SHALL NOT block, alter, or replace the MIDI batch loop or trigger semantics.

#### Scenario: MIDI works while editing

- **WHEN** `Y = 1` and a valid Note On arrives on channel 1
- **THEN** `TR.P 1` and CV output behave per Phase 1 using pattern values (including any TXI edits)

#### Scenario: NONE does not affect MIDI

- **WHEN** `Y = -1` and a valid Note On arrives
- **THEN** MIDI→TR+CV behaviour is identical to Phase 1

---

### Requirement: TXo CV and envelope extension (Phase 2 — deferred)

Phase 2 TXo envelope outputs per preset set are **deferred**. They SHALL NOT be implemented in the Phase 3 iteration. A future revision MAY add **TELEXo (TXo)** envelope outputs triggered with `TR.P 1`; normative detail is deferred until Phase 2 is scheduled.

#### Scenario: Phase 3 scene has no TXo envelope ops

- **WHEN** the Phase 3 scene is inspected
- **THEN** no `TO.ENV.*` envelope triggering is required for acceptance

---

### Requirement: Gate outputs (future — placement TBD)

The full feature vision includes **gate** values alongside CV for the Bia. Phase 1 implements four **CV outputs only**; gate-like behaviour uses CV voltage levels. A future revision MAY map explicit gate signals to **TR 2–4** or TXo channels; that mapping SHALL be defined before implementation and SHALL NOT alter the Phase 1 pattern index map for CV 1–4 without a documented migration.

#### Scenario: Phase 1 has no separate gate TR routing

- **WHEN** Phase 1 scene is active
- **THEN** only `TR.P 1` is used for note events; TR 2–4 are not pulsed by note handling
