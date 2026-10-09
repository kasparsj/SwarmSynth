#!/usr/bin/env python3
"""Run a disposable Tidal -> SuperDirt rehearsal on dedicated UDP/server ports."""

from pathlib import Path
import argparse
import importlib.util
import json
import math
import os
import struct
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[2]
SUPERDIRT = Path(os.environ.get("SUPERDIRT_PATH") or (
    Path.home() / "Library/Application Support/SuperCollider/downloaded-quarks/SuperDirt"
))
VOWEL = Path(os.environ.get("VOWEL_PATH") or SUPERDIRT.parent / "Vowel")
spec = importlib.util.spec_from_file_location("synthdefs_runner", ROOT / "tests/run-synthdefs.py")
assert spec and spec.loader
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)


def live_float_samples(path: Path) -> list[float]:
    data = path.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise AssertionError("live recording is not a WAV file")
    offset, fmt, audio = 12, None, None
    while offset + 8 <= len(data):
        kind = data[offset:offset + 4]
        size = struct.unpack_from("<I", data, offset + 4)[0]
        chunk = data[offset + 8:offset + 8 + size]
        if kind == b"fmt ":
            fmt = chunk
        if kind == b"data":
            audio = chunk
        offset += 8 + size + (size % 2)
    if fmt is None or audio is None:
        raise AssertionError("live recording has no WAV sample data")
    encoding, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", fmt)
    if encoding != 3 or channels != 2 or rate not in (44100, 48000) or bits != 32:
        raise AssertionError("live recording has an unexpected WAV format")
    samples = list(struct.unpack(f"<{len(audio) // 4}f", audio))
    if not all(math.isfinite(sample) for sample in samples):
        raise AssertionError("live recording contains non-finite samples")
    return samples


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--growth-seconds", type=float, default=0.6)
    arguments = parser.parse_args()
    if not math.isfinite(arguments.growth_seconds) or arguments.growth_seconds <= 0:
        parser.error("--growth-seconds must be a positive finite number")
    growth_wait = arguments.growth_seconds + 1.6
    rehearsal_duration = arguments.growth_seconds + 12.9
    with tempfile.TemporaryDirectory(prefix="swarm-dirt-live-") as directory:
        runtime = Path(directory)
        configuration = support.config(runtime)
        configuration.write_text(
            configuration.read_text(encoding="utf-8")
            + f"  - {json.dumps(str(SUPERDIRT))}\n"
            + f"  - {json.dumps(str(VOWEL))}\n",
            encoding="utf-8",
        )
        recording = runtime / "swarm-dirt-live.wav"
        environment = os.environ.copy()
        environment.update(
            SWARM_DIRT_ROOT=str(ROOT),
            SWARM_DIRT_LIVE_RECORDING=str(recording),
            SWARM_DIRT_LIVE_DURATION=str(rehearsal_duration),
        )
        tidal_source = (ROOT / "superdirt/tests/live-rehearsal.tidal").read_text(encoding="utf-8")
        tidal_source = tidal_source.replace(
            "swGrowSeconds 0.6", f"swGrowSeconds {arguments.growth_seconds}"
        ).replace("threadDelay 2200000", f"threadDelay {int(growth_wait * 1_000_000)}")
        tidal_path = runtime / "live-rehearsal.tidal"
        tidal_path.write_text(tidal_source, encoding="utf-8")
        process = subprocess.Popen(
            [str(support.SCLANG), "-D", "-l", str(configuration),
             str(ROOT / "superdirt/tests/swarm-dirt-live.scd")],
            cwd=ROOT,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        assert process.stdout is not None
        output: list[str] = []
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            line = process.stdout.readline()
            if not line:
                if process.poll() is not None:
                    break
                continue
            print(line, end="")
            output.append(line)
            if "READY: SwarmDirt live rehearsal" in line:
                break
        else:
            process.kill()
            raise TimeoutError("SuperDirt did not become ready")
        if not any("READY: SwarmDirt live rehearsal" in line for line in output):
            process.kill()
            raise RuntimeError("SuperDirt exited before becoming ready")

        tidal = subprocess.run(
            ["cabal", "repl", "--build-depends", "tidal", "--repl-options=-v0"],
            cwd=ROOT / "tidal",
            env=environment,
            stdin=tidal_path.open(encoding="utf-8"),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=arguments.growth_seconds + 30,
        )
        print(tidal.stdout, end="")
        if tidal.returncode:
            process.kill()
            raise SystemExit(tidal.returncode)

        remaining, _ = process.communicate(timeout=30)
        print(remaining, end="")
        output.append(remaining)
        joined = "".join(output)
        if (process.returncode or "ERROR:" in joined or "FAILURE IN SERVER" in joined
                or "PASS: SwarmDirt live Tidal transport rehearsal" not in joined):
            raise SystemExit(process.returncode or 1)
        samples = live_float_samples(recording)
        if max(map(abs, samples), default=0) < 1e-6:
            raise AssertionError("live Tidal/SuperDirt recording was silent")
        print("PASS: dedicated-port Tidal UDP transport and non-silent server recording")


if __name__ == "__main__":
    main()
