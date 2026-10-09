"""v3 sounds, procedurally synthesized (CC0, original work).

Run:  python3 tools/synth_audio_v3.py   (needs numpy + scipy + ffmpeg)
Writes OGG files into assets/audio/{ambience,sfx}/.
"""
import os, subprocess, tempfile
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band", output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x)


def smooth_noise(rng, n, rate_hz):
    """Slowly varying random curve in 0..1."""
    k = max(int(n / SR * rate_hz) + 3, 4)
    pts = rng.random(k)
    x = np.linspace(0, k - 3, n)
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    return pts[i] * (1 - f) + pts[i + 1] * f


def loopify(x, fade_s=1.5):
    """Crossfade the tail into the head so the clip loops seamlessly."""
    n = int(fade_s * SR)
    head, tail = x[:n].copy(), x[-n:]
    w = np.linspace(0, 1, n)
    out = x[n:].copy()
    out[-n:] = tail * (1 - w) + head * w
    return out


def save(name, x, peak=0.89, quality=3):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    path = os.path.join(ROOT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.unlink(tmp.name)
    print("wrote", name, round(len(x) / SR, 2), "s")


def wind(seed=11, dur=32.0):
    rng = np.random.default_rng(seed)
    n = int((dur + 1.5) * SR)
    noise = rng.normal(0, 1, n)
    gust = smooth_noise(rng, n, 0.25) ** 2
    body = bp(noise, 120, 700) * (0.25 + 1.3 * gust)
    whistle_f = 380 + 260 * smooth_noise(rng, n, 0.4)
    whistle = bp(noise, 300, 1400) * gust ** 2 * 0.5
    # A slow moving resonance gives the 'howl' in strong gusts.
    phase = 2 * np.pi * np.cumsum(whistle_f) / SR
    howl = np.sin(phase) * bp(noise, 200, 900) * gust ** 3 * 0.25
    leaves = hp(noise, 2500) * (smooth_noise(rng, n, 1.5) ** 3) * gust * 0.35
    return loopify(lp(body + whistle + howl, 1800) + leaves)


def chirp(rng, f0, f1, dur, harm=0.25):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.geomspace(f0, f1, n) * (1 + 0.06 * np.sin(2 * np.pi * rng.uniform(20, 45) * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return (np.sin(ph) + harm * np.sin(2 * ph)) * env


def birds(seed=21, dur=30.0):
    rng = np.random.default_rng(seed)
    n = int((dur + 1.5) * SR)
    out = np.zeros(n)
    t = 0.3
    while t < dur:
        species = rng.integers(0, 3)
        if species == 0:  # quick descending twitters
            for k in range(rng.integers(3, 7)):
                c = chirp(rng, rng.uniform(3800, 5200), rng.uniform(2400, 3400), rng.uniform(0.05, 0.09))
                i = int((t + k * 0.11) * SR)
                out[i:i + len(c)] += c[: max(0, n - i)] * 0.5
        elif species == 1:  # two-note whistle
            for k, (a, b) in enumerate([(2600, 2700), (2100, 2050)]):
                c = chirp(rng, a, b, 0.22, 0.1)
                i = int((t + k * 0.3) * SR)
                out[i:i + len(c)] += c[: max(0, n - i)] * 0.35
        else:  # warble
            c = chirp(rng, rng.uniform(2800, 3300), rng.uniform(3600, 4200), rng.uniform(0.3, 0.5), 0.3)
            i = int(t * SR)
            out[i:i + len(c)] += c[: max(0, n - i)] * 0.3
        t += rng.uniform(0.8, 3.2)
    noise = rng.normal(0, 1, n)
    bed = lp(bp(noise, 150, 900), 900) * 0.02
    return loopify(out + bed)


def crickets(seed=31, dur=20.0):
    rng = np.random.default_rng(seed)
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for c in range(5):
        f = rng.uniform(3900, 4700)
        rate = rng.uniform(14, 22)  # pulses per second inside a chirp
        chirp_rate = rng.uniform(1.2, 2.4)
        carrier = np.sin(2 * np.pi * f * t + rng.uniform(0, 6))
        pulses = (np.sin(2 * np.pi * rate * t) > 0.2).astype(float)
        groups = (np.sin(2 * np.pi * chirp_rate * t + rng.uniform(0, 6)) > 0.35).astype(float)
        env = lp(pulses * groups, 300)
        out += carrier * env * rng.uniform(0.3, 1.0) * (0.6 + 0.4 * smooth_noise(rng, n, 0.2))
    noise = rng.normal(0, 1, n)
    out += lp(noise, 400) * 0.03  # faint night air
    return loopify(out)


def waves(seed=41, dur=18.0):
    rng = np.random.default_rng(seed)
    n = int((dur + 2.0) * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    period = dur / 3.0  # three breakers per loop
    for k in range(4):
        start = k * period + rng.uniform(-0.4, 0.4)
        x = (t - start) / period
        swell = np.clip(x, 0, 1) ** 2 * (x < 1)
        crash = np.exp(-np.clip(t - start - period * 0.95, 0, None) * 1.6) * (t > start + period * 0.95)
        out += bp(noise, 150, 1200) * swell * 0.4 + bp(noise, 300, 5000) * crash * 1.0
        # Hiss of the wash running back over sand.
        wash = np.exp(-np.clip(t - start - period * 1.3, 0, None) * 0.9) * (t > start + period * 1.3)
        out += hp(noise, 2500) * wash * 0.35
    out += lp(noise, 250) * 0.15
    return loopify(out, 2.0)


def pond(seed=51, dur=12.0):
    rng = np.random.default_rng(seed)
    n = int((dur + 1.5) * SR)
    noise = rng.normal(0, 1, n)
    out = bp(noise, 200, 1200) * smooth_noise(rng, n, 1.0) * 0.25
    t = 0.5
    while t < dur:
        i = int(t * SR)
        m = int(0.06 * SR)
        tt = np.arange(m) / SR
        f = rng.uniform(500, 900) * (1 + tt * 6)
        blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 60)
        out[i:i + m] += blip * 0.6
        t += rng.uniform(0.3, 1.4)
    return loopify(out)


def door_creak(seed=61):
    rng = np.random.default_rng(seed)
    dur = 0.75
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 180 + 120 * np.sin(np.pi * t / dur) + 30 * np.sin(2 * np.pi * 9 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    stick = (rng.random(n) < 0.02).astype(float)
    src = np.sign(np.sin(ph)) * 0.4 + lp(stick, 2000) * 2
    body = bp(src, 300, 2500) * np.sin(np.pi * t / dur) ** 0.6
    thud_n = int(0.12 * SR)
    thud = lp(rng.normal(0, 1, thud_n), 300) * np.exp(-np.arange(thud_n) / SR * 40)
    out = np.concatenate([body, thud * 2.0])
    return out


def splash(seed=71):
    rng = np.random.default_rng(seed)
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0, 1, n)
    out = bp(noise, 400, 4000) * np.exp(-t * 9) + lp(noise, 500) * np.exp(-t * 14) * 0.8
    for k in range(6):
        i = int(rng.uniform(0.05, 0.4) * SR)
        m = int(0.03 * SR)
        tt = np.arange(m) / SR
        out[i:i + m] += np.sin(2 * np.pi * rng.uniform(900, 1600) * tt * (1 + tt * 20)) * np.exp(-tt * 90) * 0.4
    return out


def plop(seed=72):
    rng = np.random.default_rng(seed)
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 380 * (1 + t * 8)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 25) + bp(rng.normal(0, 1, n), 500, 3000) * np.exp(-t * 30) * 0.3


def reel(seed=73):
    rng = np.random.default_rng(seed)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    clicks = (np.sin(2 * np.pi * 26 * t) > 0.92).astype(float)
    out = bp(lp(clicks, 6000) + rng.normal(0, 0.05, n), 1500, 6000)
    return out * np.minimum(1, (0.9 - t) * 6)


def pickup(seed=74):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    f = np.where(t < 0.07, 880, 1320)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-((t % 0.07) * 30)) * 0.6


def breathing(seed=81, dur=2.6):
    """Heavy, tired breathing (two breaths), loopable."""
    rng = np.random.default_rng(seed)
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    for k in range(2):
        s = k * dur / 2
        inhale = np.clip((t - s) / 0.45, 0, 1) * (t < s + 0.5) * np.clip((s + 0.5 - t) / 0.1, 0, 1)
        exhale = np.clip((t - s - 0.55) / 0.08, 0, 1) * np.clip((s + 1.2 - t) / 0.5, 0, 1) * (t > s + 0.55)
        out += bp(noise, 600, 2400) * inhale * 0.6 + bp(noise, 300, 1600) * exhale
    return loopify(out, 0.4)


def jump_land(seed=91):
    rng = np.random.default_rng(seed)
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    return lp(rng.normal(0, 1, n), 600) * np.exp(-t * 28) + bp(rng.normal(0, 1, n), 800, 3000) * np.exp(-t * 45) * 0.3


if __name__ == "__main__":
    save("ambience/wind_gusts_loop.ogg", wind(), 0.8)
    save("ambience/birds_day_loop.ogg", birds(), 0.75)
    save("ambience/crickets_night_loop.ogg", crickets(), 0.6)
    save("ambience/waves_loop.ogg", waves(), 0.9)
    save("ambience/pond_loop.ogg", pond(), 0.6)
    save("sfx/door_creak.ogg", door_creak(), 0.7)
    save("sfx/splash.ogg", splash(), 0.8)
    save("sfx/plop.ogg", plop(), 0.7)
    save("sfx/reel.ogg", reel(), 0.6)
    save("sfx/pickup.ogg", pickup(), 0.5)
    save("sfx/breathing_heavy_loop.ogg", breathing(), 0.6)
    save("sfx/land.ogg", jump_land(), 0.7)
