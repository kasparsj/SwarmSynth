#!/usr/bin/env python3
"""Run SwarmAudition against only SuperCollider and SwarmSynth classes."""

from __future__ import annotations

import json
import os
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


PROJECT = Path(__file__).resolve().parent.parent
SCLANG = Path(
    os.environ.get("SCLANG")
    or shutil.which("sclang")
    or "/Applications/SuperCollider.app/Contents/MacOS/sclang"
).resolve()
CLASS_LIBRARY = Path(
    os.environ.get("SC_CLASS_LIBRARY")
    or SCLANG.parent.parent / "Resources/SCClassLibrary"
).resolve()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gui", action="store_true", help="run the standalone Qt smoke")
    args = parser.parse_args()
    test_file = "swarm-audition-gui.scd" if args.gui else "swarm-audition.scd"
    required = (
        SCLANG,
        CLASS_LIBRARY,
        PROJECT / "Classes/SwarmAudition.sc",
        PROJECT / "Classes/SwarmInstrumentRegistry.sc",
        PROJECT / "Classes/SwarmPartialPlotData.sc",
        PROJECT / "tests/support/SwarmAuditionTestDoubles.sc",
        PROJECT / "tests/swarm-audition.scd",
        PROJECT / "tests/swarm-audition-gui.scd",
    )
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("Missing standalone audition dependencies:\n" + "\n".join(missing))

    with tempfile.TemporaryDirectory(prefix="swarmsynth-audition-") as directory:
        runtime = Path(directory)
        overrides = runtime / "SystemOverwrites"
        overrides.mkdir()
        (overrides / "NoPersonalStartup.sc").write_text(
            "+ OSXPlatform { startupFiles { ^[] } }\n"
        )
        config = runtime / "sclang.yaml"
        config.write_text(
            "excludeDefaultPaths: true\nincludePaths:\n"
            + "".join(
                f"  - {json.dumps(str(path))}\n"
                for path in (
                    CLASS_LIBRARY,
                    PROJECT / "Classes",
                    PROJECT / "tests/support",
                    runtime,
                )
            )
        )
        result = subprocess.run(
            [str(SCLANG), "-D", "-l", str(config), str(PROJECT / "tests" / test_file)],
            cwd=PROJECT,
            env=os.environ.copy(),
            timeout=45,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(result.stdout, end="")
        marker = (
            "PASS: standalone SwarmAuditionGUI variants, cached plot, and lifecycle"
            if args.gui
            else "PASS: standalone SwarmAudition isolation, sampling, plotting, modes, and lifecycle"
        )
        if result.returncode or "ERROR:" in result.stdout or marker not in result.stdout:
            raise SystemExit(result.returncode or 1)


if __name__ == "__main__":
    main()
