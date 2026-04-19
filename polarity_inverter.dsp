// ============================================================
//  POLARITY INVERTER — Faust DSP Source
//  File: polarity_inverter.dsp
//
//  Compile to WASM:
//    faust2wasm polarity_inverter.dsp
//
//  Or use Faust Web IDE (no install needed):
//    https://faustide.grame.fr
//    → Paste this code → Export → WASM
//
//  Or Docker:
//    docker run --rm -v $(pwd):/dsp grame/faust \
//      faust2wasm /dsp/polarity_inverter.dsp
//
//  Output files:
//    polarity_inverter.wasm
//    polarity_inverter-glue.js
// ============================================================

import("stdfaust.lib");

// ── Parameters ──────────────────────────────────────────
// Gain: -1.0 = polarity inverted (default), +1.0 = normal
gain = hslider("gain [style:knob] [unit:x]", -1.0, -1.0, 1.0, 0.001);

// ── Signal Chain ─────────────────────────────────────────
// 1. Remove DC offset + subsonic content (HPF @ 20 Hz)
hpf = fi.highpass(2, 20.0);

// 2. Invert polarity by multiplying by gain (-1 default)
invert = *(gain);

// 3. Peak limiter (1176-style, R4 ratio) — protects speakers
limiter = co.limiter_1176_R4_mono;

// ── Main process ─────────────────────────────────────────
process = hpf : invert : limiter;

// ── Stereo version (uncomment for stereo mic input) ──────
// process = par(i, 2, hpf : invert : limiter);
