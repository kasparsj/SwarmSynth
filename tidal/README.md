# SwarmSynth for TidalCycles

This companion package defines the Tidal control vocabulary for the optional
SwarmSynth SuperDirt adapter. It targets GHC 9.6.7 and `tidal-core-1.10.1`.
It is a pure Haskell control package: it does not depend on SuperDirt or
SuperCollider, and importing it does not install sounds or mutate a stream.

## Load

Install the local library into the environment used by Tidal:

```sh
cd /Users/kasparsj/Work2/SwarmSynth/tidal
cabal v2-install --lib --package-env="$HOME/.ghc/aarch64-darwin-9.6.7/environments/default"
```

Add this import before `mkTidal`:

```haskell
import Sound.Tidal.SwarmSynth
```

After constructing the stream, bind emergency cleanup once:

```haskell
swBindPanic $ once $ s "swPanic"
```

The corresponding SuperCollider adapter must be installed separately. This
repository does not edit the user's package environment, BootTidal file, or
SuperDirt startup files automatically. See
[`examples/BootTidal.hs`](examples/BootTidal.hs) for a complete minimal boot.

## Controls

The public controls serialize directly to same-named OSC keys:

```haskell
swInstrument  :: Pattern String -> ControlPattern
swVoiceId     :: Pattern Int -> ControlPattern
swVariant     :: Pattern String -> ControlPattern
swPartials    :: Pattern Int -> ControlPattern
swVariations  :: Pattern Int -> ControlPattern
swDetune      :: Pattern Double -> ControlPattern
swMod         :: Pattern Double -> ControlPattern
swModFreq     :: Pattern Double -> ControlPattern
swPhase       :: Pattern Double -> ControlPattern
swPhaseFreq   :: Pattern Double -> ControlPattern
swPanFreq     :: Pattern Double -> ControlPattern
swNyquist     :: Pattern String -> ControlPattern
swSeed        :: Pattern Int -> ControlPattern
swRampSeconds :: Pattern Double -> ControlPattern
swGrowSeconds :: Pattern Double -> ControlPattern
swGrowPartials, swGrowVariations, swVowel :: Pattern Int -> ControlPattern
swVibratoSpeed, swVibratoDepth, swLPF, swHPF :: Pattern Double -> ControlPattern
swSweepRatio, swComb1, swComb2 :: Pattern Double -> ControlPattern
swPulse, swPulseFreq, swSaw, swSawFreq :: Pattern Double -> ControlPattern
```

Normal Tidal controls provide pitch, octave, gain, pan, orbit, room, size, and
other SuperDirt effects. `swNyquist` selects the adapter's registered policy by
name; Haskell never sends SuperCollider functions over OSC.

The standard adapter registrations have ready-to-use sound patterns:

```haskell
swFlute, swClarinet, swOrgan, swMarimba, swBell :: ControlPattern

d1 $ n "0 2 4 7" # swFlute # octave 5 # swPartials 16
```

They are ordinary `s "sw…"` events. Their recipes, variants, node limits,
envelope translation, and synthesis remain owned by the SuperCollider adapter.

## Persistent voices

```haskell
swHold    :: ControlPattern -> ControlPattern
swRelease :: Pattern Int -> ControlPattern
swFree    :: Pattern Int -> ControlPattern
swBindPanic :: IO () -> IO ()
swPanic   :: IO ()
```

`swHold` samples the source at sixteen evenly spaced events per cycle and adds
the internal `swOp = "hold"` command. It preserves the source pattern's time:
it does not play the pattern sixteen times faster. Each event refreshes or
updates the voice identified by adapter instance, orbit, and `swVoiceId`.

```haskell
d4 $ swHold
   $ s "swVoice"
   # swInstrument "swOrgan"
   # swVoiceId 1
   # n "0"
   # octave 2
   # swPartials 24
   # swRampSeconds 8
```

`swRelease ids` creates `swVoice` command events with `swOp = "release"`, so
the adapter keeps the configured release tail. `swFree ids` uses `swOp =
"free"` for immediate removal. Their voice-ID arguments are patterns, so one
call may address a patterned sequence of IDs.

`swPanic` runs the `IO` action installed by `swBindPanic`. Keeping the stream
action in BootTidal avoids hiding a specific stream or connection in this pure
package. Calling `swPanic` before binding fails explicitly. A normal binding is
`swBindPanic $ once $ s "swPanic"`; the adapter owns cancellation of pending
updates and immediate cleanup of all of its voices.

At the initial `cps = 0.25`, sixteen events per cycle means a heartbeat every
0.25 seconds. The receiving adapter calculates its actual timeout using the
heartbeat interval, latency, and its minimum timeout. Changing `cps` changes
the heartbeat interval accordingly.

See [`examples/StandardInstruments.tidal`](examples/StandardInstruments.tidal)
for transient and persistent examples.

## Test

The runner builds in a temporary directory and does not change global Cabal or
GHC configuration:

```sh
python3 tests/run-tests.py
python3 tests/run-coexistence.py
```

The second command builds a temporary project importing this package together
with the sibling StochasticSequencer Tidal package. It expects the repositories
to remain siblings under the same parent directory.
