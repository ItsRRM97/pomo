#!/usr/bin/env python3
"""Generate short royalty-free timer alert tones as WAV files."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "sounds"


def write_wave(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767))
            for sample in samples
        )
        wav_file.writeframes(frames)


def tone(freq: float, duration: float, volume: float = 0.35) -> list[float]:
    count = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(count):
        t = i / SAMPLE_RATE
        attack = min(1.0, i / (SAMPLE_RATE * 0.01))
        release = min(1.0, (count - i) / (SAMPLE_RATE * 0.08))
        envelope = attack * release
        samples.append(volume * envelope * math.sin(2 * math.pi * freq * t))
    return samples


def chime() -> list[float]:
    first = tone(880.0, 0.12, 0.28)
    gap = [0.0] * int(SAMPLE_RATE * 0.04)
    second = tone(1174.66, 0.28, 0.3)
    return first + gap + second


def bell() -> list[float]:
    samples: list[float] = []
    for partial, gain in ((523.25, 0.34), (1046.5, 0.18), (1569.75, 0.08)):
        partial_samples = tone(partial, 0.75, gain)
        if len(samples) < len(partial_samples):
            samples = [0.0] * len(partial_samples)
        samples = [a + b for a, b in zip(samples, partial_samples)]
    return samples


def digital_beep() -> list[float]:
  return tone(1000.0, 0.12, 0.32)


def main() -> None:
    write_wave(OUT_DIR / "chime.wav", chime())
    write_wave(OUT_DIR / "bell.wav", bell())
    write_wave(OUT_DIR / "digital_beep.wav", digital_beep())
    print(f"Wrote timer sounds to {OUT_DIR}")


if __name__ == "__main__":
    main()
