#!/usr/bin/env python3
"""Render the original 15-second Strikernaut V2 drum-and-bass trailer cue."""

from __future__ import annotations

import argparse
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 48_000
DURATION = 15.0
BPM = 174.0
BEAT = 60.0 / BPM


def timebase(duration: float) -> np.ndarray:
    return np.arange(max(1, round(duration * SAMPLE_RATE))) / SAMPLE_RATE


def add(buffer: np.ndarray, sound: np.ndarray, start: float, pan: float = 0.0) -> None:
    frame = max(0, round(start * SAMPLE_RATE))
    available = min(len(sound), len(buffer) - frame)
    if available <= 0:
        return
    angle = (pan + 1.0) * np.pi / 4
    buffer[frame : frame + available, 0] += sound[:available] * np.cos(angle)
    buffer[frame : frame + available, 1] += sound[:available] * np.sin(angle)


def kick(accent: float = 1.0) -> np.ndarray:
    t = timebase(0.34)
    frequency = 46 + 118 * np.exp(-t * 24)
    phase = 2 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
    body = np.sin(phase) * np.exp(-t * 13)
    click = np.random.default_rng(11).standard_normal(len(t)) * np.exp(-t * 105)
    return accent * (0.94 * body + 0.14 * click)


def snare(accent: float = 1.0) -> np.ndarray:
    t = timebase(0.28)
    rng = np.random.default_rng(round(accent * 10_000) + 29)
    noise = rng.standard_normal(len(t))
    bright = np.concatenate(([noise[0]], np.diff(noise)))
    body = np.sin(2 * np.pi * 188 * t) * np.exp(-t * 17)
    return accent * (0.50 * bright * np.exp(-t * 18) + 0.50 * body)


def hat(open_hat: bool = False) -> np.ndarray:
    duration = 0.17 if open_hat else 0.055
    t = timebase(duration)
    rng = np.random.default_rng(round(duration * 100_000) + 71)
    noise = rng.standard_normal(len(t))
    bright = np.concatenate(([noise[0]], np.diff(noise)))
    decay = 22 if open_hat else 68
    return 0.19 * bright * np.exp(-t * decay)


def impact() -> np.ndarray:
    t = timebase(0.72)
    rng = np.random.default_rng(99)
    sub = np.sin(2 * np.pi * (72 - 38 * t) * t) * np.exp(-t * 5.5)
    noise = rng.standard_normal(len(t)) * np.exp(-t * 12)
    return 0.82 * sub + 0.19 * noise


def riser(duration: float) -> np.ndarray:
    t = timebase(duration)
    rng = np.random.default_rng(round(duration * 1_000) + 121)
    noise = rng.standard_normal(len(t))
    shimmer = np.sin(2 * np.pi * (260 * t + 2_100 * t * t / max(duration, 0.01)))
    envelope = np.clip(t / max(duration, 0.01), 0, 1) ** 2.2
    return (0.17 * noise + 0.14 * shimmer) * envelope


def reese(note_hz: float, duration: float, accent: float = 1.0) -> np.ndarray:
    t = timebase(duration)
    phase_a = np.mod(t * note_hz * 0.992, 1)
    phase_b = np.mod(t * note_hz * 1.008, 1)
    saw = (2 * phase_a - 1) + (2 * phase_b - 1)
    sub = np.sin(2 * np.pi * note_hz * t)
    wobble = 0.66 + 0.34 * np.sin(2 * np.pi * (BPM / 60) * 2 * t) ** 2
    attack = np.clip(t / 0.018, 0, 1)
    release = np.clip((duration - t) / 0.08, 0, 1)
    return accent * (0.30 * saw + 0.72 * sub) * wobble * attack * release


def synth_stab(root: float, duration: float = 0.24) -> np.ndarray:
    t = timebase(duration)
    notes = (root, root * 1.2, root * 1.5, root * 2.0)
    signal = sum(
        np.sin(2 * np.pi * frequency * t + index * 0.7)
        for index, frequency in enumerate(notes)
    ) / len(notes)
    grit = np.sign(signal) * np.sqrt(np.abs(signal))
    envelope = np.exp(-t * 11) * np.clip(t / 0.006, 0, 1)
    return 0.46 * grit * envelope


def render() -> np.ndarray:
    music = np.zeros((round(DURATION * SAMPLE_RATE), 2), dtype=np.float64)

    # Full-energy DnB drums from frame one: syncopated kicks, backbeat snares,
    # and alternating hats with a harder second-half subdivision.
    total_beats = int(np.ceil(DURATION / BEAT))
    for beat_index in range(total_beats):
        beat_time = beat_index * BEAT
        if beat_index % 4 in {0, 2}:
            add(music, kick(1.08 if beat_index % 8 == 0 else 0.92), beat_time)
        if beat_index % 4 in {1, 3}:
            add(music, snare(0.92), beat_time)
        if beat_index % 4 == 2:
            add(music, kick(0.66), beat_time + BEAT * 0.70)
        if beat_index % 8 == 7:
            add(music, kick(0.58), beat_time + BEAT * 0.47)

        subdivisions = 4 if beat_time < 9.7 else 8
        for subdivision in range(subdivisions):
            hat_time = beat_time + subdivision * BEAT / subdivisions
            pan = -0.52 if (beat_index + subdivision) % 2 == 0 else 0.52
            add(
                music,
                hat(open_hat=subdivision == subdivisions - 1 and beat_index % 2 == 1),
                hat_time,
                pan,
            )

    # Reese bass moves through a terse D-minor progression and ducks on every
    # beat so the kick remains dominant on phone speakers.
    bass_notes = [36.71, 36.71, 43.65, 32.70, 36.71, 49.00, 43.65, 32.70]
    phrase = BEAT * 2
    for index, start in enumerate(np.arange(0, DURATION, phrase)):
        note = bass_notes[index % len(bass_notes)]
        add(music, reese(note, phrase * 0.94, 0.88), float(start), -0.05)

    # Typography and gameplay-impact sync points.
    hit_times = [0.0, 2.30, 4.40, 6.40, 10.00, 12.50]
    roots = [146.83, 174.61, 196.00, 146.83, 220.00, 293.66]
    for index, hit_time in enumerate(hit_times):
        add(music, impact(), hit_time)
        add(music, synth_stab(roots[index]), hit_time, -0.18 if index % 2 == 0 else 0.18)
        if hit_time > 0.45:
            add(music, riser(0.42), hit_time - 0.42, 0.35 if index % 2 == 0 else -0.35)

    # Final brand lift and controlled stop so the CTA lands cleanly.
    for offset, root in ((12.50, 146.83), (12.84, 174.61), (13.19, 220.00)):
        add(music, synth_stab(root, 0.34), offset)
    fade_start = round(14.45 * SAMPLE_RATE)
    music[fade_start:] *= np.linspace(1.0, 0.0, len(music) - fade_start)[:, None]

    # Saturated but controlled trailer master.
    music = np.tanh(music * 1.28)
    peak = float(np.max(np.abs(music)))
    if peak > 0:
        music *= 0.94 / peak
    return music


def write_wave(path: Path, music: np.ndarray) -> None:
    pcm = np.clip(music, -1, 1)
    pcm = (pcm * 32_767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    np.random.seed(7)
    write_wave(args.output, render())
    print(args.output)


if __name__ == "__main__":
    main()
