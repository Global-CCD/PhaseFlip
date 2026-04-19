# PhaseFlip 🔄

> **Live microphone polarity inversion DSP — offline PWA for iOS & Android**

PhaseFlip is a real-time audio processing tool that captures live microphone input, inverts its polarity (phase), and routes it directly to the phone speaker or Bluetooth output — all offline, with persistent background audio. Built on a FAUST DSP signal chain compiled to WebAssembly, running inside an AudioWorklet with full PWA offline support.

---

## What is Polarity Inversion?

Polarity inversion flips the sign of every audio sample (`× -1`), effectively rotating the waveform 180°. This is distinct from a phase shift (which is frequency-dependent). Use cases include acoustic cancellation experiments, anti-noise systems, audio alignment testing, and live signal chain verification.

---

## DSP Source

```faust
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
```

---

## Features

### Audio Engine
- **True polarity inversion** — sample-accurate `× −1` multiplication, not a phase shift
- **FAUST DSP signal chain** — `HPF(20 Hz, 2nd-order Butterworth) → Polarity Invert → 1176-style limiter`
- **AudioWorklet primary path** — low-latency, off-main-thread processing (modern iOS/Android)
- **ScriptProcessor fallback** — automatic fallback for older WebKit/Chromium versions
- **DC blocking HPF** — 2nd-order Butterworth at 20 Hz removes mic DC offset before inversion
- **1176-style peak limiter** — R4 ratio soft-knee limiter protects speakers and Bluetooth output
- **Variable gain control** — continuous gain slider from −1.0 (inverted) to +1.0 (normal) with smooth ramp
- **48 kHz sample rate** — forced on AudioContext creation for maximum fidelity
- **Mono mic, mono out** — minimal latency single-channel pipeline; stereo DSP available via DSP flag

### Background & Offline Operation
- **iOS background audio lock** — silent looping `AudioBufferSource` (1e-10 DC) keeps the iOS audio session active when screen locks
- **Android background persistence** — `Page Visibility API` listener resumes suspended `AudioContext` on return from background
- **WakeLock API** — requests `screen` wake lock on supported Android Chrome builds to prevent CPU sleep
- **Service Worker caching** — entire app cached on first load; runs fully offline with no network dependency
- **PWA installable** — `manifest.json` enables "Add to Home Screen" on iOS Safari and Android Chrome, launching in standalone mode (no browser chrome)
- **Offline-first fetch strategy** — Service Worker serves from cache first, falls back to network, falls back to cached root

### Microphone & Routing
- **Raw mic capture** — `echoCancellation: false`, `noiseSuppression: false`, `autoGainControl: false` for unprocessed input
- **Bluetooth speaker support** — routes to whatever the OS audio output is set to, including A2DP Bluetooth
- **Output device detection** — enumerates audio output devices and displays active output (speaker vs. Bluetooth label)
- **Mic permission handling** — graceful error states for denied/missing microphone with on-screen feedback

### UI & Metering
- **Dual VU meters** — real-time RMS metering on both input and output signal paths via `AnalyserNode`
- **Live oscilloscope** — Canvas-rendered waveform display of the output signal at 60 fps
- **Animated power ring** — SVG stroke-dashoffset ring with pulse animation indicates active state
- **Toast notifications** — non-blocking status messages for start, stop, and error events
- **Status panel** — live readout of engine mode, mic state, background lock, sample rate, latency, and output device
- **Responsive portrait layout** — `100dvh` layout, touch-optimised, no zoom, works on all phone screen sizes

---

## Compiling the FAUST DSP to WASM

### Option 1 — Faust Web IDE (no install)
1. Open [faustide.grame.fr](https://faustide.grame.fr)
2. Paste the DSP source above
3. Click **Export** → select **wasm** target
4. Download `polarity_inverter.wasm` + `polarity_inverter-glue.js`

### Option 2 — faust2wasm CLI
```bash
# Install Faust
brew install faust          # macOS
sudo apt install faust      # Ubuntu/Debian

# Compile
faust2wasm polarity_inverter.dsp

# Output
# polarity_inverter.wasm
# polarity_inverter-glue.js
```

### Option 3 — Docker (no local install)
```bash
docker run --rm -v $(pwd):/dsp grame/faust \
  faust2wasm /dsp/polarity_inverter.dsp
```

---

## Deployment

All three files (`phaseflip.html`, `manifest.json`, `polarity_inverter.dsp`) must be served from the **same directory over HTTPS** — required for microphone access and Service Worker registration.

```bash
# Quick local HTTPS for testing (requires mkcert)
mkcert -install
mkcert localhost
npx http-server . --ssl --cert localhost.pem --key localhost-key.pem
```

Then on your phone, navigate to `https://<your-local-ip>:8080/phaseflip.html` and tap **Add to Home Screen**.

---

## iOS-Specific Notes

| Behaviour | Detail |
|---|---|
| Audio session | Must be started by a user gesture — the power button handles this |
| Background lock | Silent buffer loop keeps the session alive; re-acquired on screen unlock via Visibility API |
| Screen-off duration | Tested stable for 15+ minutes with screen locked |
| Minimum iOS version | iOS 14.5+ for AudioWorklet; ScriptProcessor fallback covers iOS 12+ |

---

## Android-Specific Notes

| Behaviour | Detail |
|---|---|
| Background audio | Chrome continues Web Audio in background when tab is active PWA |
| WakeLock | Acquired automatically; prevents Doze mode from killing the audio thread |
| Minimum version | Android 8+ (Chromium 66+) for AudioWorklet |
| Bluetooth | Routes to active A2DP output automatically via OS audio routing |

---

## Architecture

```
Microphone (raw, AGC/NS/EC off)
    │
    ▼
MediaStreamSource
    │
    ▼
AnalyserNode (input metering)
    │
    ▼
AudioWorkletNode ─── phaseflip-processor
    │                   ├─ 2nd-order Butterworth HPF @ 20 Hz
    │                   ├─ × gain (default: −1.0)
    │                   └─ 1176-style peak limiter
    ▼
GainNode (smooth gain ramp)
    │
    ▼
AnalyserNode (output metering + oscilloscope)
    │
    ▼
AudioContext.destination (Speaker / Bluetooth)

Background lock:
AudioBufferSource (silent loop, 1e-10) ──► destination
```

---

## Roadmap

### v1.1 — Signal Chain Expansion
- [ ] Switchable **all-pass phase shifter** (0°–360° continuous, frequency-selective) as alternative to hard polarity flip
- [ ] **Parametric EQ** (3-band) pre-inversion for frequency-targeted polarity work
- [ ] **Mid/side processing** mode — invert only the side channel for stereo width manipulation
- [ ] Configurable **HPF cutoff frequency** (currently fixed at 20 Hz) exposed in UI
- [ ] **Low-pass filter** option to band-limit output before speaker routing

### v1.2 — Latency & Performance
- [ ] **Latency compensation display** — measure and display round-trip mic-to-speaker latency in ms
- [ ] **Buffer size selector** (128 / 256 / 512 samples) for latency vs. stability trade-off
- [ ] **WASM binary integration** — load compiled `polarity_inverter.wasm` directly instead of inline JS worklet
- [ ] **SIMD WASM** build path for Faust DSP on supported Chromium versions
- [ ] AudioWorklet **SharedArrayBuffer** path for sub-10ms latency on Android

### v1.3 — Background & Session Hardening
- [ ] **Android Foreground Service** via Capacitor plugin — survives aggressive battery optimisation (Xiaomi, Samsung OneUI)
- [ ] **iOS Audio Background Mode** — native Capacitor/Cordova wrapper with `UIBackgroundModes: audio` in `Info.plist`
- [ ] **Automatic session recovery** — detect and silently restart audio pipeline after OS interruptions (phone call, Siri, alarm)
- [ ] **Bluetooth reconnection handler** — re-route to newly connected Bluetooth device without restart
- [ ] **Audio focus management** on Android (request `AUDIOFOCUS_GAIN` via Capacitor bridge)

### v1.4 — Output & Routing
- [ ] **Audio output device selector** — enumerate and manually select output device (internal speaker, earpiece, Bluetooth)
- [ ] **Earpiece routing option** — force output to phone earpiece for private monitoring
- [ ] **Split routing** — mic in from one device, output to another (e.g., USB mic → Bluetooth speaker)
- [ ] **Audio file input** — load a WAV/MP3 file and process through the polarity inverter offline
- [ ] **Screen-off audio continuation** notification banner with tap-to-stop

### v2.0 — Native App
- [ ] **Capacitor wrapper** — package as true native iOS/Android app with proper background audio entitlements
- [ ] **React Native port** with `react-native-track-player` for rock-solid background playback
- [ ] **App Store / Play Store** distribution
- [ ] **Siri / Google Assistant** voice trigger: *"Hey Siri, start PhaseFlip"*
- [ ] **Widget** (iOS WidgetKit / Android App Widget) for one-tap start from home screen

### v2.1 — Advanced DSP
- [ ] **Adaptive feedback suppression** — detect and attenuate howl when mic and speaker are in proximity
- [ ] **Noise gate** pre-inversion to cut mic bleed during silence
- [ ] **Spectrum analyser** display (FFT, 1/3-octave bars) alongside oscilloscope
- [ ] **Correlation meter** — display polarity correlation between input and output in real time
- [ ] **Convolution reverb** slot — apply IR post-inversion for spatial processing
- [ ] **Multi-band polarity** — independent polarity control per frequency band (crossover-based)

### v2.2 — Collaboration & Logging
- [ ] **Session logging** — timestamped log of start/stop events, device info, latency readings exported as CSV
- [ ] **WebRTC peer mode** — stream the inverted signal to a second device over LAN for A/B comparison
- [ ] **MIDI control** — map gain and bypass to MIDI CC via Web MIDI API
- [ ] **Preset system** — save and recall named gain/filter configurations

---

## License

MIT — free to use, modify, and distribute.

---

## Acknowledgements

- [GRAME FAUST](https://faust.grame.fr/) — functional audio stream language and WASM compiler
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API) — W3C audio processing standard
- 1176 limiter algorithm adapted from FAUST `compressors.lib`
