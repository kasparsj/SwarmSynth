#!/usr/bin/env python3
"""Run SwarmDensityAutomation checks in an isolated sclang process."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
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
    required = (
        SCLANG,
        CLASS_LIBRARY,
        ROOT / "Classes/SwarmMath.sc",
        ROOT / "Classes/SwarmDensityAutomation.sc",
        ROOT / "tests/support/SwarmDensityTestSynth.sc",
        ROOT / "tests/density-automation.scd",
    )
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("Missing density test dependencies:\n" + "\n".join(missing))

    with tempfile.TemporaryDirectory(prefix="swarmsynth-density-") as directory:
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
                    ROOT / "Classes",
                    ROOT / "tests/support",
                    runtime,
                )
            )
        )
        result = subprocess.run(
            [str(SCLANG), "-D", "-l", str(config), str(ROOT / "tests/density-automation.scd")],
            cwd=ROOT,
            timeout=30,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(result.stdout, end="")
        marker = "PASS: standalone SwarmDensityAutomation validation, timing, and cancellation"
        if result.returncode or "ERROR:" in result.stdout or marker not in result.stdout:
            raise SystemExit(result.returncode or 1)


if __name__ == "__main__":
    main()
