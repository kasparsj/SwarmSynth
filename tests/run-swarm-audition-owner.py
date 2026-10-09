#!/usr/bin/env python3
"""Verify SwarmAudition's optional lifecycle-owner protocol in isolation."""

from __future__ import annotations

import json
import os
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
    test = PROJECT / "tests/swarm-audition-run-owner.scd"
    with tempfile.TemporaryDirectory(prefix="swarmsynth-run-owner-") as directory:
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
            [str(SCLANG), "-D", "-l", str(config), str(test)],
            cwd=PROJECT,
            env=os.environ.copy(),
            timeout=45,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(result.stdout, end="")
        marker = "PASS: optional SwarmAudition run owner lifecycle"
        if result.returncode or "ERROR:" in result.stdout or marker not in result.stdout:
            raise SystemExit(result.returncode or 1)


if __name__ == "__main__":
    main()
