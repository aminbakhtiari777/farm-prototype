"""v6a music loops + campfire crackle (CC0, original, synthesized here).
Run: /tmp/pwvenv/bin/python tools/synth_audio_v6a.py
  assets/audio/music/gym_loop.ogg     upbeat 120 bpm electronic loop (gym)
  assets/audio/music/radio_loop.ogg   gentle santur-like melody over a drone (home radios, cafe)
  assets/audio/music/zarb_loop.ogg    tombak / zarb 6/8 drum groove + drone (zurkhaneh-style)
  assets/audio/ambience/campfire_loop.ogg  fire crackle
All loops are seamless (whole bars, tails wrapped around).
"""
from __future__ import annotations
import math, os, wave, subprocess, tempfile
import numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
rng = np.random.default_rng(606)


def write_ogg(path: str, samples: np.ndarray) -> None:
    peak = np.max(np.abs(samples)) or 1.0
    samples = np.clip(samples / peak * 0.85, -1, 1)
    pcm = (samples * 32767).astype(np.int16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    with wave.open(wav, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", path])
    os.unlink(wav)
    print("wrote", path, "%.2fs" % (len(samples) / SR))


def add(buf, start_s, snd):
    """Mix snd into buf at start_s; wraps around (seamless loops)."""
    i = int(start_s * SR) % len(buf)
    n = len(snd)
    end = i + n
    if end <= len(buf):
        buf[i:end] += snd
    else:
        k = len(buf) - i
        buf[i:] += snd[:k]
        rest = snd[k:]
        while len(rest):
            m = min(len(rest), len(buf))
            buf[:m] += rest[:m]
            rest = rest[m:]


def t_arr(dur):
    return np.arange(int(dur * SR)) / SR


def kick(dur=0.35):
    t = t_arr(dur)
    f = 50 + 90 * np.exp(-t * 30)
    ph = 2 * math.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * 0.9


def hat(dur=0.06, open_=False):
    t = t_arr(0.18 if open_ else dur)
    n = rng.standard_normal(len(t))
    n = np.diff(np.concatenate([[0], n]))  # crude high-pass
    return n * np.exp(-t * (18 if open_ else 60)) * 0.18


def clap(dur=0.2):
    t = t_arr(dur)
    n = rng.standard_normal(len(t))
    e = np.exp(-t * 25) + 0.5 * np.exp(-np.maximum(t - 0.012, 0) * 30) * (t > 0.012)
    return n * e * 0.25


def bass(freq, dur):
    t = t_arr(dur)
    saw = 2 * ((t * freq) % 1.0) - 1
    saw = np.convolve(saw, np.ones(6) / 6, mode="same")
    return saw * np.minimum(1, t * 80) * np.exp(-t * 3) * 0.35


def pluck(freq, dur, bright=0.5):
    t = t_arr(dur)
    out = np.zeros_like(t)
    for h, a in ((1, 1.0), (2, 0.5 * bright), (3, 0.3 * bright), (4, 0.15 * bright)):
        out += a * np.sin(2 * math.pi * freq * h * t) * np.exp(-t * (3 + h * 2.5))
    return out * np.minimum(1, t * 400) * 0.3


def santur(freq, dur=1.4):
    # Two slightly detuned strings, hammered.
    return pluck(freq, dur, 0.9) + pluck(freq * 1.003, dur, 0.7) * 0.8


def drone(freq, dur):
    t = t_arr(dur)
    out = 0.5 * np.sin(2 * math.pi * freq * t) + 0.25 * np.sin(2 * math.pi * freq * 1.5 * t) + 0.15 * np.sin(2 * math.pi * freq * 2 * t)
    lfo = 0.85 + 0.15 * np.sin(2 * math.pi * t / dur * 2)
    return out * lfo * 0.12


def tombak(kind="dom"):
    if kind == "dom":  # deep centre stroke
        t = t_arr(0.4)
        f = 95 + 40 * np.exp(-t * 25)
        ph = 2 * math.pi * np.cumsum(f) / SR
        return np.sin(ph) * np.exp(-t * 8) * 0.8
    if kind == "tak":  # sharp rim
        t = t_arr(0.12)
        n = rng.standard_normal(len(t))
        tone = np.sin(2 * math.pi * 620 * t)
        return (0.5 * n + tone) * np.exp(-t * 45) * 0.35
    t = t_arr(0.08)  # "ka" finger roll
    return rng.standard_normal(len(t)) * np.exp(-t * 70) * 0.18


def gym_loop():
    bpm = 120.0
    beat = 60.0 / bpm
    bars = 4
    buf = np.zeros(int(bars * 4 * beat * SR))
    roots = [55.0, 55.0, 43.65, 49.0]  # A, A, F, G
    arp = [0, 7, 12, 7, 3, 7, 12, 15]
    for b in range(bars):
        for q in range(4):
            s = (b * 4 + q) * beat
            add(buf, s, kick())
            if q % 2 == 1:
                add(buf, s, clap())
            for e in range(2):
                add(buf, s + e * beat / 2, hat(open_=(e == 1 and q == 3)))
            add(buf, s + beat / 2, bass(roots[b], beat / 2))
            add(buf, s, bass(roots[b], beat / 2) * 0.7)
        for k in range(8):
            f = roots[b] * 4 * 2 ** (arp[k] / 12)
            add(buf, b * 4 * beat + k * beat / 2, pluck(f, 0.3, 0.8) * 0.6)
    return buf


def radio_loop():
    # Dastgah-ish (shur flavour: neutral second approximated) gentle melody, 6/8 at 84 bpm.
    beat = 60.0 / 84.0 / 2
    steps = 48
    buf = np.zeros(int(steps * beat * SR))
    base = 293.66  # D
    scale = [0, 1.5, 3, 5, 7, 8, 10, 12]  # semitone steps, 1.5 = koron flavour
    melody = [0, 1, 2, 1, 0, -1, 0, 2, 3, 2, 1, 0, 4, 3, 2, 3, 1, 0, 2, 1, 0, 1, 2, 0]
    for i, m in enumerate(melody):
        st = scale[m] if m >= 0 else -2
        f = base * 2 ** (st / 12)
        s = i * 2 * beat
        add(buf, s, santur(f, 1.2))
        add(buf, s + beat, santur(f, 0.6) * 0.45)  # santur tremolo echo
    add(buf, 0, drone(base / 2, len(buf) / SR))
    for i in range(0, steps, 6):
        add(buf, i * beat, tombak("dom") * 0.35)
        add(buf, (i + 3) * beat, tombak("tak") * 0.3)
    return buf


def zarb_loop():
    beat = 60.0 / 100.0 / 2  # eighths at 100 bpm 6/8
    bars = 4
    buf = np.zeros(int(bars * 6 * beat * SR))
    pattern = ["dom", "ka", "tak", "dom", "tak", "ka"]
    for b in range(bars):
        for i, k in enumerate(pattern):
            s = (b * 6 + i) * beat
            add(buf, s, tombak(k))
            if k == "dom" and b % 2 == 1 and i == 3:
                add(buf, s + beat / 2, tombak("tak") * 0.7)
        # bell (zang) on the downbeat
        t = t_arr(1.2)
        add(buf, b * 6 * beat, (np.sin(2 * math.pi * 1240 * t) + 0.5 * np.sin(2 * math.pi * 1870 * t)) * np.exp(-t * 4) * 0.08)
    add(buf, 0, drone(110.0, len(buf) / SR) * 1.3)
    return buf


def campfire_loop():
    dur = 6.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Low roar: brown noise
    w = rng.standard_normal(n)
    roar = np.cumsum(w)
    roar -= np.convolve(roar, np.ones(400) / 400, mode="same")
    roar = roar / (np.max(np.abs(roar)) or 1) * 0.25
    buf = roar.copy()
    for _ in range(70):
        s = rng.uniform(0, dur)
        ln = rng.uniform(0.004, 0.02)
        tt = t_arr(ln)
        add(buf, s, rng.standard_normal(len(tt)) * np.exp(-tt * rng.uniform(150, 400)) * rng.uniform(0.3, 1.0))
    return buf


if __name__ == "__main__":
    write_ogg(os.path.join(ROOT, "assets/audio/music/gym_loop.ogg"), gym_loop())
    write_ogg(os.path.join(ROOT, "assets/audio/music/radio_loop.ogg"), radio_loop())
    write_ogg(os.path.join(ROOT, "assets/audio/music/zarb_loop.ogg"), zarb_loop())
    write_ogg(os.path.join(ROOT, "assets/audio/ambience/campfire_loop.ogg"), campfire_loop())
