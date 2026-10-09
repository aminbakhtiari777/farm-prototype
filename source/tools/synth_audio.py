"""Procedurally synthesizes all prototype sounds (CC0, original work).

Run:  python3 tools/synth_audio.py   (needs numpy + scipy)
Outputs WAV files into assets/audio/ (then converted to OGG with ffmpeg, see CREDITS.md).
"""
import os
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band", output="sos")
    return sosfilt(sos, x)


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), output="sos"), x)


def highpass(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x)


def save(name, x, peak=0.89):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    path = os.path.join(ROOT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, SR, (x * 32767).astype(np.int16))
    print("wrote", path, round(len(x) / SR, 2), "s")


def formant_bank(src, formants):
    out = np.zeros_like(src)
    for f, bw, gain in formants:
        out += gain * bandpass(src, max(60, f - bw / 2), min(SR / 2 - 100, f + bw / 2), order=2)
    return out


def bleat(seed, f0=340.0, dur=0.85, quaver=27.0, bright=1.0):
    """Sheep 'baa': harmonic voice + strong amplitude/pitch quaver + vowel formants."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Pitch contour: quick rise, plateau, droop at the end; plus quaver and jitter.
    contour = 0.92 + 0.12 * np.clip(t / 0.08, 0, 1) - 0.14 * np.clip((t - dur * 0.55) / (dur * 0.45), 0, 1) ** 1.5
    jitter = np.cumsum(rng.normal(0, 0.002, n))
    jitter = lowpass(jitter - np.linspace(jitter[0], jitter[-1], n), 30)
    q_phase = 2 * np.pi * np.cumsum(quaver * (1 + 0.08 * np.sin(2 * np.pi * 1.3 * t))) / SR
    f = f0 * contour * (1 + 0.035 * np.sin(q_phase) + jitter)
    phase = 2 * np.pi * np.cumsum(f) / SR
    src = np.zeros(n)
    for k in range(1, 40):
        amp = (1.0 / k ** 1.15) * (f * k < 5500)
        src += amp * np.sin(k * phase + rng.uniform(0, 2 * np.pi))
    # Vowel: nasal 'm/b' onset morphing into 'ae' then 'eh'.
    nasal = formant_bank(src, [(280, 180, 1.0), (1100, 300, 0.15), (2400, 400, 0.05)])
    vowel = formant_bank(src, [(820, 260, 1.0), (1750, 380, 0.55 * bright), (2700, 500, 0.25 * bright), (3600, 700, 0.08)])
    vowel2 = formant_bank(src, [(620, 220, 1.0), (1900, 380, 0.6 * bright), (2600, 500, 0.25 * bright)])
    m1 = np.clip(t / 0.07, 0, 1)
    m2 = np.clip((t - dur * 0.5) / (dur * 0.4), 0, 1)
    voice = nasal * (1 - m1) * 0.6 + vowel * m1 * (1 - m2) + vowel2 * m2
    # Breathy noise follows the vowel.
    noise = bandpass(rng.normal(0, 1, n), 1800, 5200) * 0.05
    voice = voice + noise * m1
    # The characteristic bleat tremolo.
    trem = 1 - 0.55 * (0.5 + 0.5 * np.sin(q_phase + 0.6)) * np.clip((t - 0.06) / 0.1, 0, 1)
    env = np.clip(t / 0.035, 0, 1) * np.clip((dur - t) / 0.18, 0, 1) ** 1.4
    out = voice * trem * env
    return highpass(out, 120)


def footstep(seed):
    rng = np.random.default_rng(seed)
    dur = 0.16
    n = int(dur * SR)
    t = np.arange(n) / SR
    crunch = rng.normal(0, 1, n) * (rng.random(n) < 0.25)
    body = bandpass(rng.normal(0, 1, n), 250, 1400) * 0.6
    x = bandpass(crunch, 1500, 6000) * 0.5 + body
    env = np.clip(t / 0.006, 0, 1) * np.exp(-t / 0.045)
    thump = np.sin(2 * np.pi * 90 * t) * np.exp(-t / 0.03) * 0.5
    return x * env + thump


def ambience(seed, dur=24.0):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Wind: filtered noise with slow gusts.
    wind = lowpass(np.cumsum(rng.normal(0, 1, n)) * 0.02 + rng.normal(0, 1, n) * 0.5, 500, order=2)
    wind = highpass(wind, 60)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / dur * 2 + 0.5) * np.sin(2 * np.pi * t / dur * 3 + 1.2)
    out = wind / (np.max(np.abs(wind)) + 1e-9) * 0.22 * gust
    # Leaves rustle.
    rustle = bandpass(rng.normal(0, 1, n), 2500, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 5)) * 0.015
    out += rustle
    # Birds: short chirp phrases.
    time = 0.8
    while time < dur - 1.5:
        species = rng.integers(0, 3)
        base = rng.uniform(2600, 4200)
        notes = rng.integers(2, 6)
        nt = time
        for _ in range(notes):
            ln = rng.uniform(0.04, 0.11) if species != 2 else rng.uniform(0.12, 0.2)
            m = int(ln * SR)
            tt = np.arange(m) / SR
            if species == 0:     # quick downward chirps
                fr = base * (1.25 - 0.35 * tt / ln)
            elif species == 1:   # upward 'tweet'
                fr = base * (0.8 + 0.45 * (tt / ln) ** 0.7)
            else:                # warble
                fr = base * 0.8 * (1 + 0.08 * np.sin(2 * np.pi * 38 * tt))
            ph = 2 * np.pi * np.cumsum(fr) / SR
            note = (np.sin(ph) + 0.2 * np.sin(2 * ph)) * np.sin(np.pi * tt / ln) ** 2
            i0 = int(nt * SR)
            out[i0:i0 + m] += note[: max(0, min(m, n - i0))] * rng.uniform(0.05, 0.12)
            nt += ln + rng.uniform(0.03, 0.09)
        time = nt + rng.uniform(1.2, 3.5)
    # Seamless loop: crossfade the last second into the start.
    xf = int(1.0 * SR)
    fade = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * fade + out[-xf:] * (1 - fade)
    return out[:-xf]


if __name__ == "__main__":
    # bleat() is kept as an experiment; the game uses the real CC0 recording (see CREDITS.md).
    for i in range(4):
        save("sfx/footstep_grass_%d.wav" % (i + 1), footstep(10 + i), peak=0.7)
    save("ambience/meadow_day_loop.wav", ambience(99), peak=0.6)
