#!/usr/bin/env python3
"""Compile a temporary project importing both local Tidal companions."""

from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
STOCHASTIC = ROOT.parent.parent / "StochasticSequencer" / "tidal"


def main() -> int:
    if not (STOCHASTIC / "stochastic-sequencer-tidal.cabal").exists():
        raise SystemExit(f"missing sibling package: {STOCHASTIC}")

    with tempfile.TemporaryDirectory(prefix="swarm-stochastic-coexistence-") as temp:
        workspace = Path(temp)
        (workspace / "src").mkdir()
        (workspace / "cabal.project").write_text(
            f"packages: . {ROOT} {STOCHASTIC}\noptimization: 1\n",
            encoding="utf-8",
        )
        (workspace / "companion-coexistence.cabal").write_text(
            """cabal-version: 2.4
name: companion-coexistence
version: 0.1.0
build-type: Simple

executable companion-coexistence
  main-is: Main.hs
  hs-source-dirs: src
  build-depends:
      base >=4.18 && <5
    , stochastic-sequencer-tidal
    , swarm-synth-tidal
    , tidal-core ==1.10.1
  default-language: Haskell2010
  ghc-options: -Wall
""",
            encoding="utf-8",
        )
        (workspace / "src" / "Main.hs").write_text(
            """module Main (main) where

import Sound.Tidal.StochasticSequencer (stcycle)
import Sound.Tidal.SwarmSynth (swHold, swOrgan)

main :: IO ()
main = (swHold $ stcycle 0.5 swOrgan) `seq` pure ()
""",
            encoding="utf-8",
        )
        command = ["cabal", "v2-build", "--offline", "all"]
        return subprocess.run(command, cwd=workspace, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
