## Context

See `proposal.md`. The grid/Norns sequencer sends **MIDI Note On 1, 2, 3** on **channel 1** (1-based note numbers). The Bia accepts one trigger and multiple CV/gate inputs simultaneously. Teletype provides four CV outputs and four trigger outputs natively; v1 uses **one trigger** and **four CVs**.

Canonical scene file: **`teletype-bia-v2.txt`** (validated on hardware).

Current `teletype-agent.txt` uses scripts 1–8 as routers and function libraries with `BREAK`-guarded helper lines, plus `I2M.*` for outbound MIDI. The replacement scene should be **single-entry** (script 1 on Note On) with pattern-backed lookups.

Reference: [Teletype manual — Control flow, Patterns, MIDI in, TELEXi/o](https://monome.org/docs/teletype/manual/).

## Goals / Non-Goals

**Goals:**

- v1: Accept MIDI Note On on channel 1 for note numbers **1, 2, 3**, remapped to pattern rows **0, 1, 2** via **`I1 = MI.N - 1`**.
- v1: On each accepted event, **`TR.P 1`** and set **CV 1–4** from the preset set for that note.
- v1: Store all preset values in **pattern memory** with a documented, editable layout.
- **Phase 3:** Live preset editing via **PARAM encoder**, **TXI knobs 1–4**, and **LIVE.DASH**.

**Non-Goals (Phase 1):**

- i2c2midi outbound MIDI (`I2M.*`).
- Per-note trigger routing (`TR.P 2–4`) or handling note **≥ 4** (raw MIDI) / **`I1 ≥ 3`** (remapped).
- CC processing, sample triggers.

**Non-Goals (Phase 3 iteration 1):**

- TXo envelopes (**Phase 2 — deferred**).
- Per-CV encoder selection (encoder selects **preset row only**; TXI knobs map 1:1 to CV 1–4).
- Norns/grid script changes (Teletype remaps 1-based MIDI notes instead).

## Decisions

### 1. Single script entry with batched Note On handling

**Decision:** Route Note On to script 1 via `MI.$ 1 1` in `#I`. Use `L 0 MI.NL:` with **`$F1 2 - MI.N 1`** to call script 2 as a function, passing **`I1 = MI.N - 1`** (remapped preset index) for each batched event.

**Rationale:** Grid chords or simultaneous steps may produce multiple Note On events before the script runs; indexed `MI.N` / `MI.NCH` ops require a loop.

**Alternative rejected:** One line per script without batch loop — drops concurrent notes in the same invocation.

### 2. Monophonic trigger, polyphonic CV

**Decision:** **`TR.P 1` fires at most once per script 1 invocation**, even when the Note On batch contains multiple accepted events (MIDI notes **1–3** on channel 1, remapped to **`I1` 0–2**). CV 1–4 are still updated for **each** accepted event in loop order; the **last** accepted event in the batch determines the final CV values.

**Rationale:** Matches Bia monophonic trigger input — one hit per script call — while allowing CV preset morphing when several grid rows fire together.

**Trade-off:** Intermediate CV sets in a multi-note batch are applied transiently; only the last preset remains after the loop. Trigger does not re-fire per row in the same batch.

### 3. Pattern memory layout (v1)

**Decision:** Use the **Tracker grid orientation**: each **row** is a preset index **`I1` (0, 1, 2)**; each **column** is a CV output (banks 0–3 → CV 1–4). Row `I1` corresponds to MIDI notes **1, 2, 3** after subtracting 1.

```
Tracker (pattern banks 0–3 as columns):

         CV1   CV2   CV3   CV4
         bnk0  bnk1  bnk2  bnk3
I1=0     row0  row0  row0  row0   ← MIDI note 1
I1=1     row1  row1  row1  row1   ← MIDI note 2
I1=2     row2  row2  row2  row2   ← MIDI note 3
```

Lookup in script 2 (via `$F1`, using **`I1`** from `- MI.N 1`):

```teletype
CV 1 VV PN 0 I1
CV 2 VV PN 1 I1
CV 3 VV PN 2 I1
CV 4 VV PN 3 I1
```

`PN bank index` — bank = CV slot (0–3), index = **`I1`** (0–2), not raw **`MI.N`** (1–3).

**Previous (incorrect) layout** used `J * MI.N 4` and `PN 0 J`…`PN 0 J+3`, which walks **down column 0** (indices 0–3, 4–7, 8–11). That does **not** match horizontal Tracker editing: a row like `4  3  3  3` only drove CV 1 from bank 0; banks 1–3 on the same row were ignored, and row 4+ in column 0 affected a different note than expected.

**Rationale:** Matches Teletype Tracker semantics ([four banks × 64 steps](https://monome.org/docs/teletype/manual/)); one row per note preset is easy to read and edit.

**Value units:** Pattern cells store **`VV` units** (100 = 1 V, ~10 mV per step). Script applies **`VV`** at output time.

### 4. Gate outputs in v1

**Decision:** v1 specifies **four CV outputs only**. Gate-like behaviour is achieved with CV voltages (e.g. 0 vs full scale). **TR 2–4** and **TXo gate channels** remain available for a future revision if explicit gate pulses are needed.

**Rationale:** Confirmed sufficient for Bia patching in v1; avoids conflicting with the single-trigger story.

### 5. Event filtering

**Decision:**

- Reject when remapped preset index **`I1 ≥ 3`** (equivalently raw **`MI.N ≥ 4`**): **`IF GTE I1 3: BREAK`** in script 2.
- Filter on **`I1`**, not raw **`MI.N`**, whenever script 1 passes **`$F1 2 - MI.N 1`**.

Rejected events produce **no trigger** and **no CV change** — existing CV outputs hold their previous values.

**Pitfall (resolved on hardware):** Using **`IF GTE MI.N 3: BREAK`** after remapping rejects **MIDI note 3** (`MI.N = 3`) even though `I1 = 2` is a valid preset. That looked like “wrap to row 0” when mixed with unremapped **`PN … MI.N`** reads.

### 6. Scene structure (v1 target shape)

```
#I   MI.$ 1 1; LIVE.DASH 1
#1   L loop, $F1 2 - MI.N 1, TR.P 1, BREAK
#2   IF GTE I1 3, CV 1–4 via PN bank I1, X 1
#M   empty
#P   rows 0–2 × banks 0–3 (VV units)
```

Remove all `I2M.*`, `$F*`, `$L*`, `$S2`, `TO.*`, `FB.S`, and CC dashboard placeholders from v1 unless retained for unrelated reasons.

### 6a. Teletype script size limits (mandatory)

Teletype firmware enforces hard limits on every script (`#1`–`#8`, `#M`, `#I`):

| Limit | Value | Source |
|-------|-------|--------|
| Lines per script | **6** | `SCRIPT_MAX_COMMANDS` |
| Characters per line | **31** | `LINE_EDITOR_SIZE` (32 incl. null) |
| Words per command | **16** | `COMMAND_MAX_LENGTH` |

The first `teletype-bia.txt` iteration failed on hardware because script 1 contained **12 lines** (helper library + CV output). The working split is **`teletype-bia-v2.txt`**:

**Script 1** — MIDI entry (4 lines):

```teletype
X 0
L 0 MI.NL: $F1 2 - MI.N 1
IF NZ X: TR.P 1
BREAK
```

**Script 2** — CV function (6 lines, matches deployed scene):

```teletype
IF GTE I1 3: BREAK
X 1; PRINT 1 I1
CV 1 VV PN 0 MI.N
CV 2 VV PN 1 I1
CV 3 VV PN 2 I1
CV 4 VV PN 3 I1
```

Pattern: **row = `I1`** for CV 2–4; **column/bank = CV** (0–3). **`PRINT 1 I1`** + scene placeholder **`MI.N: %1`** support live debugging via **`LIVE.DASH 1`**.

Project rules: `.cursor/rules/teletype-scenes.mdc` and `openspec/config.yaml`.

### 9. MIDI note remapping (`I1 = MI.N - 1`)

**Decision:** The Norns sequencer emits **MIDI notes 1, 2, 3** (not 0, 1, 2). Rather than change the sequencer map, script 1 passes the remapped index into script 2:

```teletype
L 0 MI.NL: $F1 2 - MI.N 1
```

Inside script 2, **`I1`** holds the **pattern row** (0, 1, 2). The reject condition and CV 2–4 lookups use **`I1`**; do not filter on raw **`MI.N`** after remapping.

| MIDI `MI.N` | `I1` (= MI.N − 1) | Tracker row |
|-------------|-------------------|-------------|
| 1 | 0 | row 0 |
| 2 | 1 | row 1 |
| 3 | 2 | row 2 |
| ≥ 4 | ≥ 3 | rejected (`IF GTE I1 3: BREAK`) |

**Why the apparent “wrap” happened:** Script 1 was updated to pass **`- MI.N 1`** but script 2 still filtered on **`GTE MI.N 3`**. Note 3 was rejected while **`PN … MI.N`** (unremapped) still addressed row 3 or fell through inconsistently — behaviour that looked like row 0 “wrapping” for the third preset. Aligning the filter to **`I1`** fixed it.

**Alternative rejected:** Change Norns `map` to emit 0, 1, 2 — valid, but remapping on Teletype keeps the scene self-contained.

### 7. Phase 2 — TXo envelopes (deferred)

**Status:** Deferred until Phase 3 editing UI is complete and validated on hardware.

**Provisional direction (unchanged):** Extend each preset set with **TXo CV targets** using `TO.CV` / `TO.ENV.*` ops, triggered in time with **`TR.P 1`**. Pattern extension TBD in a future design pass.

### 10. Phase 3 — Live preset editing (next iteration)

**Decision:** Add a performance editing UI that edits the **same Phase 1 pattern layout** (rows 0–2 × banks 0–3). No pattern migration.

| Control | Role |
|---------|------|
| **Teletype PARAM knob** | **Position-based** preset zone via **`PARAM.SCALE -1 2`** → **`Y ∈ {-1, 0, 1, 2}`** |
| **Global `Y`** | Current edit preset: **`-1` = NONE**, **`0..2` = row** (read from scaled **`PARAM`**) |
| **Global `T`** | Last **`Y`** processed; skip dashboard refresh when **`Y = T`** |
| **TXI PARAM 1–4** | Set CV 1–4 of selected row (`PN 0 Y` … `PN 3 Y`) |
| **LIVE.DASH + PRINT** | Show preset label + four current **`VV`** values |
| **Metro or poll script** | Detect TXI knob changes and write pattern when **`Y ≥ 0`** |

**PARAM knob behaviour (hardware-validated fix):**

- **`#I`**: **`PARAM.SCALE -1 2`** maps full knob travel to integer **−1, 0, 1, 2** (not raw 0–16383).
- **`#3`** (metro, 50 ms): **`Y PARAM`**; if **`Y = T`**, exit; else **`T Y`** and refresh dashboard.
- **Do not use `O`** for PARAM storage — **`O`** is Teletype’s auto-increment counter and breaks delta logic.
- **Position-based**, not detent-cycling: knob zones select NONE / preset 0 / 1 / 2 across the range.
- Scene init: **`Y -1`**, **`T -1`**, **`SCRIPT 4`** for initial NONE dashboard.

**Alternative rejected:** Raw **`PARAM`** delta via **`J - X O`** — caused **`Y`** drift/wrap on dashboard; **`O`** auto-increments on read.
**Alternative rejected:** Detent cycling **`Y + J Y`** — unnecessary once **`PARAM.SCALE`** provides discrete range.

**TXI behaviour:**

- When **`Y = -1` (NONE)**: ignore all TXI input; no pattern writes.
- When **`Y ∈ {0, 1, 2}`**: map TXI PARAM **1–4** → banks **0–3** at row **`Y`**.
- On knob change, write new value to pattern and update dashboard display.
- Values stored in **`VV` units** (same as Phase 1).

**Dashboard:**

- Scene placeholders (e.g. `%1` preset label, `%2`–`%5` CV values) driven by **`PRINT`** ops.
- When NONE: display e.g. `EDIT: NONE` and omit or zero CV readouts.
- When preset N selected: display e.g. `EDIT: 0` and four values from `PN 0 Y` … `PN 3 Y`.

**MIDI play path:**

- Scripts **1–2** unchanged; they continue to read presets from pattern memory.
- Edits via TXI are immediately effective on the next accepted Note On for that row.
- NONE does not affect MIDI→TR+CV behaviour.

**Scene structure (Phase 3 target):**

```
#I   MI.$ 1 1; PARAM.SCALE -1 2; LIVE.DASH 1
#1   (Phase 1 MIDI entry — unchanged)
#2   (Phase 1 CV function — unchanged)
#3   Y PARAM; change-detect via T; SCRIPT 4
#4   preset dashboard; #5 NONE dashboard
#6–7 TXI PARAM 1–4 poll; write PN when Y ≥ 0
#M   SCRIPT 3; SCRIPT 6–7 when Y ≥ 0
#P   rows 0–2 × banks 0–3 (VV units)
```

Split across scripts/metro per **6-line / 31-char** limits (see §6a).

**Alternative rejected:** Encoder selects individual CV slot (note × CV matrix) — more steps to edit a full preset; TXI 1:1 mapping is faster for four-CV sets.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Multi-note batch applies CV multiple times before one TR | Last accepted note’s preset wins; single TR per invocation — by design |
| CV slew on Teletype causes lag between preset switches | Use `CV SET` ops or zero slew for v1; address in envelope phase for musical fades |
| Pattern values start at zero | User must tune `#P` in Tracker before musically useful output |
| TXo envelope + TR timing drift | Phase 2 deferred; spike when envelopes are scheduled |
| Accidental TXI edits during performance | **NONE** selection disables all TXI writes; default **`Y -1`** on scene load |
| TXI poll rate vs encoder responsiveness | Metro interval tuned for stable reads without blocking MIDI scripts |

## Migration Plan

1. Author new scene (keep old `teletype-agent.txt` until validated).
2. Load on Teletype; verify Note On **1–3** on ch 1 → TR 1 + CV 1–4 from Tracker rows 0–2.
3. Tune `#P` in Tracker for Bia sweet spots.
4. Archive/remove i2c2midi-dependent lines once hardware test passes.
5. **Phase 3:** Add PARAM + TXI editing; verify NONE lockout and dashboard; validate edits persist across preset switches and MIDI playback.

Rollback: reload previous scene from USB backup.

## Resolved Decisions (review)

| Question | Decision |
|----------|----------|
| Gate semantics | **Four CV voltages sufficient** in v1; TR 2–4 reserved for future if needed |
| Batch chord behaviour | **`TR.P 1` once per script invocation**; CV updated per accepted event (last wins) |
| Rejected notes | **`I1 ≥ 3`** (raw **`MI.N ≥ 4`**); no trigger, **no CV change** (outputs hold) |
| Default `#P` seeds | **All zeros** (`VV` 0 = 0 V) until user tunes in Tracker |
| MIDI note numbers | Sequencer sends **1, 2, 3**; Teletype remaps with **`$F1 2 - MI.N 1`** → **`I1`**; filter **`GTE I1 3`**, not **`GTE MI.N 3`** |
| Phase 2 TXo envelopes | **Deferred** — implement Phase 3 editing UI first |
| Edit preset selection | **`PARAM.SCALE -1 2`**; **`Y PARAM`**; **`T`** holds last **`Y`** for change-only dashboard refresh; **never use `O`** for PARAM |
| PARAM UX | **Position zones** (−1 / 0 / 1 / 2), not detent cycle |
| TXI knob mapping | PARAM **1–4** → **`PN 0..3 Y`** when **`Y ≥ 0`**; ignored when **`Y = -1`** |
| Dashboard | **LIVE.DASH + PRINT** shows selected preset + four **`VV`** values; refreshes on encoder or TXI change |
