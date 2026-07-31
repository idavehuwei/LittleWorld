#!/usr/bin/env python3
"""Generate deterministic 16x16 block textures and short mono WAV effects."""

from __future__ import annotations

import math
import random
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = ROOT / "assets" / "textures" / "blocks"
AUDIO_DIR = ROOT / "assets" / "audio" / "sfx"
AMBIENT_DIR = ROOT / "assets" / "audio" / "ambient"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
SIZE = 16
SAMPLE_RATE = 22050


def clamp_byte(value: float) -> int:
    return max(0, min(255, round(value)))


def shade(color: tuple[int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (
        clamp_byte(color[0] * factor),
        clamp_byte(color[1] * factor),
        clamp_byte(color[2] * factor),
        255,
    )


def write_png(path: Path, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    raw = b"".join(
        b"\x00" + bytes(channel for pixel in row for channel in pixel)
        for row in pixels
    )
    payload = b"\x89PNG\r\n\x1a\n"
    payload += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    payload += chunk(b"IDAT", zlib.compress(raw, 9))
    payload += chunk(b"IEND", b"")
    path.write_bytes(payload)


def noisy_texture(base: tuple[int, int, int], seed: int, spread: float) -> list[list[tuple[int, int, int, int]]]:
    rng = random.Random(seed)
    return [
        [shade(base, 1.0 + rng.uniform(-spread, spread)) for _x in range(SIZE)]
        for _y in range(SIZE)
    ]


def grass_texture() -> list[list[tuple[int, int, int, int]]]:
    pixels = noisy_texture((91, 159, 57), 101, 0.16)
    rng = random.Random(102)
    for _ in range(28):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        pixels[y][x] = shade((55, 122, 42), rng.uniform(0.82, 1.08))
    for _ in range(18):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        pixels[y][x] = shade((133, 190, 72), rng.uniform(0.92, 1.08))
    return pixels


def dirt_texture() -> list[list[tuple[int, int, int, int]]]:
    pixels = noisy_texture((126, 78, 43), 201, 0.17)
    rng = random.Random(202)
    for _ in range(30):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        color = (88, 54, 34) if rng.random() < 0.6 else (163, 107, 60)
        pixels[y][x] = shade(color, rng.uniform(0.9, 1.08))
    return pixels


def stone_texture() -> list[list[tuple[int, int, int, int]]]:
    pixels = noisy_texture((132, 139, 144), 301, 0.12)
    rng = random.Random(302)
    for _ in range(24):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        color = (91, 98, 104) if rng.random() < 0.55 else (174, 180, 183)
        pixels[y][x] = shade(color, rng.uniform(0.92, 1.06))
    for x, y in [(2, 4), (3, 4), (11, 3), (12, 4), (7, 10), (8, 10), (8, 11), (13, 13)]:
        pixels[y][x] = (75, 82, 88, 255)
    return pixels


def planks_texture() -> list[list[tuple[int, int, int, int]]]:
    rng = random.Random(401)
    pixels: list[list[tuple[int, int, int, int]]] = []
    for y in range(SIZE):
        row = []
        seam = y in (0, 5, 10, 15)
        for x in range(SIZE):
            if seam:
                row.append((91, 54, 28, 255))
            else:
                wave_factor = 1.0 + 0.08 * math.sin((x + y * 0.7) * 0.9)
                row.append(shade((188, 124, 62), wave_factor + rng.uniform(-0.05, 0.05)))
        pixels.append(row)
    for y in (2, 7, 12):
        knot_x = (y * 3) % 13 + 1
        pixels[y][knot_x] = (91, 55, 27, 255)
        pixels[y][min(SIZE - 1, knot_x + 1)] = (133, 78, 35, 255)
    return pixels


def bricks_texture() -> list[list[tuple[int, int, int, int]]]:
    mortar = (198, 177, 151, 255)
    rng = random.Random(501)
    pixels: list[list[tuple[int, int, int, int]]] = []
    for y in range(SIZE):
        row = []
        row_index = y // 5
        offset = 4 if row_index % 2 else 0
        for x in range(SIZE):
            horizontal_mortar = y in (0, 5, 10, 15)
            vertical_mortar = (x + offset) % 8 == 0
            if horizontal_mortar or vertical_mortar:
                row.append(mortar)
            else:
                row.append(shade((165, 67, 48), 1.0 + rng.uniform(-0.12, 0.12)))
        pixels.append(row)
    return pixels


def log_texture() -> list[list[tuple[int, int, int, int]]]:
    rng = random.Random(801)
    pixels: list[list[tuple[int, int, int, int]]] = []
    center = (SIZE - 1) * 0.5
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            distance = max(abs(x - center), abs(y - center))
            ring = int(distance) % 3 == 0
            base = (139, 88, 43) if ring else (177, 119, 61)
            row.append(shade(base, 1.0 + rng.uniform(-0.07, 0.07)))
        pixels.append(row)
    for x in range(SIZE):
        pixels[0][x] = (91, 55, 29, 255)
        pixels[SIZE - 1][x] = (91, 55, 29, 255)
    for y in range(SIZE):
        pixels[y][0] = (91, 55, 29, 255)
        pixels[y][SIZE - 1] = (91, 55, 29, 255)
    return pixels


def crafting_table_texture() -> list[list[tuple[int, int, int, int]]]:
    pixels = planks_texture()
    dark = (79, 48, 27, 255)
    light = (221, 167, 91, 255)
    for y in (1, 6, 11, 14):
        for x in range(1, 15):
            pixels[y][x] = dark
    for x in (1, 6, 11, 14):
        for y in range(1, 15):
            pixels[y][x] = dark
    for x, y in [(3, 3), (8, 3), (13, 3), (3, 8), (8, 8), (13, 8), (3, 13), (8, 13), (13, 13)]:
        pixels[y][x] = light
    return pixels


def leaves_texture() -> list[list[tuple[int, int, int, int]]]:
    pixels = noisy_texture((62, 137, 55), 901, 0.19)
    rng = random.Random(902)
    for _ in range(42):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        color = (37, 101, 42) if rng.random() < 0.55 else (101, 170, 68)
        pixels[y][x] = shade(color, rng.uniform(0.88, 1.08))
    return pixels


def flower_texture() -> list[list[tuple[int, int, int, int]]]:
    transparent = (0, 0, 0, 0)
    pixels = [[transparent for _x in range(SIZE)] for _y in range(SIZE)]
    stem = (48, 128, 47, 255)
    leaf = (68, 151, 54, 255)
    petal = (250, 224, 73, 255)
    petal_light = (255, 247, 157, 255)
    center = (154, 83, 34, 255)
    for y in range(7, 16):
        pixels[y][7] = stem
        pixels[y][8] = stem
    for x, y in [(5, 11), (6, 11), (9, 12), (10, 12), (6, 12), (9, 13)]:
        pixels[y][x] = leaf
    for x, y in [(7, 3), (8, 3), (5, 5), (6, 4), (9, 4), (10, 5), (6, 7), (9, 7), (7, 8), (8, 8)]:
        pixels[y][x] = petal
    for x, y in [(7, 4), (8, 4), (6, 5), (9, 5), (7, 7), (8, 7)]:
        pixels[y][x] = petal_light
    for x, y in [(7, 5), (8, 5), (7, 6), (8, 6)]:
        pixels[y][x] = center
    return pixels


def write_wav(path: Path, samples: list[float]) -> None:
    pcm = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample))
        pcm += struct.pack("<h", round(value * 32767))
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm)


def break_sound() -> list[float]:
    rng = random.Random(601)
    duration = 0.30
    count = round(SAMPLE_RATE * duration)
    filtered_noise = 0.0
    samples: list[float] = []
    for i in range(count):
        t = i / SAMPLE_RATE
        envelope = math.exp(-11.0 * t)
        raw_noise = rng.uniform(-1.0, 1.0)
        filtered_noise = filtered_noise * 0.52 + raw_noise * 0.48
        grit = filtered_noise * 0.72
        crack = 0.0
        for impulse_time in (0.0, 0.035, 0.082, 0.135):
            dt = t - impulse_time
            if 0.0 <= dt < 0.018:
                crack += math.sin(2.0 * math.pi * (420.0 - 1800.0 * dt) * dt) * math.exp(-95.0 * dt)
        thump = math.sin(2.0 * math.pi * (105.0 - 55.0 * t) * t) * math.exp(-18.0 * t)
        samples.append((grit * envelope + crack * 0.34 + thump * 0.22) * 0.78)
    return samples


def place_sound() -> list[float]:
    rng = random.Random(701)
    duration = 0.17
    count = round(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(count):
        t = i / SAMPLE_RATE
        thump = math.sin(2.0 * math.pi * (150.0 - 80.0 * t) * t) * math.exp(-25.0 * t)
        click = rng.uniform(-1.0, 1.0) * math.exp(-90.0 * t)
        wooden_tone = math.sin(2.0 * math.pi * 285.0 * t) * math.exp(-36.0 * t)
        samples.append((thump * 0.72 + click * 0.20 + wooden_tone * 0.18) * 0.70)
    return samples


def material_impact(material: str, action: str) -> list[float]:
    seed = sum(ord(char) for char in material + action) + 1200
    rng = random.Random(seed)
    duration = 0.26 if action == "break" else 0.16
    count = round(SAMPLE_RATE * duration)
    profiles = {
        "grass": (95.0, 0.72, 0.34),
        "stone": (220.0, 0.32, 0.78),
        "wood": (145.0, 0.48, 0.50),
    }
    base_frequency, noise_amount, tone_amount = profiles[material]
    samples: list[float] = []
    filtered = 0.0
    decay = 10.0 if action == "break" else 24.0
    for i in range(count):
        t = i / SAMPLE_RATE
        envelope = math.exp(-decay * t)
        raw = rng.uniform(-1.0, 1.0)
        smoothing = 0.72 if material == "grass" else (0.25 if material == "stone" else 0.52)
        filtered = filtered * smoothing + raw * (1.0 - smoothing)
        frequency = base_frequency * (1.0 - 0.18 * t)
        tone = math.sin(2.0 * math.pi * frequency * t)
        if material == "stone":
            tone += 0.45 * math.sin(2.0 * math.pi * frequency * 2.73 * t)
        elif material == "wood":
            tone += 0.32 * math.sin(2.0 * math.pi * frequency * 1.52 * t)
        impulse = rng.uniform(-1.0, 1.0) * math.exp(-95.0 * t)
        samples.append((filtered * noise_amount + tone * tone_amount + impulse * 0.22) * envelope * 0.64)
    return samples


def footstep_sound(material: str) -> list[float]:
    samples = material_impact(material, "place")
    return [sample * 0.72 for sample in samples]


def wind_loop() -> list[float]:
    rng = random.Random(1501)
    duration = 8.0
    count = round(SAMPLE_RATE * duration)
    samples: list[float] = []
    low = 0.0
    slower = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        raw = rng.uniform(-1.0, 1.0)
        low = low * 0.985 + raw * 0.015
        slower = slower * 0.998 + low * 0.002
        gust = 0.52 + 0.25 * math.sin(2.0 * math.pi * 0.11 * t) + 0.16 * math.sin(2.0 * math.pi * 0.037 * t)
        fade = min(1.0, t / 0.5, (duration - t) / 0.5)
        samples.append((low * 0.52 + slower * 1.8) * gust * max(0.0, fade))
    return samples


def bird_chirp() -> list[float]:
    duration = 1.2
    count = round(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(count):
        t = i / SAMPLE_RATE
        value = 0.0
        for start, length, base in ((0.05, 0.18, 1650.0), (0.33, 0.16, 1950.0), (0.62, 0.24, 1480.0)):
            dt = t - start
            if 0.0 <= dt <= length:
                envelope = math.sin(math.pi * dt / length) ** 2
                frequency = base + 420.0 * math.sin(math.pi * dt / length)
                value += math.sin(2.0 * math.pi * frequency * dt) * envelope
        samples.append(value * 0.28)
    return samples


def ambient_music() -> list[float]:
    duration = 16.0
    count = round(SAMPLE_RATE * duration)
    samples: list[float] = []
    chord_frequencies = (130.81, 164.81, 196.00, 246.94)
    melody = (261.63, 293.66, 329.63, 293.66, 246.94, 261.63, 220.00, 246.94)
    for i in range(count):
        t = i / SAMPLE_RATE
        pad = 0.0
        for index, frequency in enumerate(chord_frequencies):
            pad += math.sin(2.0 * math.pi * frequency * t + index * 0.7) * (0.12 / (index + 1))
        note_index = int(t / 2.0) % len(melody)
        note_t = t % 2.0
        melody_envelope = math.sin(math.pi * min(1.0, note_t / 1.8)) ** 2
        lead = math.sin(2.0 * math.pi * melody[note_index] * t) * melody_envelope * 0.055
        slow_pulse = 0.82 + 0.18 * math.sin(2.0 * math.pi * t / duration)
        edge_fade = min(1.0, t / 1.0, (duration - t) / 1.0)
        samples.append((pad + lead) * slow_pulse * max(0.0, edge_fade))
    return samples


def main() -> None:
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    AMBIENT_DIR.mkdir(parents=True, exist_ok=True)
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    textures = {
        "grass.png": grass_texture(),
        "dirt.png": dirt_texture(),
        "stone.png": stone_texture(),
        "planks.png": planks_texture(),
        "bricks.png": bricks_texture(),
        "log.png": log_texture(),
        "leaves.png": leaves_texture(),
        "flower.png": flower_texture(),
        "crafting_table.png": crafting_table_texture(),
    }
    for filename, pixels in textures.items():
        write_png(TEXTURE_DIR / filename, pixels)
    write_wav(AUDIO_DIR / "block_break.wav", break_sound())
    write_wav(AUDIO_DIR / "block_place.wav", place_sound())
    for material in ("grass", "stone", "wood"):
        write_wav(AUDIO_DIR / f"break_{material}.wav", material_impact(material, "break"))
        write_wav(AUDIO_DIR / f"place_{material}.wav", material_impact(material, "place"))
        write_wav(AUDIO_DIR / f"step_{material}.wav", footstep_sound(material))
    write_wav(AMBIENT_DIR / "wind_loop.wav", wind_loop())
    write_wav(AMBIENT_DIR / "bird_chirp.wav", bird_chirp())
    write_wav(MUSIC_DIR / "little_world_theme.wav", ambient_music())
    print(f"Generated {len(textures)} textures and 14 audio assets in {ROOT}")


if __name__ == "__main__":
    main()
