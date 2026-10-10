"""Render and verify the three shared SwarmInstruments kick recipes."""
from __future__ import annotations

import argparse
import importlib.util
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("synthdefs_runner", ROOT / "tests/run-synthdefs.py")
assert spec and spec.loader
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)


def peak(samples: list[float]) -> float:
    return max(map(abs, samples), default=0.0)


def projection(samples: list[float], frequency: float) -> float:
    count = len(samples)
    real = imag = 0.0
    for index, sample in enumerate(samples):
        weight = 0.5 - 0.5 * math.cos(2 * math.pi * index / (count - 1))
        angle = 2 * math.pi * frequency * index / 48000
        real += sample * weight * math.cos(angle)
        imag += sample * weight * math.sin(angle)
    return 4 * math.hypot(real, imag) / count


def verify(directory: Path, log: str) -> None:
    if log.count("NODE TREE Group 1") != 7 or log.count("NODE TREE Group 0") != 7:
        raise AssertionError("missing kick node-cleanup queries")
    for section in log.split("NODE TREE Group 1")[1:]:
        tree = section.split("nextOSCPacket", 1)[0]
        if "swarm_kick" in tree:
            raise AssertionError("a kick partial survived its envelope")
    for section in log.split("NODE TREE Group 0")[1:]:
        tree = section.split("nextOSCPacket", 1)[0]
        if re.search(r"^\s+(?!1 group$)\d+ group$", tree, re.MULTILINE):
            raise AssertionError("owned kick playback group survived disposal")

    renders: dict[str, list[float]] = {}
    for variant in ("natural", "rough", "acoustic"):
        samples = support.float_samples(directory / f"kick-{variant}.wav")
        if not 1e-4 < peak(samples) < 0.5:
            raise AssertionError(f"{variant}: invalid default peak")
        if peak(samples[-9600:]) > 1e-9:
            raise AssertionError(f"{variant}: tail did not finish")
        if max(abs(left - right) for left, right in zip(samples[::2], samples[1::2])) > 1e-9:
            raise AssertionError(f"{variant}: centered stereo channels differ")
        mono = samples[::2]
        body = mono[int(0.08 * 48000):int(0.28 * 48000)]
        if projection(body, 55) < 1e-4:
            raise AssertionError(f"{variant}: missing low-frequency body")
        renders[variant] = samples
    for variant in ("rough", "acoustic"):
        difference = max(abs(a - b) for a, b in zip(renders["natural"], renders[variant]))
        if difference < 1e-3:
            raise AssertionError(f"{variant}: indistinguishable from natural")

    overlap = support.float_samples(directory / "kick-overlap.wav")
    single = renders["natural"]
    shift = 12288 * 2  # 0.256 seconds at 48 kHz, stereo interleaved.
    error = max(abs(value - single[index] - (single[index - shift] if index >= shift else 0))
                for index, value in enumerate(overlap))
    if error > 2e-5:
        raise AssertionError(f"overlap did not retain the first tail ({error:g})")

    repeated = support.float_samples(directory / "kick-repeated.wav")[::2]
    for start in (0.01, 0.21, 0.41, 0.61):
        window = repeated[int(start * 48000):int((start + 0.08) * 48000)]
        if peak(window) < 1e-4:
            raise AssertionError(f"repeated hit missing at {start:g}s")
    extremes = support.float_samples(directory / "kick-extremes.wav")
    if peak(extremes) < 1e-6 or peak(extremes[-9600:]) > 1e-9:
        raise AssertionError("bounded extreme controls did not render and clean up")
    if peak(support.float_samples(directory / "kick-nyquist.wav")) > 1e-9:
        raise AssertionError("moving above-Nyquist kick frequencies were not muted")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "output/kick")
    args = parser.parse_args()
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="swarm-kick-") as temporary:
        runtime = Path(temporary)
        shutil.copy(ROOT / "tests/support/SwarmStandardScoreServer.sc", runtime)
        configuration = support.config(runtime)
        environment = os.environ.copy()
        environment.update(SCSYNTH=str(support.SCSYNTH), SWARM_KICK_RENDER_DIR=str(directory))
        plugins = support.SCSYNTH.parent / "plugins"
        if plugins.is_dir():
            environment["SWARM_KICK_NRT_OPTIONS"] = "-U " + str(plugins)
        support.run(ROOT / "tests/standard-instruments.scd", configuration, environment,
                    "PASS: SwarmInstruments contracts", 45)
        result = subprocess.run(
            [str(support.SCLANG), "-D", "-l", str(configuration),
             str(ROOT / "tests/kick-render.scd")],
            cwd=ROOT, env=environment, timeout=120, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        (directory / "verification.log").write_text(result.stdout)
        if (result.returncode or "ERROR:" in result.stdout or
                "FAILURE IN SERVER" in result.stdout or
                "PASS: Swarm kick NRT renders" not in result.stdout):
            print(result.stdout[-6000:])
            raise SystemExit(result.returncode or 1)
        verify(directory, result.stdout)
    (directory / "README.md").write_text(
        "# Swarm kick listening renders\n\n"
        "- `kick-natural.wav`: Deep Electronic (the default)\n"
        "- `kick-rough.wav`: Rough Swarm\n"
        "- `kick-acoustic.wav`: Acoustic-like\n\n"
        "Each audition is an offline 55 Hz hit using the shared SwarmSynth definition. "
        "Automated checks cover finite samples, conservative peaks, low-frequency body, "
        "distinct profiles, overlap, extremes, Nyquist handling, and cleanup. Musical "
        "quality still requires listening.\n"
    )
    print(f"PASS: 7 kick NRT cases and three listening WAVs: {directory}")


if __name__ == "__main__":
    main()
