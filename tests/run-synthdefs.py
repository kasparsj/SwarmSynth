"""Verify reusable sine SynthDefs against frozen Pagrabs graphs and NRT audio."""

from __future__ import annotations

import json
import argparse
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
SCLANG = Path(os.environ.get("SCLANG") or shutil.which("sclang") or "/Applications/SuperCollider.app/Contents/MacOS/sclang").resolve()
SCSYNTH = Path(os.environ.get("SCSYNTH") or shutil.which("scsynth") or "/Applications/SuperCollider.app/Contents/Resources/scsynth").resolve()
CLASS_LIBRARY = Path(os.environ.get("SC_CLASS_LIBRARY") or SCLANG.parent.parent / "Resources/SCClassLibrary").resolve()


def config(runtime: Path) -> Path:
    overrides = runtime / "SystemOverwrites"
    overrides.mkdir()
    (overrides / "NoPersonalStartup.sc").write_text("+ OSXPlatform { startupFiles { ^[] } }\n")
    target = runtime / "sclang.yaml"
    target.write_text(
        "excludeDefaultPaths: true\nincludePaths:\n"
        + "".join(f"  - {json.dumps(str(path))}\n" for path in (CLASS_LIBRARY, ROOT / "Classes", runtime))
    )
    return target


def run(script: Path, configuration: Path, environment: dict[str, str], marker: str, timeout: int = 120) -> None:
    result = subprocess.run(
        [str(SCLANG), "-D", "-l", str(configuration), str(script)],
        cwd=ROOT, env=environment, timeout=timeout, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    print(result.stdout, end="")
    if result.returncode or "ERROR:" in result.stdout or marker not in result.stdout:
        raise SystemExit(result.returncode or 1)


def float_samples(path: Path, expected_channels: int = 2) -> list[float]:
    data = path.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise AssertionError(f"{path.name}: invalid WAV")
    offset, fmt, audio = 12, None, None
    while offset + 8 <= len(data):
        kind = data[offset:offset + 4]
        size = struct.unpack_from("<I", data, offset + 4)[0]
        chunk = data[offset + 8:offset + 8 + size]
        if kind == b"fmt ": fmt = chunk
        if kind == b"data": audio = chunk
        offset += 8 + size + (size % 2)
    if fmt is None or audio is None:
        raise AssertionError(f"{path.name}: missing WAV data")
    encoding, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", fmt)
    if (encoding, channels, rate, bits) != (3, expected_channels, 48000, 32):
        raise AssertionError(f"{path.name}: unexpected WAV format")
    values = list(struct.unpack(f"<{len(audio) // 4}f", audio))
    if not all(math.isfinite(value) for value in values):
        raise AssertionError(f"{path.name}: non-finite sample")
    return values


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, help="also verify Pagrabs aliases")
    arguments = parser.parse_args()
    project = arguments.project.resolve() if arguments.project else None
    required_paths = [SCLANG, SCSYNTH, CLASS_LIBRARY, ROOT / "Classes/SwarmSynthDefs.sc"]
    if project:
        required_paths.append(project / "synths/additive.scd")
    for required in required_paths:
        if not required.exists():
            raise SystemExit(f"Missing SynthDef test dependency: {required}")
    with tempfile.TemporaryDirectory(prefix="swarm-synthdefs-") as directory:
        runtime = Path(directory)
        environment = os.environ.copy()
        environment.update({"SCSYNTH": str(SCSYNTH), "SWARM_SYNTHDEF_RENDER_DIR": str(runtime / "renders")})
        plugins = SCSYNTH.parent / "plugins"
        if plugins.is_dir():
            environment["SWARM_SYNTHDEF_NRT_OPTIONS"] = "-U " + str(plugins)
        if project:
            environment["PAGRABS_PROJECT"] = str(project)
        else:
            environment.pop("PAGRABS_PROJECT", None)
        (runtime / "renders").mkdir()
        configuration = config(runtime)
        run(ROOT / "tests/synthdefs.scd", configuration, environment,
            "PASS: SwarmSynthDefs frozen graphs, controls, inert builders, install, and optional aliases", 30)
        run(ROOT / "tests/synthdefs-render.scd", configuration, environment,
            "PASS: SwarmSynthDefs seeded NRT parity", 120)
        baselines = sorted((runtime / "renders").glob("baseline-*.wav"))
        if len(baselines) != 11:
            raise AssertionError(f"expected 11 seeded parity cases, got {len(baselines)}")
        for baseline_path in baselines:
            label = baseline_path.name.removeprefix("baseline-")
            channels = 4 if label == "pad-route-out2.wav" else 2
            baseline = float_samples(baseline_path, channels)
            current = float_samples(runtime / "renders" / f"current-{label}", channels)
            if len(baseline) != len(current):
                raise AssertionError(f"{label}: render lengths differ")
            difference = max(abs(a - b) for a, b in zip(baseline, current))
            if difference > 1e-7:
                raise AssertionError(f"{label}: seeded NRT difference {difference:g}")
            if channels == 4:
                for variant, samples in (("baseline", baseline), ("current", current)):
                    leading_peak = max(abs(value) for value in samples[0::4] + samples[1::4])
                    routed_peak = max(abs(value) for value in samples[2::4] + samples[3::4])
                    if leading_peak > 1e-12:
                        raise AssertionError(
                            f"{variant} {label}: leading outputs are not silent ({leading_peak:g})"
                        )
                    if routed_peak < 1e-5:
                        raise AssertionError(
                            f"{variant} {label}: routed outputs are silent ({routed_peak:g})"
                        )
    print("PASS: SwarmSynthDefs exact graph/control and 11-case seeded NRT parity")


if __name__ == "__main__":
    main()
