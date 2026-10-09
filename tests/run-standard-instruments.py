"""Isolated contracts, spectral/envelope NRT checks, and retained listening WAVs."""
from __future__ import annotations

import argparse
import importlib.util
import math
import os
import re
from pathlib import Path
import subprocess
import shutil
import tempfile
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("synthdefs_runner", ROOT / "tests/run-synthdefs.py")
assert spec and spec.loader
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)
RATIOS = {
    "flute": [1, 2, 3, 4, 5], "clarinet": [1, 3, 5, 7, 9],
    "organ": list(range(1, 9)), "marimba": [1, 4, 10],
    "bell": [.5, 1, 1.2, 1.5, 2, 3],
}


def peak(samples: list[float]) -> float:
    return max(map(abs, samples), default=0)


def projection(samples: list[float], frequency: float) -> float:
    # Hann-windowed projection avoids treating attack/decay leakage as a partial.
    count = len(samples)
    real = imag = 0.0
    for i, sample in enumerate(samples):
        weight = .5 - .5 * math.cos(2 * math.pi * i / (count - 1))
        angle = 2 * math.pi * frequency * i / 48000
        real += sample * weight * math.cos(angle)
        imag += sample * weight * math.sin(angle)
    return 4 * math.hypot(real, imag) / count


def verify(directory: Path, log: str) -> None:
    if log.count("NODE TREE Group 1") != 24 or log.count("NODE TREE Group 0") != 24:
        raise AssertionError("Missing server-side node cleanup queries")
    for section in log.split("NODE TREE Group 0")[1:]:
        tree = section.split("nextOSCPacket", 1)[0]
        if re.search(r"^\s+(?!1 group$)\d+ group$", tree, re.MULTILINE):
            raise AssertionError("Owned playback group survived disposal")
    # A child synth would be printed as its node id followed by swarm_partial.
    if any("swarm_partial" in line for line in log.splitlines()):
        raise AssertionError("A partial survived its expected envelope lifetime")
    for name, ratios in RATIOS.items():
        variants = {}
        for variant in ("natural", "soft", "bright"):
            samples = support.float_samples(directory / f"{name}-{variant}.wav")
            if not 1e-4 < peak(samples) < .3:
                raise AssertionError(f"{name}-{variant}: invalid signal level")
            if peak(samples[-9600:]) > 1e-9:
                raise AssertionError(f"{name}-{variant}: tail did not finish")
            if max(abs(a-b) for a, b in zip(samples[::2], samples[1::2])) > 1e-9:
                raise AssertionError(f"{name}-{variant}: centered stereo differs")
            variants[variant] = samples
        natural = variants["natural"][::2]
        # Held tones are inspected in sustain; strikes during the early decay.
        start, end = ((.06, .14) if name in ("marimba", "bell") else (.4, .7))
        window = natural[int(start * 48000):int(end * 48000)]
        for ratio in ratios:
            frequency = 440 * ratio
            target = projection(window, frequency)
            nearby = projection(window, frequency + 73)
            if target < 1e-6 or target < nearby * 3:
                raise AssertionError(f"{name}: missing spectral mode {frequency:g} Hz")
        for variant in ("soft", "bright"):
            if max(abs(a-b) for a, b in zip(variants[variant], variants["natural"])) < 1e-4:
                raise AssertionError(f"{name}-{variant}: indistinguishable render")
        if name not in ("marimba", "bell"):
            if peak(natural[int(.6 * 48000):int(.75 * 48000)]) < 1e-4:
                raise AssertionError(f"{name}: gate did not sustain")
            if peak(natural[int(1.2 * 48000):]) > 1e-9:
                raise AssertionError(f"{name}: gate did not release")
        phrase = support.float_samples(directory / f"{name}-listening.wav")
        if peak(phrase) < 1e-4 or peak(phrase[-9600:]) > 1e-9:
            raise AssertionError(f"{name}: invalid listening phrase")
    for name in ("marimba", "bell"):
        single = support.float_samples(directory / f"{name}-natural.wav")
        overlap = support.float_samples(directory / f"{name}-overlap.wav")
        # 0.256 seconds is exactly 192 control blocks at 48 kHz; summed tails prove overlap.
        shift = 12288 * 2
        error = max(abs(value - single[i] - (single[i-shift] if i >= shift else 0))
                    for i, value in enumerate(overlap))
        if error > 2e-5:
            raise AssertionError(f"{name}: retrigger did not preserve old tail ({error:g})")
    routed = support.float_samples(directory / "organ-route.wav", 4)
    if peak(routed[0::4] + routed[1::4]) > 1e-9 or peak(routed[2::4]) < 1e-4:
        raise AssertionError("Output routing failed")
    if peak(support.float_samples(directory / "marimba-nyquist.wav")) > 1e-9:
        raise AssertionError("Above-Nyquist modes were not suppressed")


def listening_preview(directory: Path) -> None:
    durations = {"flute": 3.1, "clarinet": 3.1, "organ": 3.1, "marimba": 4.0, "bell": 8.0}
    timeline = []
    offset = 0.0
    with wave.open(str(directory / "listening-preview.wav"), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(48000)
        for name, duration in durations.items():
            samples = support.float_samples(directory / f"{name}-listening.wav")[:int(duration * 48000) * 2]
            timeline.append(f"- {offset:.1f}s: {name}")
            output.writeframes(struct.pack(f"<{len(samples)}h", *(round(value * 32767) for value in samples)))
            offset += duration
    (directory / "README.md").write_text(
        "# SwarmInstruments listening renders\n\n"
        "`listening-preview.wav` presents natural flute, clarinet, organ, marimba, then bell.\n\n"
        + "\n".join(timeline)
        + "\n\nIndividual `<name>-<variant>.wav` files compare natural, soft, and bright at 440 Hz "
        "and an amplitude budget of 0.2 per base frequency. `<name>-listening.wav` plays four notes. "
        "Levels are numerically normalized, not perceptually matched.\n\n"
        "Generated through captured SwarmInstrument.play OSC and offline scsynth. "
        "These are additive approximations; recognizability and musical quality require listening.\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "output/standard-instruments")
    args = parser.parse_args()
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="swarm-standard-") as temporary:
        shutil.copy(ROOT / "tests/support/SwarmStandardScoreServer.sc", temporary)
        config = support.config(Path(temporary))
        environment = os.environ.copy()
        environment.update(SCSYNTH=str(support.SCSYNTH), SWARM_STANDARD_RENDER_DIR=str(directory))
        plugins = support.SCSYNTH.parent / "plugins"
        if plugins.is_dir():
            environment["SWARM_STANDARD_NRT_OPTIONS"] = "-U " + str(plugins)
        support.run(ROOT / "tests/standard-instruments.scd", config, environment,
                    "PASS: SwarmInstruments contracts", 45)
        result = subprocess.run([str(support.SCLANG), "-D", "-l", str(config),
                                 str(ROOT / "tests/standard-instruments-render.scd")],
                                cwd=ROOT, env=environment, timeout=180, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (directory / "verification.log").write_text(result.stdout)
        if result.returncode or "ERROR:" in result.stdout or "FAILURE IN SERVER" in result.stdout or "PASS: SwarmInstruments NRT renders" not in result.stdout:
            print(result.stdout[-6000:])
            raise SystemExit(result.returncode or 1)
        verify(directory, result.stdout)
        listening_preview(directory)
    print(f"PASS: 24 NRT renders, spectra, variants, gates, overlap, routing, Nyquist, and node cleanup; WAVs: {directory}")


if __name__ == "__main__":
    main()
