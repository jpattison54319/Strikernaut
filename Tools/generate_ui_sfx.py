#!/usr/bin/env python3
"""Generate Strikernaut UI sound effects as 16-bit mono WAVs (no dependencies)."""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "GoalRush", "Resources", "Audio")


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f"wrote {path} ({len(samples) / RATE:.2f}s)")


def tone(freq, duration, decay=8.0, attack=0.004, volume=0.8, detune=1.0):
    count = int(RATE * duration)
    out = []
    for i in range(count):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(volume * env * math.sin(2 * math.pi * freq * detune * t))
    return out


def sequence(notes):
    """notes: list of (delay_seconds, tone_samples) layered into one buffer."""
    total = max(int((delay + len(samples) / RATE) * RATE) for delay, samples in notes)
    mix = [0.0] * total
    for delay, samples in notes:
        offset = int(delay * RATE)
        for i, s in enumerate(samples):
            mix[offset + i] += s
    peak = max(1.0, max(abs(s) for s in mix))
    return [s / peak * 0.9 for s in mix]


def noise_burst(duration, decay=30.0, volume=0.5):
    state = 0x12345
    out = []
    count = int(RATE * duration)
    for i in range(count):
        state = (1103515245 * state + 12345) % (1 << 31)
        noise = (state / (1 << 31)) * 2 - 1
        out.append(volume * math.exp(-decay * i / RATE) * noise)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("ui-tap", tone(880, 0.09, decay=22.0, volume=0.55))
    write_wav("ui-whoosh", noise_burst(0.22, decay=14.0, volume=0.5))
    write_wav("ui-purchase", sequence([
        (0.0, tone(660, 0.14, decay=10.0)),
        (0.09, tone(990, 0.22, decay=9.0)),
    ]))
    write_wav("ui-claim", sequence([
        (0.0, tone(523, 0.12, decay=11.0)),
        (0.08, tone(659, 0.12, decay=11.0)),
        (0.16, tone(784, 0.24, decay=8.0)),
    ]))
    write_wav("ui-fanfare", sequence([
        (0.0, tone(523, 0.14, decay=9.0)),
        (0.11, tone(659, 0.14, decay=9.0)),
        (0.22, tone(784, 0.14, decay=9.0)),
        (0.33, tone(1047, 0.38, decay=6.0)),
    ]))
    write_wav("ui-draft", sequence([
        (0.0, tone(440, 0.16, decay=8.0, detune=1.0)),
        (0.05, tone(554, 0.18, decay=8.0)),
    ]))
    write_wav("ui-locked", tone(196, 0.16, decay=14.0, volume=0.6))
    write_wav("ui-combo", tone(1175, 0.07, decay=18.0, volume=0.5))


if __name__ == "__main__":
    main()
