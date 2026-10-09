#!/usr/bin/env python3
"""Build and run the Tidal companion tests without changing global config."""

from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="swarm-synth-tidal-") as build_dir:
        command = [
            "cabal",
            "v2-test",
            "--offline",
            f"--builddir={build_dir}",
            "all",
            "--test-show-details=direct",
        ]
        return subprocess.run(command, cwd=ROOT, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
