#!/usr/bin/env python3
"""Run isolated SwarmDirt adapter contracts without booting an audio server."""

from pathlib import Path
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SUPERDIRT = Path(os.environ.get("SUPERDIRT_PATH") or (
    Path.home() / "Library/Application Support/SuperCollider/downloaded-quarks/SuperDirt"
))
VOWEL = Path(os.environ.get("VOWEL_PATH") or SUPERDIRT.parent / "Vowel")
spec = importlib.util.spec_from_file_location("synthdefs_runner", ROOT / "tests/run-synthdefs.py")
assert spec and spec.loader
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="swarm-dirt-") as directory:
        runtime = Path(directory)
        shutil.copy(ROOT / "tests/support/SwarmStandardScoreServer.sc", runtime)
        shutil.copy(ROOT / "superdirt/tests/SwarmDirtTestDoubles.sc", runtime)
        configuration = support.config(runtime)
        for dependency in (SUPERDIRT / "classes/SuperDirt.sc", VOWEL / "Vowel.sc"):
            if not dependency.exists():
                raise SystemExit(f"Missing SuperDirt test dependency: {dependency}")
        configuration.write_text(
            configuration.read_text(encoding="utf-8")
            + f"  - {json.dumps(str(SUPERDIRT))}\n"
            + f"  - {json.dumps(str(VOWEL))}\n",
            encoding="utf-8",
        )
        environment = os.environ.copy()
        environment.update(
            SWARM_DIRT_ROOT=str(ROOT),
            SWARM_DIRT_RENDER_DIR=str(runtime / "render"),
            SCSYNTH=str(support.SCSYNTH),
        )
        support.run(
            ROOT / "superdirt/tests/swarm-dirt.scd",
            configuration,
            environment,
            "PASS: SwarmDirt adapter contracts",
            45,
        )
        support.run(
            ROOT / "superdirt/tests/swarm-dirt-real.scd",
            configuration,
            environment,
            "PASS: SwarmDirt real SuperDirt registration smoke",
            45,
        )
        (runtime / "render").mkdir()
        result = subprocess.run(
            [str(support.SCLANG), "-D", "-l", str(configuration),
             str(ROOT / "superdirt/tests/swarm-dirt-render.scd")],
            cwd=ROOT,
            env=environment,
            timeout=90,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(result.stdout, end="")
        if (result.returncode or "ERROR:" in result.stdout
                or "PASS: SwarmDirt standard-instrument NRT renders" not in result.stdout):
            raise SystemExit(result.returncode or 1)
        for name in ("flute", "clarinet", "organ", "marimba", "bell", "kick"):
            samples = support.float_samples(runtime / f"render/swarm-dirt-{name}.wav")
            if max(map(abs, samples), default=0) < 1e-5:
                raise AssertionError(f"SwarmDirt {name} NRT render was silent")
            if max(map(abs, samples[-9600:]), default=0) > 1e-8:
                raise AssertionError(f"SwarmDirt {name} NRT render did not finish its tail")
    print("PASS: SwarmDirt fake lifecycle, real SuperDirt registration, and six finite NRT renders")


if __name__ == "__main__":
    main()
