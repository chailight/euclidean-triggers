## Why

The existing `teletype-agent.txt` scene routes grid MIDI through i2c2midi, multiple trigger outputs, and CC-heavy helper scripts. The target instrument is a **Noise Engineering Bia**, which is **monophonic** (one trigger) but accepts **multiple simultaneous CV (and gate) inputs**. A dedicated Teletype scene maps grid note numbers to **one shared trigger** plus **preset CV sets** stored in pattern memory.

Phase 1 (MIDI → TR + CV) is implemented and validated in **`teletype-bia-v2.txt`**. The next iteration adds a **live preset editor** so CV sets can be tuned at performance time without opening Tracker.

## What Changes

**Phase 1 (complete):**

- Minimal MIDI-in → TR+CV scene on **MIDI channel 1**, notes **1–3** remapped to pattern rows **0–2**.
- **`TR.P 1`** once per batch; four CV outputs from pattern memory (`VV` units).
- No **I2C2MIDI (`I2M.*`)** dependency.

**Phase 3 (next — in scope):**

- **Teletype PARAM encoder** selects the active edit target: preset **0**, **1**, **2**, or **NONE** (stored in a global variable).
- **TXI PARAM knobs 1–4** set CV 1–4 for the selected preset row; writes go to `PN bank row`.
- **LIVE.DASH + PRINT** show the selected preset label and all four CV values for that row.
- Switching preset via encoder reloads dashboard values; **NONE** disables TXI writes to prevent accidental edits.
- MIDI play path (scripts 1–2) unchanged; edited values are live on the next note hit.

**Phase 2 (deferred):**

- TXo CV/envelope outputs per preset — postponed until after the editing UI is working.

## Capabilities

### New Capabilities

- `teletype/bia-cv-control`: Teletype scene for Bia MIDI note response, pattern-backed CV presets, and TXI/encoder live editing.

### Modified Capabilities

- _(none — no existing OpenSpec capabilities in this repo)_

## Impact

- **`teletype-bia-v2.txt`**: extended with PARAM script, TXI poll (metro or script chain), and dashboard placeholders.
- **Pattern `#P`**: same Tracker layout (rows 0–2 × banks 0–3); now writable from TXI as well as Tracker.
- **Grid / Norns scripts**: no change required.
- **Hardware**: Teletype TR 1 + CV 1–4 → Bia; **TELEXi** on i2c for four PARAM knobs. TXo not required for Phase 3.
