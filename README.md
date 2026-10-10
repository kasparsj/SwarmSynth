# SwarmSynth

Additive swarms for SuperCollider, with reusable instruments, timed playback,
private audition controls, and partial-spectrum inspection.

Install this repository as a SuperCollider quark or add its `Classes` directory
to your class-library paths, then recompile the class library. Open the class
help files for API details and `examples/` for runnable usage. The reusable
classes depend on the standard SuperCollider library; server boot and SynthDef
installation are explicit in the examples.

- `SwarmMath`: pitch resolution, partial ratios, waveform recipes, normalization,
  Nyquist policies, reproducible snapshots, and spectrum reports.
- `SwarmSynth` and `SwarmInstrument`: sampled controls, variants, stable ramp
  targets, and explicit playback ownership and disposal.
- `SwarmPlayback`, `SwarmDensityAutomation`, and `SwarmInstrumentRegistry`:
  cancellable timed playback, density transitions, and instrument lookup.
- `SwarmAudition`, `SwarmAuditionGUI`, and `SwarmPartialPlotData`: private
  audition state, Qt controls, and cached generated-input spectrum estimates.
- `SwarmSynthDefs` and `SwarmInstruments`: reusable synthesis graphs; additive
  flute, clarinet, organ, marimba, and bell approximations; and a pitch-swept
  swarm kick with deep electronic, rough, and acoustic-like recipes.

Spectrum displays estimate synthesis inputs. Modulation, envelopes, filters,
and nonlinear processing can change the audible spectrum. The instrument
profiles are additive approximations; their musical quality requires listening.

## Verification

The runners use isolated class-library configurations and disable personal
startup scripts. Run from this repository:

```sh
python3 tests/run-swarmmath.py
python3 tests/run-playback.py
python3 tests/run-registry.py
python3 tests/run-density-automation.py
python3 tests/run-swarm-audition.py
python3 tests/run-swarm-audition-owner.py
python3 tests/run-audition-nyquist.py
python3 tests/run-synthdefs.py
python3 tests/run-standard-instruments.py
python3 tests/run-kick.py
```

The Nyquist regression and last two commands render offline audio with `scsynth`.
Standard instrument renders are written to ignored `output/standard-instruments/`; the three
kick auditions are retained in ignored `output/kick/`. Add `--gui` to
`run-swarm-audition.py` for the Qt smoke test. Automated checks establish the
covered contracts and numeric audio behavior, not an artistic audition.

Runners find the SuperCollider application on macOS by default. Set `SCLANG`,
`SC_CLASS_LIBRARY`, and, for offline renders, `SCSYNTH` to override its paths.

## Optional run ownership

`SwarmAudition` accepts a `runOwner` option for composition adapters that already
use a lifecycle manager. The factory receives `(facade, run)` after the root
Routine has been constructed and before it is scheduled. Return an object with
`run`, `fork`, `cleanup`, and `children`; the existing `run[\children]` field is
then an alias of the owner's collection. Without this option audition playback
uses its built-in ownership exactly as before, and SwarmSynth has no dependency
on StochasticSequencer.

Install and recompile SwarmSynth first, followed by an optional owner library
such as StochasticSequencer, then reload the composition setup. Stop playback
before recompiling the SuperCollider class library. A cleanup callback should
pass its captured run to `facade[\stopAudition].value(facade, run)` so a retired
owner cannot stop a replacement audition.

## Optional TidalCycles companion

See [the Haskell package](tidal/README.md) and [the explicitly installed
SuperDirt adapter](superdirt/README.md) for independent standard-instrument notes
and persistent swHold voices. Neither integration is required by the core
SuperCollider classes.
