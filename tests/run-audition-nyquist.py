"""Verify inherited audition policy through sampled controls, plots, and NRT audio."""

import importlib.util
import os
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("synthdefs_runner", ROOT / "tests/run-synthdefs.py")
assert spec and spec.loader
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)

if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="swarm-audition-nyquist-") as directory:
        runtime = Path(directory)
        shutil.copy(ROOT / "tests/support/SwarmAuditionTestDoubles.sc", runtime)
        configuration = support.config(runtime)
        environment = os.environ.copy()
        environment.update(SCSYNTH=str(support.SCSYNTH), SWARM_NYQUIST_RENDER_DIR=str(runtime))
        support.run(ROOT / "tests/audition-nyquist.scd", configuration, environment,
                    "PASS: audition inherited Nyquist controls and plots", 60)
        for name in ("inherited", "explicit-mute", "explicit-taper", "restored-inherit"):
            samples = support.float_samples(runtime / f"{name}.wav")
            assert max(map(abs, samples)) < 1e-9, f"{name}: above-Nyquist partial produced audio"
        for name in ("explicit-bypass", "explicit-fold"):
            samples = support.float_samples(runtime / f"{name}.wav")
            assert max(map(abs, samples)) > 1e-4, f"{name}: explicit audible policy produced silence"
    print("PASS: audition inherited mute, all explicit policies, and restored inheritance NRT")
