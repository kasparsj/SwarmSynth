(
var check, variants, spec, registry, resolverCalls = 0;
var currentState, currentSynth, replacementState, replacementSynth;
var event, routine, yielded, result, completed, error, nan;
var mathState, mathSynth, mathRegistry;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
variants = (
	original: (args: (
		freq: { |e| e.freq * e.p1 },
		amp: { |e| e.vol / e.p1 }, phase: 0, pan: 0
	), partials: 2, variations: 1)
);
spec = (synthDef: \playbackTest, variant: \original,
	hasGate: true, liveSwitch: \sustained);
currentState = SwarmPlaybackTestState.new;
currentSynth = SwarmPlaybackTestSynth.new;
registry = SwarmInstrumentRegistry.new;
registry.register(\unrelatedVoice, { |environment|
	resolverCalls = resolverCalls + 1;
	(synth: currentSynth, state: currentState)
}, spec, variants, ());

// Invalid scheduling values fail before lookup, event mutation, or playback.
nan = Float.from32Bits(16r7FC00000);
[-1, inf, nan].do { |invalid|
	error = try {
		SwarmPlayback.play(registry, \unrelatedVoice, (duration: 9), invalid);
		nil
	} { |caught| caught };
	check.(error.notNil and: { error.what.contains("waitBeats") },
		"invalid wait did not fail descriptively");
};
check.(resolverCalls == 0, "invalid wait resolved the registry");
check.(currentState.events.isEmpty, "invalid wait mutated state");
check.(currentSynth.sets.isEmpty, "invalid wait updated playback");

// The event's envelope duration is independent from the yielded wait value.
event = (duration: 9, velocity: 0.75);
completed = false;
routine = Routine {
	result = SwarmPlayback.play(registry, \unrelatedVoice, event, 3,
		closeGate: true, excludeParams: [\phase, \pan]);
	completed = true;
};
yielded = routine.next;
check.(yielded == 3, "playback did not yield the supplied waitBeats");
check.(completed.not, "playback completed before its caller resumed");
check.(resolverCalls == 1, "playback did not resolve exactly once before waiting");
check.(currentState.values[\duration] == 9,
	"event duration was coupled to the wait value");
check.(currentState.values[\velocity] == 0.75, "event values were not applied");
check.(currentSynth.sets.size == 1, "playback was not updated exactly once");
check.(currentSynth.sets[0][\state] === currentState,
	"playback did not receive the resolved raw state");
check.(currentSynth.sets[0][\excludeParams] == [\phase, \pan],
	"excluded parameters were not forwarded");

// Replacement during the wait cannot redirect gate closure.
replacementState = SwarmPlaybackTestState.new;
replacementSynth = SwarmPlaybackTestSynth.new;
currentState = replacementState;
currentSynth = replacementSynth;
routine.next;
check.(completed, "playback did not finish after the caller resumed");
check.(resolverCalls == 1, "playback resolved the registry again after waiting");
check.(currentSynth.closedGates == 0,
	"gate closure followed a replacement binding");
check.(result[\synth].closedGates == 1,
	"gate closure did not use the originally resolved synth");
check.(result[\state].values[\duration] == 9,
	"returned resolution did not retain the original state");

// A later call resolves the replacement binding afresh.
routine = Routine {
	SwarmPlayback.play(registry, \unrelatedVoice, (duration: 2), 0);
};
check.(routine.next == 0, "zero wait did not yield zero beats");
routine.next;
check.(resolverCalls == 2, "later playback did not perform one fresh lookup");
check.(replacementState.values[\duration] == 2 and: {
	 replacementSynth.sets.size == 1
}, "later playback did not resolve replacement bindings");

// Stopping the caller while suspended cancels the pending gate closure.
completed = false;
routine = Routine {
	SwarmPlayback.play(registry, \unrelatedVoice, (duration: 5), 8,
		closeGate: true);
	completed = true;
};
check.(routine.next == 8, "caller-stop case did not suspend at its wait");
routine.stop;
routine.next;
check.(completed.not, "stopped caller resumed playback completion");
check.(replacementSynth.closedGates == 0,
	"stopping the caller did not cancel pending gate closure");

// nextTrigger registrations still use raw state/synth operations: no reset.
mathState = SwarmMath.new([220], 2, 1, variants[\original][\args].deepCopy, 0.2);
mathSynth = SwarmPlaybackTestSynth.new;
mathRegistry = SwarmInstrumentRegistry.new;
mathRegistry.register(\nextNote, { |environment|
	(synth: mathSynth, state: mathState)
}, (synthDef: \playbackTest, variant: \original,
	hasGate: false, liveSwitch: \nextTrigger), variants, ());
routine = Routine {
	SwarmPlayback.play(mathRegistry, \nextNote, (freq: 330, duration: 4), 1);
};
check.(routine.next == 1, "SwarmMath playback yielded the wrong beat value");
check.(mathState.freqs[0] == 330, "SwarmMath event was not applied");
check.(mathSynth.sets.size == 1, "SwarmMath playback was not updated");
check.(mathSynth.resets == 0,
	"nextTrigger playback used SwarmInstrument.play and reset the synth");
routine.next;

registry.dispose;
mathRegistry.dispose;
[result[\synth], replacementSynth, mathSynth].do { |synth|
	check.(synth.releases == 0 and: { synth.disposals == 0 },
		"SwarmPlayback took ownership of borrowed playback");
};

"PASS: SwarmPlayback borrowed timed playback".postln;
0.exit;
)
