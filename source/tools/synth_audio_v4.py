"""v4 tool / switch sounds, procedurally synthesized (CC0, original work).

Run:  python3 tools/synth_audio_v4.py   (needs numpy + scipy + ffmpeg)
Writes OGG files into assets/audio/sfx/.
"""
import os, subprocess, tempfile
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(404)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band", output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), output="sos"), x)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def write(name, x, quality=4):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(quality),
                        os.path.join(OUT, name)], check=True)
    os.unlink(tmp.name)


def seg(dur):
    return int(dur * SR)


# Hoe: a dull thud into soil + gravelly scrape.
n = seg(0.45)
thud = lp(rng.standard_normal(n), 300) * env(n, 0.004, 0.06) * 3.0
scrape = bp(rng.standard_normal(n), 900, 3500) * env(n, 0.02, 0.12) * (0.4 + 0.6 * rng.random(n) ** 3)
write("hoe_dig.ogg", thud + scrape * 0.6)

# Watering can: trickle (band-passed noise with bubbling amplitude).
n = seg(1.1)
t = np.arange(n) / SR
bubble = 0.6 + 0.4 * np.sin(2 * np.pi * 9 * t + 3 * np.sin(2 * np.pi * 2.3 * t))
water = bp(rng.standard_normal(n), 1500, 6000) * bubble
fade = np.minimum(1, t / 0.08) * np.minimum(1, (t[-1] - t) / 0.25)
write("water_pour.ogg", water * fade)

# Seeds: soft rustle / patter.
n = seg(0.5)
x = np.zeros(n)
for k in range(14):
    s = int(rng.integers(0, n - 800))
    m = 600
    x[s:s + m] += bp(rng.standard_normal(m), 2500, 8000) * env(m, 0.001, 0.01) * rng.uniform(0.3, 1)
write("seeds.ogg", x)

# Harvest: pluck (leafy rustle + low pop).
n = seg(0.4)
t = np.arange(n) / SR
pop = np.sin(2 * np.pi * (180 - 120 * t) * t) * env(n, 0.002, 0.05)
rustle = bp(rng.standard_normal(n), 1800, 7000) * env(n, 0.01, 0.1) * 0.5
write("harvest.ogg", pop + rustle)

# Breaker switch: two sharp clicks + a low clunk.
n = seg(0.3)
x = np.zeros(n)
for at, amp in ((0.0, 1.0), (0.035, 0.6)):
    s = int(at * SR)
    m = 400
    x[s:s + m] += bp(rng.standard_normal(m), 2000, 9000) * env(m, 0.0005, 0.004) * amp
m = seg(0.2)
t = np.arange(m) / SR
x[:m] += np.sin(2 * np.pi * 90 * t) * env(m, 0.002, 0.04) * 0.7
write("switch.ogg", x)

# Hammer (workshop crafting): two knocks on wood.
n = seg(0.7)
x = np.zeros(n)
for at in (0.0, 0.33):
    s = int(at * SR)
    m = seg(0.25)
    tt = np.arange(m) / SR
    x[s:s + m] += (np.sin(2 * np.pi * 420 * tt) * 0.6 + bp(rng.standard_normal(m), 600, 2500)) * env(m, 0.001, 0.035)
write("hammer.ogg", x)
print("v4 sfx written")
