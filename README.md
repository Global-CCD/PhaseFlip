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

## Hosting & Deployment

All files must be served from the **same directory over HTTPS** — required for microphone access (`getUserMedia`) and Service Worker registration. PhaseFlip is a fully static app (no server-side code), so it deploys to any static host.

---

### Hosting Compatibility Overview

| Host | Free Tier | HTTPS | Custom Headers | COOP/COEP¹ | PWA Install | Service Worker | Custom Domain | Notes |
|---|---|---|---|---|---|---|---|---|
| **Cloudflare Pages** | ✅ Unlimited requests | ✅ | ✅ `_headers` file | ✅ | ✅ | ✅ | ✅ Free TLS | ⭐ Recommended |
| **GitHub Pages** | ✅ Public repos | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ Free TLS | No custom headers |
| **Netlify** | ✅ 100 GB/month | ✅ | ✅ `_headers` file | ✅ | ✅ | ✅ | ✅ Free TLS | Drop-in deploy |
| **Vercel** | ✅ 100 GB/month | ✅ | ✅ `vercel.json` | ✅ | ✅ | ✅ | ✅ Free TLS | `vercel.json` needed |
| **Render** | ✅ Static sites free | ✅ | ✅ via dashboard | ✅ | ✅ | ✅ | ✅ Free TLS | Git-connected |
| **Surge.sh** | ✅ Unlimited | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ paid HTTPS only | CLI deploy in seconds |
| **Firebase Hosting** | ✅ 10 GB/month | ✅ | ✅ `firebase.json` | ✅ | ✅ | ✅ | ✅ Free TLS | Requires Google account |
| **Deno Deploy** | ✅ 100K req/day | ✅ | ✅ via Worker script | ✅ | ✅ | ✅ | ✅ Free TLS | Edge-deployed |
| **Bunny.net CDN** | ❌ Pay-as-you-go | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ~$0.01/GB — cheapest CDN |
| **AWS S3 + CloudFront** | ❌ Free tier 12mo | ✅ | ✅ CloudFront policy | ✅ | ✅ | ✅ | ✅ | Overkill for this app |

> ¹ **COOP/COEP** (`Cross-Origin-Opener-Policy` + `Cross-Origin-Embedder-Policy`) are required for `SharedArrayBuffer` and WASM SIMD — needed in future roadmap versions. The current app works without them on all hosts.

**Quick pick:**
- **Zero config, best performance** → Cloudflare Pages
- **Already on GitHub, simplest** → GitHub Pages
- **Drag-and-drop, no Git required** → Netlify
- **Existing Vercel projects** → Vercel with `vercel.json`

---

### Repository Structure

Before deploying, your repo root should look like this:

```
phaseflip/
├── phaseflip.html          ← main app
├── manifest.json           ← PWA manifest
├── polarity_inverter.dsp   ← FAUST source
├── _headers                ← Cloudflare Pages headers (required)
├── _redirects              ← Cloudflare Pages redirects
├── _config.yml             ← GitHub Pages Jekyll config
└── .github/
    └── workflows/
        └── deploy.yml      ← GitHub Actions auto-deploy
```

---

### Option 1 — Cloudflare Pages ✅ Recommended

Cloudflare Pages serves over HTTPS globally via CDN and supports custom response headers via `_headers` — which is needed to set `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` (required for future WASM SIMD / SharedArrayBuffer support). Free tier is generous and includes unlimited requests.

#### Step-by-step

**1. Push repo to GitHub (or GitLab)**
```bash
git init
git add .
git commit -m "Initial PhaseFlip commit"
git remote add origin https://github.com/YOUR_USERNAME/phaseflip.git
git push -u origin main
```

**2. Connect to Cloudflare Pages**
1. Log in at [dash.cloudflare.com](https://dash.cloudflare.com)
2. Go to **Workers & Pages** → **Create** → **Pages** → **Connect to Git**
3. Authorise GitHub and select your `phaseflip` repository
4. Configure build settings:

| Setting | Value |
|---|---|
| Production branch | `main` |
| Build command | *(leave blank — no build step)* |
| Build output directory | `/` *(root)* |
| Root directory | `/` |

5. Click **Save and Deploy**

Cloudflare will assign a URL like `https://phaseflip.pages.dev` immediately.

**3. Custom domain (optional)**
- In Pages → your project → **Custom domains** → **Set up a custom domain**
- Add your domain (e.g. `phaseflip.yourdomain.com`)
- Cloudflare auto-provisions TLS

**4. Verify headers are active**
```bash
curl -I https://phaseflip.pages.dev/phaseflip.html | grep -E "permissions|cross-origin"
# Should show:
# permissions-policy: microphone=self, ...
# cross-origin-opener-policy: same-origin
# cross-origin-embedder-policy: require-corp
```

**5. Install on phone**
- Navigate to `https://phaseflip.pages.dev/phaseflip.html`
- iOS Safari: Share → **Add to Home Screen**
- Android Chrome: Menu → **Add to Home Screen** / **Install App**

#### The `_headers` file (already included)

```
/*
  Permissions-Policy: microphone=self, speaker-selection=self, autoplay=self
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  Service-Worker-Allowed: /

/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable
```

> **Note:** Without `_headers`, Cloudflare Pages still works for the current PWA. The headers become mandatory only when loading `.wasm` binaries directly or using `SharedArrayBuffer`.

---

### Option 2 — GitHub Pages ✅ Compatible

GitHub Pages serves static files over HTTPS for free from any public (or private, with Pro) repository. It does **not** support custom response headers natively — but PhaseFlip works without `COOP`/`COEP` headers in its current form (no raw `SharedArrayBuffer` usage). The AudioWorklet, Service Worker, mic access, and PWA install all work correctly on GitHub Pages.

#### Step-by-step

**1. Push repo to GitHub**
```bash
git init
git add .
git commit -m "Initial PhaseFlip commit"
git remote add origin https://github.com/YOUR_USERNAME/phaseflip.git
git push -u origin main
```

**2. Enable GitHub Pages via Actions (recommended)**

The included `.github/workflows/deploy.yml` handles this automatically on every push to `main`.

To activate it:
1. Go to your repo on GitHub → **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Push any commit — the workflow will deploy automatically

Your app will be live at:
```
https://YOUR_USERNAME.github.io/phaseflip/phaseflip.html
```

**3. Alternative: Enable GitHub Pages via branch (simpler)**
1. Go to **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: `main`, folder: `/ (root)`
4. Click **Save**

GitHub will publish within ~60 seconds at:
```
https://YOUR_USERNAME.github.io/phaseflip/
```

**4. `.nojekyll` file (important)**

GitHub Pages runs Jekyll by default, which ignores files starting with `_`. Since `_headers` and `_redirects` start with underscores, add a `.nojekyll` file to disable Jekyll processing:

```bash
touch .nojekyll
git add .nojekyll
git commit -m "Disable Jekyll"
git push
```

> The included `_config.yml` also handles this, but `.nojekyll` is the belt-and-suspenders approach.

**5. Custom domain (optional)**
1. In repo **Settings** → **Pages** → **Custom domain**, enter e.g. `phaseflip.yourdomain.com`
2. Add a `CNAME` DNS record pointing to `YOUR_USERNAME.github.io`
3. Tick **Enforce HTTPS** once DNS propagates

#### GitHub Pages limitations vs Cloudflare Pages

| Feature | GitHub Pages | Cloudflare Pages |
|---|---|---|
| HTTPS | ✅ | ✅ |
| Custom headers (`_headers`) | ❌ | ✅ |
| `SharedArrayBuffer` support | ❌ (no COOP/COEP) | ✅ |
| Bandwidth | Soft 100 GB/month | Unlimited |
| Build minutes | 2,000/month (free) | 500/month (free) |
| Deploy previews | ❌ | ✅ |
| Custom domain + TLS | ✅ | ✅ |
| PWA install works | ✅ | ✅ |
| Mic access works | ✅ | ✅ |
| Offline / Service Worker | ✅ | ✅ |

**Verdict:** Both work for the current app. Use **Cloudflare Pages** if you plan to integrate compiled `.wasm` binaries or need `SharedArrayBuffer` for the SIMD WASM path. Use **GitHub Pages** for the simplest possible setup with zero configuration.

---

### Option 3 — Local HTTPS (testing)

```bash
# Requires Node.js and mkcert
npm install -g mkcert
mkcert create-ca
mkcert create-cert

npx http-server . --ssl --cert cert.pem --key cert-key.pem -p 8080
```

Navigate on your phone to `https://<your-machine-ip>:8080/phaseflip.html` (both devices must be on the same Wi-Fi network).

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
