"""v5b voice blips + sneeze + cooking SFX (CC0, original).
Run: /tmp/pwvenv/bin/python tools/synth_audio_v5b.py
"""
from __future__ import annotations
import math, os, struct, wave, subprocess, tempfile
import numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050


def write_ogg(path: str, samples: np.ndarray) -> None:
    samples = np.clip(samples, -1, 1)
    pcm = (samples * 32767).astype(np.int16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    with wave.open(wav, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", path])
    os.unlink(wav)
    print("wrote", path, "%.2fs" % (len(samples) / SR))


def env(n, a=0.01, r=0.04):
    e = np.ones(n)
    aa = int(a * SR); rr = int(r * SR)
    if aa: e[:aa] = np.linspace(0, 1, aa)
    if rr: e[-rr:] = np.linspace(1, 0, rr)
    return e


def vowel(f1, f2, f3, dur=0.12, pitch=180.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Buzz + formants via band-pass resonances (simple additive).
    buzz = np.sign(np.sin(2 * math.pi * pitch * t)) * 0.25
    # Soften buzz
    buzz = np.convolve(buzz, np.ones(8)/8, mode="same")
    out = np.zeros(n)
    for f, a in ((f1, 0.55), (f2, 0.35), (f3, 0.18)):
        # Resonant ring: impulse train filtered by exponential decay sine.
        carrier = np.sin(2 * math.pi * f * t)
        damp = np.exp(-t * (f * 0.012 + 8))
        out += a * carrier * damp * (0.6 + 0.4 * buzz)
    out *= env(n, 0.008, 0.035) * 0.9
    return out.astype(np.float64)


def hum(dur=0.16, pitch=140.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = 0.45 * np.sin(2 * math.pi * pitch * t)
    out += 0.18 * np.sin(2 * math.pi * pitch * 2 * t)
    out += 0.08 * np.sin(2 * math.pi * pitch * 3 * t)
    out *= env(n, 0.02, 0.05)
    return out


def sneeze():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    noise = np.random.randn(n)
    # Banded noise "ahh" then burst
    ah = noise * np.exp(-t * 6) * 0.25
    ah *= (0.5 + 0.5 * np.sin(2 * math.pi * 900 * t))
    burst = np.zeros(n)
    b0 = int(0.18 * SR)
    burst[b0:] = np.random.randn(n - b0) * np.exp(-(t[b0:] - t[b0]) * 28) * 0.9
    out = (ah + burst) * env(n, 0.01, 0.05)
    return out


def chop():
    n = int(0.12 * SR)
    noise = np.random.randn(n)
    out = noise * np.exp(-np.arange(n) / SR * 40) * 0.7
    # Woody thud
    t = np.arange(n) / SR
    out += 0.4 * np.sin(2 * math.pi * 120 * t) * np.exp(-t * 30)
    return out * env(n, 0.002, 0.04)


def sprinkle():
    n = int(0.18 * SR)
    out = np.random.randn(n) * 0.15
    # High ticks
    for k in range(6):
        i = int((0.02 + k * 0.025) * SR)
        if i < n:
            out[i:i+40] += np.random.randn(min(40, n-i)) * 0.5 * np.exp(-np.arange(min(40, n-i))/8)
    return out * env(n, 0.005, 0.04)


def sizzle(dur=0.6):
    n = int(dur * SR)
    out = np.random.randn(n) * 0.22
    # High-pass-ish by differencing
    out = np.diff(out, prepend=0) * 0.6
    t = np.arange(n) / SR
    out *= 0.6 + 0.4 * np.sin(2 * math.pi * 8 * t)
    return out * env(n, 0.05, 0.1)


def eat():
    n = int(0.2 * SR)
    out = np.zeros(n)
    for k, p in enumerate((180, 220, 160)):
        i = int(k * 0.05 * SR)
        m = int(0.06 * SR)
        tt = np.arange(m) / SR
        chunk = 0.5 * np.sin(2 * math.pi * p * tt) * np.exp(-tt * 25)
        out[i:i+m] += chunk[:max(0, min(m, n-i))]
    out += np.random.randn(n) * 0.05 * np.exp(-np.arange(n)/SR * 12)
    return out * env(n, 0.005, 0.04)


def main():
    voice = os.path.join(ROOT, "assets/audio/voice")
    sfx = os.path.join(ROOT, "assets/audio/sfx")
    # Vowels a e i o u (formants approx)
    for name, f in [("a", (700, 1200, 2500)), ("e", (500, 1800, 2500)), ("i", (300, 2200, 3000)),
                    ("o", (500, 900, 2500)), ("u", (350, 700, 2400))]:
        write_ogg(os.path.join(voice, f"blip_{name}.ogg"), vowel(*f, dur=0.11, pitch=170))
    for i, p in enumerate((130, 160, 200)):
        write_ogg(os.path.join(voice, f"hum_{i}.ogg"), hum(0.15, p))
    write_ogg(os.path.join(sfx, "sneeze.ogg"), sneeze())
    write_ogg(os.path.join(sfx, "chop.ogg"), chop())
    write_ogg(os.path.join(sfx, "sprinkle.ogg"), sprinkle())
    write_ogg(os.path.join(sfx, "sizzle.ogg"), sizzle())
    write_ogg(os.path.join(sfx, "eat.ogg"), eat())

if __name__ == "__main__":
    main()
