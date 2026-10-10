# Optional SuperDirt adapter

The core SwarmSynth classes and Haskell companion work without SuperDirt. Load
`SwarmDirt.scd` explicitly after starting stereo SuperDirt, then install:

```supercollider
"/path/to/SwarmSynth/superdirt/SwarmDirt.scd".load;
~swDirt = ~installSwarmDirt.(~dirt);
~swDirt.registerStandardInstruments;
```

Wait for the server to receive the definitions before playing. In a Routine,
`~dirt.server.sync` provides that barrier. The example under `examples/` installs
flute, clarinet, organ, marimba, bell and kick without any Pagrabs files.
Registrations are `swFlute`, `swClarinet`, `swOrgan`, `swMarimba`, `swBell`,
`swKick`. The melodic recipes use `natural`, `soft`, and `bright`; kick uses
`natural` (deep electronic), `rough`, and `acoustic`. Import
`Sound.Tidal.SwarmSynth` using the companion [installation guide](../tidal/README.md).

## Registration and ownership

```supercollider
~swDirt.registerInstrument(\swMyInstrument, mySwarmInstrument, releaseTime: 0.5);
~swDirt.removeInstrument(\swMyInstrument);
~swDirt.freeAll; // panic: sounds and pending commands, retaining registrations
~swDirt.dispose; // uninstall: also remove owned registrations and callbacks
```

Registration copies state, variants and default parameters. It borrows no
running player. `releaseTime` is a conservative bound on the recipe's release
tail; choose it to cover every registered variant. Spectral functions remain in
SuperCollider. Haskell sends recipe names and numerical shaping controls.
Calling `registerStandardInstruments` keeps registrations already owned by the
same manager, so a project-specific `swKick` and its catalog remain active while
the other standard sounds are added.

An independent note expands through `playInside`, inside Dirt's existing OSC
bundle. Every partial targets the event's synth group and output bus. Partial
controls are sampled once. Recipe amplitude and envelope sustain level remain
intact; Dirt's gate applies event gain once. Dirt's event lifetime is extended by
the registered tail. `sustain` also sets recipe `duration`/`dur` in seconds for
graphs using those names, and schedules gate closure for gated graphs.

## Held voices

Held playback requires a gated recipe. Use `s "swVoice"`, `swInstrument "swOrgan"`, `swVoiceId 1` inside `swHold`.
IDs are local to an adapter and orbit. Repeated equal controls refresh the
watchdog without restarting a ramp. Changed controls update or resize the
existing SwarmSynth; existing partial phase and pan are preserved. `swPhase`
explicitly changes phase, while ordinary Tidal `pan` positions the stereo voice.
Standard pitch, gain and orbit controls work for both modes. `note` and `n`
are semitone offsets from `octave * 12`; explicit `note` takes precedence over
`n`. Explicit `midinote` or `freq` overrides that default resolution. The
registration supplies a numeric MIDI pitch before Dirt caches the frequency,
for both independent notes and `swVoice`. Use `swVariant` for named timbres.
Tidal `#` takes event structure from its left side: use
`n "0 2 4 7" # swFlute` for four notes per cycle. A single `swFlute`
event on the left samples only the first pitch, even with `note` instead of `n`.

Each held voice owns a group, stereo bus and router into the orbit's `dryBus`,
before its global effects. It outlives individual Dirt events. The optional
fourth constructor argument `SwarmSynth.new(defName, defaults, hasGate,
targetGroup)` keeps synthesis on that target's server; the previous default
target remains available.

`swHold` samples sixteen events per cycle. The watchdog begins at the scheduled
playback time and releases after `max(0.75, 2*delta + latency + 0.1)` seconds
without updates. `swRelease` keeps the tail; `swFree` also cuts already released
tails for that ID. Retired voice epochs reject previously queued holds. New
holds sent after retirement can deliberately create a new voice.

`swGrowSeconds`, `swGrowPartials`, `swGrowVariations` request a prepared density
transition. Partials grow exponentially over the specified seconds; after a
one-second pause, variations reach the final value with a 0.3-second sampled
ramp. Equal heartbeats keep the transition running. Removing the growth request
cancels it. Both the current and final density obey allocation limits.

Bind emergency cleanup to the active Tidal stream after creating it:

```haskell
swBindPanic $ once $ s "swPanic"
```

Use `hush >> swPanic` to stop sending updates and immediately clear owned
sounds. The command is delivered through the normal Tidal transport. Reinstall,
CmdPeriod and disposal also clean owned voices, buses, callbacks and pending
work. Already submitted future note bundles are paired with server-side cleanup at their playback time. Other SuperDirt sounds remain available. Stereo orbits are required.

## Limits and supported controls

The installer defaults to 2,048 nodes per event/voice and 8,192 live owned
nodes overall; supply `maxPerVoice` and `maxTotal` to change them. Partial
nodes, release/shrink tails, each persistent router and its two owned groups
count against the budget. An allocation is rejected before node
creation. Cleanup works even when the budget is full.

Universal controls: `swPartials`, `swVariations`, `swVariant`, `swSeed`,
`swNyquist` (`none`, `fold`, `mute`, `taper`), `swDetune`, `swMod`, `swModFreq`,
`swPhase`, `swPhaseFreq`, `swPanFreq`, `swRampSeconds`. Graph-specific shaping:
`swPulse`, `swPulseFreq`, `swSaw`, `swSawFreq`, `swVowel`, `swVibratoSpeed`,
`swVibratoDepth`, `swLPF`, `swHPF`, `swSweepRatio`, `swComb1`, `swComb2`.
Kick-specific shaping: `swKickSweepRatio`, `swKickSweepTime`, `swKickAttack`,
`swKickDrive`; the universal `swDetune` control also applies to the kick.
Controls only affect recipes/graphs that consume the corresponding parameter.

## Verification

Run `python3 superdirt/tests/run-tests.py` from SwarmSynth. The runner uses an
isolated class library, injected scheduling clock, captured OSC, real SuperDirt
registration, and NRT rendering. Set `SUPERDIRT_PATH` and `VOWEL_PATH` to test
another installation. Callback compatibility was checked against the local
SuperDirt fork and upstream's `play`/`playInside` contract. Automated signal
checks do not substitute for an artistic listening rehearsal.

Run `python3 superdirt/tests/run-live-rehearsal.py` for a dedicated-server Tidal
UDP transport check; add `--growth-seconds 180` for the full growth duration.
Both passed, including overlaps, held updates without retriggering, growth,
variation reduction, silence timeout and panic. The recording checks establish
finite, non-silent output and silence after cleanup; human listening was not
performed.
