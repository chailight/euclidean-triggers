## 1. Teletype scene file (Phase 1)

- [x] 1.1 Create `teletype-bia.txt` with init script (`MI.$ 1 1`) and empty scripts 2–8 / metro
- [x] 1.2 Implement script 1 batch loop, CV preset lookup from pattern bank 0, and single `TR.P 1` per invocation
- [x] 1.3 Seed pattern bank 0 indices 0–11 to zero in `#P`; remove all `I2M.*` and legacy routing

## 2. Verification (Phase 1)

- [x] 2.1 Confirm scene contains no `I2M` ops and matches spec filtering (ch 1, notes 1–3 remapped to rows 0–2)

## 3. Edit preset selection (Phase 3)

- [x] 3.1 Add global **`Y`**; init to **`-1` (NONE)** on scene load
- [x] 3.2 Set **`PARAM.SCALE -1 2`** in `#I`; poll **`Y PARAM`** from metro script 3
- [x] 3.3 Map knob zones to **`Y ∈ {-1,0,1,2}`**; change-detect with **`T`** (not **`O`**)

## 4. TXI knob editing (Phase 3)

- [x] 4.1 Add metro or poll script reading **TXI PARAM 1–4**
- [x] 4.2 When **`Y ≥ 0`**, write knob values to **`PN 0 Y` … `PN 3 Y`** (VV units)
- [x] 4.3 When **`Y = -1`**, skip all TXI pattern writes

## 5. Live dashboard (Phase 3)

- [x] 5.1 Add scene placeholders and **PRINT** ops for preset label + four CV values
- [x] 5.2 Refresh dashboard on encoder preset change and on TXI knob update
- [x] 5.3 NONE state: show **NONE**; do not display editable preset values

## 6. Scene integration (Phase 3)

- [x] 6.1 Extend **`teletype-bia-v2.txt`** without changing Phase 1 scripts 1–2 behaviour
- [x] 6.2 Split new logic across scripts/metro within 6-line / 31-char limits
- [x] 6.3 Verify edited values persist across preset switches and apply on next MIDI note hit

## 7. Hardware verification (Phase 3)

- [ ] 7.1 PARAM knob: confirm scaled zones **−1 / 0 / 1 / 2** and NONE default on scene recall
- [ ] 7.2 TXI knobs: confirm 1:1 CV mapping per selected row; confirm NONE lockout
- [ ] 7.3 LIVE.DASH: confirm readouts match pattern values during edit
- [ ] 7.4 MIDI playback: confirm TR+CV unchanged while editing and after edits
