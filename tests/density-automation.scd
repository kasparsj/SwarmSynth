(
var check, expectError, makeState, clock, nan;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
expectError = { |function, fragment, state, synth|
	var before = [state.partials, state.variations], error;
	error = try { function.value; nil } { |caught| caught };
	check.(error.notNil and: { error.what.contains(fragment) },
		"Expected error containing '%'".format(fragment));
	check.([state.partials, state.variations] == before,
		"Invalid automation mutated density");
	check.(synth.ramps.isEmpty, "Invalid automation ramped playback");
};
makeState = { |partials=1, variations=1|
	SwarmMath.new([110], partials, variations,
		[freq: 110, amp: 0.1, phase: 0, pan: 0], 0.1)
};
nan = Float.from32Bits(16r7FC00000);

// All argument and current-state checks happen before the first mutation.
[
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \frequency, 1, 1, 2) }, "key"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, "partials", 1, 1, 2) }, "key"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 1, 0, 2) }, "from"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 1, 1.5, 2) }, "from"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 1, 1, 1.5) }, "to"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 1, 1, 0) }, "to"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 0, 1, 2) }, "duration"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, -1, 1, 2) }, "duration"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, inf, 1, 2) }, "duration"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, nan, 1, 2) }, "duration"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 1, 1, 2, -0.1) }, "rampTime"],
	[{ |state, synth| SwarmDensityAutomation.run(state, synth, \partials, 1, 1, 2, inf) }, "rampTime"]
].do { |case|
	var state = makeState.(), synth = SwarmDensityTestSynth.new;
	expectError.({ case[0].value(state, synth) }, case[1], state, synth);
};
{
	var state = makeState.(0), synth = SwarmDensityTestSynth.new;
	expectError.({ SwarmDensityAutomation.run(state, synth, \partials, 1, 1, 2) },
		"current partials", state, synth);
}.value;

clock = TempoClock(100);
Routine {
	var state, synth, child, stoppedValue, stoppedRamps, intervals;

	// Both supported fields grow through repeated rampTo calls. Because the
	// loop never forces `to`, the last sampled integer remains below it.
	state = makeState.();
	synth = SwarmDensityTestSynth.new;
	SwarmDensityAutomation.run(state, synth, \partials, 0.035, 1, 64, 0.002);
	check.(state.partials > 1 and: { state.partials < 64 },
		"Partial growth did not retain the sampled pre-endpoint value");
	check.(synth.ramps.notEmpty and: {
		synth.ramps.every { |ramp| ramp.duration == 0.002 }
	}, "Partial growth did not ramp each density change");

	state = makeState.();
	synth = SwarmDensityTestSynth.new;
	SwarmDensityAutomation.run(state, synth, \variations, 0.025, 1, 32, 0);
	check.(state.variations > 1 and: { state.variations < 32 },
		"Variation growth or no-forced-endpoint behavior changed");
	check.(synth.ramps.every { |ramp| ramp.partials == 1 },
		"Variation automation changed the other density field");

	// Descending targets remain a no-op: this is intentionally grow-only.
	state = makeState.(10, 5);
	synth = SwarmDensityTestSynth.new;
	SwarmDensityAutomation.run(state, synth, \partials, 0.01, 10, 2, 0);
	check.(state.partials == 10 and: { synth.ramps.isEmpty },
		"Descending density stopped being grow-only");

	// Waits are yielded to the caller's clock. At tempo 10, the 0.2-beat
	// post-change pause plus 0.1 polling wait separates ramps by about 0.03s.
	clock.tempo = 10;
	state = makeState.();
	synth = SwarmDensityTestSynth.new;
	SwarmDensityAutomation.run(state, synth, \partials, 0.11, 1, 1024, 0.1);
	check.(synth.times.size >= 2, "Timing case did not produce repeated ramps");
	intervals = synth.times.differentiate.copyToEnd(1);
	check.(intervals.every { |interval| interval >= 0.022 },
		"Density waits did not run on the caller's TempoClock");

	// Stopping the caller is the sole cancellation boundary.
	clock.tempo = 100;
	state = makeState.();
	synth = SwarmDensityTestSynth.new;
	child = Routine {
		SwarmDensityAutomation.run(state, synth, \partials, 2, 1, 100000, 0.01)
	}.play(clock);
	(clock.tempo * 0.04).wait;
	child.stop;
	stoppedValue = state.partials;
	stoppedRamps = synth.ramps.size;
	(clock.tempo * 0.03).wait;
	check.(child.isPlaying.not, "Stopped caller Routine remained active");
	check.(state.partials == stoppedValue and: { synth.ramps.size == stoppedRamps },
		"Density progression continued after caller stop");

	clock.stop;
	"PASS: standalone SwarmDensityAutomation validation, timing, and cancellation".postln;
	0.exit;
}.play(clock);
)
