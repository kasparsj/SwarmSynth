"""Run SwarmPlayback checks in an isolated sclang process."""

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

with tempfile.TemporaryDirectory(prefix="swarm-playback-tests-") as directory:
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
    try:
        result = subprocess.run(
            [str(SCLANG), "-D", "-l", str(config), str(ROOT / "tests/playback.scd")],
            cwd=ROOT,
            timeout=30,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
    except subprocess.TimeoutExpired as caught:
        output = caught.stdout or b""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        print(output, end="")
        raise SystemExit("SwarmPlayback tests timed out")
    print(result.stdout, end="")
    marker = "PASS: SwarmPlayback borrowed timed playback"
    if result.returncode or "ERROR:" in result.stdout or marker not in result.stdout:
        raise SystemExit(result.returncode or 1)
