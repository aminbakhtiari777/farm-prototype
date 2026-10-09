"""v5a ambient calls, procedurally synthesized (CC0, original work).

  adhan.ogg       - a short, gentle, voice-like call in the style of an adhan
                    (formant-synthesised "aa"/"oo" vowels, maqam-like melody
                    with ornaments, vibrato and a soft reverb tail). No words,
                    no recording - a respectful, subtle hourly cue.
  church_bell.ogg - three strikes of a tuned bell (additive bell partials).

Run:  /tmp/pwvenv/bin/python tools/synth_audio_v5a.py   (numpy + scipy + ffmpeg)
"""
import os, subprocess, tempfile
import numpy as np
from scipy.signal import butter, sosfilt, lfilter, fftconvolve
from scipy.io import wavfile

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(505)


def write(name, x, quality=4):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(quality),
                        os.path.join(OUT, name)], check=True)
    os.unlink(tmp.name)


def formant(x, f, bw):
    """Two-pole resonator."""
    r = np.exp(-np.pi * bw / SR)
    th = 2 * np.pi * f / SR
    return lfilter([1 - r], [1, -2 * r * np.cos(th), r * r], x)


def reverb(x, seconds=1.6, mix=0.3):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / (seconds / 5.5))
    ir = sosfilt(butter(2, 3000 / (SR / 2), output="sos"), ir)
    dry = np.concatenate([x, np.zeros(n)])
    wet = np.zeros(len(dry))
    w = fftconvolve(x, ir)[: len(dry)]
    wet[: len(w)] = w
    wet = wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(dry))
    return dry * (1 - mix) + wet * mix


# ------------------------------------------------------------------ adhan
BASE = 146.83  # D3
# (semitones above D, seconds, vowel) - two phrases, Hijaz-flavoured (Eb, F#).
PHRASES = [
    [(0, 0.55, "a"), (0, 0.35, "a"), (3, 0.45, "a"), (5, 0.9, "a"), (4, 0.25, "a"), (3, 0.4, "o"), (1, 0.45, "a"), (0, 1.3, "a")],
    [(5, 0.5, "a"), (7, 1.0, "a"), (8, 0.35, "a"), (7, 0.45, "a"), (5, 0.4, "o"), (4, 0.3, "a"), (3, 0.4, "a"), (1, 0.4, "a"), (0, 1.7, "a")],
]
VOWELS = {"a": [(730, 90), (1090, 110), (2440, 160)], "o": [(570, 80), (840, 100), (2410, 160)]}

parts = []
for phrase in PHRASES:
    n = int(sum(d for _, d, _ in phrase) * SR)
    f0 = np.zeros(n)
    vow = np.zeros(n)
    i = 0
    for semi, dur, v in phrase:
        m = int(dur * SR)
        f0[i:i + m] = BASE * 2 ** (semi / 12)
        vow[i:i + m] = 1.0 if v == "o" else 0.0
        i += m
    f0[i:] = f0[i - 1]
    # Smooth glides between notes (portamento) + vibrato that grows on long notes.
    f0 = sosfilt(butter(1, 6 / (SR / 2), output="sos"), np.log(f0))
    t = np.arange(n) / SR
    vib = 0.012 * np.sin(2 * np.pi * 5.4 * t) * np.clip(t / 0.8, 0, 1)
    f0 = np.exp(f0 + vib)
    f0[: int(0.05 * SR)] = f0[int(0.05 * SR)]
    phase = np.cumsum(f0) / SR
    # Glottal-ish source: band-limited sawtooth with a soft spectral tilt.
    src = np.zeros(n)
    for h in range(1, 28):
        ok = (f0 * h) < SR * 0.45
        src += ok * np.sin(2 * np.pi * h * phase) / h ** 1.2
    src += rng.standard_normal(n) * 0.02  # breath
    vow = sosfilt(butter(1, 8 / (SR / 2), output="sos"), vow)
    out = np.zeros(n)
    for k in range(3):
        fa, ba = VOWELS["a"][k]
        fo, bo = VOWELS["o"][k]
        g = [1.0, 0.6, 0.25][k]
        out += g * ((1 - vow) * formant(src, fa, ba) + vow * formant(src, fo, bo))
    a_env = np.clip(t / 0.25, 0, 1) * np.clip((t[-1] - t) / 0.9, 0, 1) ** 0.7
    parts.append(out * a_env)
    parts.append(np.zeros(int(0.55 * SR)))  # breath between phrases
adhan = reverb(np.concatenate(parts), 2.2, 0.35)
adhan = sosfilt(butter(2, [90 / (SR / 2), 5000 / (SR / 2)], btype="band", output="sos"), adhan)
write("adhan.ogg", adhan)

# ------------------------------------------------------------------ bell
F = 196.0  # G3 strike tone
PARTIALS = [(0.5, 1.0, 4.5), (1.0, 0.9, 3.2), (1.19, 0.55, 2.4), (1.5, 0.4, 1.8), (2.0, 0.45, 1.5),
            (2.51, 0.22, 1.0), (2.66, 0.18, 0.9), (3.01, 0.15, 0.7), (4.1, 0.08, 0.4)]
strike = 4.8
n = int(strike * SR)
t = np.arange(n) / SR
one = np.zeros(n)
for ratio, amp, dec in PARTIALS:
    beat = 1 + 0.08 * np.sin(2 * np.pi * (0.7 + ratio * 0.3) * t)
    one += amp * np.sin(2 * np.pi * F * ratio * t + rng.random() * 6) * np.exp(-t / dec) * beat
clang = sosfilt(butter(2, 2500 / (SR / 2), btype="high", output="sos"), rng.standard_normal(n)) * np.exp(-t / 0.02) * 0.3
one = (one + clang) * np.clip(t / 0.003, 0, 1)
total = np.zeros(int(1.7 * 2 * SR) + n + 2)
for k in range(3):
    s = int(k * 1.7 * SR)
    total[s:s + n] += one
write("church_bell.ogg", reverb(total, 1.8, 0.25))
print("wrote adhan.ogg, church_bell.ogg")
