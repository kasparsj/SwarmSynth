"""Run standalone SwarmMath inspection, sampling, and additive contracts."""

import importlib.util
import os
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("synthdefs_runner", ROOT / "tests/run-synthdefs.py")
assert spec and spec.loader
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)

CASES = {
    "swarmmath-inspection.scd": "PASS: SwarmMath indexing, snapshots, plotting data, formula, and validation",
    "swarmmath-playback-snapshot.scd": "PASS: SwarmMath playback snapshot order, metadata, and random semantics",
    "additive-library.scd": "PASS: SwarmMath additive library",
}

if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="swarmsynth-math-") as directory:
        configuration = support.config(Path(directory))
        for script, marker in CASES.items():
            support.run(ROOT / "tests" / script, configuration, os.environ.copy(), marker, 30)
