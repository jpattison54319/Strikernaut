#!/usr/bin/env python3
"""Generate the short electrical crack-and-surge used by Volt Ball."""

import math
import os
import random
import struct
import wave

RATE = 44_100
DURATION = 0.42
OUTPUT = os.path.join(
    os.path.dirname(__file__),
    "..",
    "GoalRush",
    "Resources",
    "Audio",
    "volt-chain.wav",
)


def samples():
    random.seed(0xB017)
    values = []
    for index in range(int(RATE * DURATION)):
        time = index / RATE
        attack = min(1.0, time / 0.004)
        envelope = attack * math.exp(-6.2 * time)
        crackle = random.uniform(-1, 1) * (0.62 if index % 7 < 2 else 0.18)
        surge = math.sin(2 * math.pi * (1_480 - 920 * time) * time)
        hum = math.sin(2 * math.pi * 118 * time)
        branch = math.sin(2 * math.pi * 2_740 * time) * math.exp(-28 * max(0, time - 0.11))
        values.append((crackle * 0.45 + surge * 0.34 + hum * 0.18 + branch * 0.14) * envelope)
    peak = max(abs(value) for value in values)
    return [int(max(-1, min(1, value / peak * 0.88)) * 32_767) for value in values]


def main():
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with wave.open(OUTPUT, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b"".join(struct.pack("<h", value) for value in samples()))
    print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
