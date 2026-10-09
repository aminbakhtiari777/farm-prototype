"""v7b.1 audio workstream: tiny original sound effects (CC0, synthesized here).
Run: /tmp/pwvenv/bin/python tools/synth_audio_v7b1.py
Mono, low sample rate, Vorbis q0-1 -> every file is a few KB (loops are seamless:
FFT-shaped noise is periodic, and event tails wrap around).
  assets/audio/v7b1/step_asphalt_1..3.ogg  hard heel click + scuff (roads, plaza, sidewalks)
  assets/audio/v7b1/step_wood_1..3.ogg     hollow board knock (floors indoors, pier, porches)
  assets/audio/v7b1/step_sand_1..3.ogg     soft grainy crunch (beach)
  assets/audio/v7b1/door_latch.ogg         latch click + handle (door opens)
  assets/audio/v7b1/door_close.ogg         wooden thud + latch (door closes)
  assets/audio/v7b1/murmur_loop.ogg        town-square crowd murmur (no words)
  assets/audio/v7b1/traffic_loop.ogg       distant road rumble with passing swells
  assets/audio/v7b1/gust_1..2.ogg          wind gust swells (sky / clouds)
  assets/audio/v7b1/thunder_1..2.ogg       distant thunder rumble (rain / storm only)
"""
from __future__ import annotations
import os, wave, subprocess, tempfile
import numpy as np
from scipy.signal import butter, sosfilt
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "v7b1")
rng = np.random.default_rng(7101)


def write_ogg(name, x, sr, q=0, gain=0.85):
    peak = np.max(np.abs(x)) or 1.0
    x = np.clip(x / peak * gain, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    with wave.open(wav, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    path = os.path.join(OUT, name)
    subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-c:a", "libvorbis", "-q:a", str(q), path])
    os.unlink(wav)
    print("wrote %-22s %.2fs %5d B" % (name, len(x) / sr, os.path.getsize(path)))


def t_arr(dur, sr):
    return np.arange(int(dur * sr)) / sr


def bp(x, lo, hi, sr, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=sr, output="sos"), x)


def lp(x, f, sr, order=2):
    return sosfilt(butter(order, f, btype="low", fs=sr, output="sos"), x)


def hp(x, f, sr, order=2):
    return sosfilt(butter(order, f, btype="high", fs=sr, output="sos"), x)


def shaped_noise(n, sr, shape):
    """Periodic noise with |spectrum| = shape(freqs): loops seamlessly."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / sr)
    return np.fft.irfft(spec * shape(f), n)


def wrap_add(buf, i, snd):
    i %= len(buf)
    k = min(len(snd), len(buf) - i)
    buf[i:i + k] += snd[:k]
    if k < len(snd):
        buf[:len(snd) - k] += snd[k:]


# ------------------------------------------------------------------ footsteps
SR_STEP = 22050


def step_asphalt(seed):
    r = np.random.default_rng(seed)
    t = t_arr(0.2, SR_STEP)
    heel = hp(r.standard_normal(len(t)), 1800 + seed % 5 * 150, SR_STEP) * np.exp(-t * 160)
    thump = np.sin(2 * np.pi * (85 + seed % 3 * 12) * t) * np.exp(-t * 55) * 0.6
    scuff = bp(r.standard_normal(len(t)), 900, 4000, SR_STEP) * np.exp(-((t - 0.06) / 0.025) ** 2) * 0.25
    toe = np.zeros_like(t)
    o = int(0.045 * SR_STEP)
    toe[o:] = hp(r.standard_normal(len(t) - o), 2400, SR_STEP) * np.exp(-t[:len(t) - o] * 220) * 0.45
    return heel + thump + scuff + toe


def step_wood(seed):
    r = np.random.default_rng(seed)
    t = t_arr(0.26, SR_STEP)
    f0 = 150 + seed % 4 * 18
    body = (np.sin(2 * np.pi * f0 * t) + 0.55 * np.sin(2 * np.pi * f0 * 1.63 * t) + 0.3 * np.sin(2 * np.pi * f0 * 2.7 * t)) * np.exp(-t * 28)
    knock = lp(r.standard_normal(len(t)), 2200, SR_STEP) * np.exp(-t * 90) * 0.8
    creak = np.sin(2 * np.pi * (520 + 60 * np.sin(t * 30)) * t) * np.exp(-((t - 0.12) / 0.04) ** 2) * 0.06 * (seed % 2)
    return body * 0.7 + knock + creak


def step_sand(seed):
    r = np.random.default_rng(seed)
    t = t_arr(0.28, SR_STEP)
    env = (1 - np.exp(-t * 60)) * np.exp(-t * 14)
    grains = (r.random(len(t)) < 0.08) * r.standard_normal(len(t))
    crunch = bp(grains, 700, 5000, SR_STEP) * 2.0 + lp(r.standard_normal(len(t)), 900, SR_STEP) * 0.6
    return crunch * env


# ------------------------------------------------------------------ doors
def door_latch():
    sr = SR_STEP
    t = t_arr(0.32, sr)
    x = np.zeros_like(t)
    for at, f, a in ((0.0, 2300, 1.0), (0.11, 1700, 0.7)):
        o = int(at * sr)
        tt = t[:len(t) - o]
        click = hp(rng.standard_normal(len(tt)), 2500, sr) * np.exp(-tt * 260) + np.sin(2 * np.pi * f * tt) * np.exp(-tt * 70) * 0.5
        x[o:] += click * a
    return x


def door_close():
    sr = SR_STEP
    t = t_arr(0.5, sr)
    thud = (np.sin(2 * np.pi * 68 * t) + 0.6 * np.sin(2 * np.pi * 112 * t) + 0.25 * np.sin(2 * np.pi * 190 * t)) * np.exp(-t * 16)
    hit = lp(rng.standard_normal(len(t)), 1500, sr) * np.exp(-t * 60) * 0.9
    x = thud + hit
    o = int(0.055 * sr)
    tt = t[:len(t) - o]
    x[o:] += (hp(rng.standard_normal(len(tt)), 2600, sr) * np.exp(-tt * 240) + np.sin(2 * np.pi * 2000 * tt) * np.exp(-tt * 80) * 0.4) * 0.5
    return x


# ------------------------------------------------------------------ loops
def murmur_loop():
    sr = 16000
    n = sr * 6
    t = np.arange(n) / sr
    out = shaped_noise(n, sr, lambda f: np.exp(-((f - 450) / 350) ** 2) * 0.5 + 0.05 * (f < 2500))
    out *= 0.25
    # ~7 overlapping "voices": formant-filtered noise with syllable envelopes.
    for v in range(7):
        pitch_lo = 300 + v * 60
        voice = np.zeros(n)
        pos = rng.integers(0, n)
        k = 0
        while k < n:
            dur = rng.uniform(0.09, 0.22)
            m = int(dur * sr)
            tt = np.arange(m) / sr
            f1 = rng.uniform(pitch_lo, pitch_lo + 500)
            f2 = rng.uniform(1100, 2300)
            src = rng.standard_normal(m)
            syl = bp(src, f1 * 0.85, f1 * 1.15, sr) + 0.5 * bp(src, f2 * 0.9, f2 * 1.1, sr)
            syl *= np.sin(np.pi * tt / dur) ** 2
            if rng.random() < 0.18:
                syl *= 0.0  # pauses between phrases
            wrap_add(voice, pos + k, syl)
            k += int(m * rng.uniform(0.7, 1.0))
        out += voice * rng.uniform(0.35, 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * (1 / 6) * (v + 1) * t + v))
    return lp(out, 2600, sr, 2) + 0.0, sr


def traffic_loop():
    sr = 11025
    n = sr * 8
    t = np.arange(n) / sr
    rumble = shaped_noise(n, sr, lambda f: 1.0 / np.maximum(f, 25.0) * (f < 450))
    rumble /= np.max(np.abs(rumble))
    hiss = shaped_noise(n, sr, lambda f: np.exp(-((f - 1100) / 500) ** 2))
    hiss /= np.max(np.abs(hiss))
    swell = np.full(n, 0.35)
    for _ in range(5):  # cars passing in the distance (periodic gaussians -> seamless)
        c = rng.uniform(0, 8)
        w = rng.uniform(0.7, 1.6)
        d = np.minimum(np.abs(t - c), 8 - np.abs(t - c))
        swell += rng.uniform(0.4, 0.9) * np.exp(-(d / w) ** 2)
    return rumble * swell + hiss * swell * 0.18, sr


def gust(seed):
    sr = 16000
    r = np.random.default_rng(seed)
    dur = 3.6
    t = t_arr(dur, sr)
    env = np.sin(np.pi * t / dur) ** 1.6 * (1 + 0.25 * np.sin(2 * np.pi * r.uniform(0.6, 1.2) * t))
    src = r.standard_normal(len(t))
    lo = bp(src, 180, 700, sr)
    hi = bp(src, 700, 2600, sr)
    bright = np.sin(np.pi * t / dur) ** 3
    whistle = np.sin(2 * np.pi * np.cumsum(620 + 140 * bright) / sr) * bright * 0.04 * (seed % 2)
    return (lo + hi * bright * 0.6) * env + whistle


def thunder(seed):
    sr = 11025
    r = np.random.default_rng(seed)
    dur = 5.5
    t = t_arr(dur, sr)
    brown = np.cumsum(r.standard_normal(len(t)))
    brown = hp(brown, 20, sr)
    rumble = lp(brown, 160, sr, 3)
    rumble /= np.max(np.abs(rumble)) or 1
    crack = lp(r.standard_normal(len(t)), 900, sr) * np.exp(-((t - 0.15) / 0.12) ** 2) * 0.5
    rolls = np.zeros_like(t)
    for _ in range(6):
        c = r.uniform(0.2, 3.8)
        rolls += r.uniform(0.4, 1.0) * np.exp(-((t - c) / r.uniform(0.25, 0.7)) ** 2)
    env = (1 - np.exp(-t * 8)) * np.exp(-t * 0.55) * (0.5 + rolls)
    return rumble * env + crack


if __name__ == "__main__":
    for i in (1, 2, 3):
        write_ogg("step_asphalt_%d.ogg" % i, step_asphalt(100 + i), SR_STEP)
        write_ogg("step_wood_%d.ogg" % i, step_wood(200 + i), SR_STEP)
        write_ogg("step_sand_%d.ogg" % i, step_sand(300 + i), SR_STEP)
    write_ogg("door_latch.ogg", door_latch(), SR_STEP)
    write_ogg("door_close.ogg", door_close(), SR_STEP)
    m, sr = murmur_loop(); write_ogg("murmur_loop.ogg", m, sr, q=0)
    tr, sr = traffic_loop(); write_ogg("traffic_loop.ogg", tr, sr, q=0)
    for i in (1, 2):
        write_ogg("gust_%d.ogg" % i, gust(400 + i), 16000)
        write_ogg("thunder_%d.ogg" % i, thunder(500 + i), 11025)
    tot = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".ogg"))
    print("total %.1f KB" % (tot / 1024))
