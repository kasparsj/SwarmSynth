// Run with python3 tests/run-swarmmath-playback-snapshot.py. No server is started.
(
var check, checkThrows, log, state, calcPairs, calcOrder, records;
var randomState, preserved, consumed, randomBefore, playbackValues, snapshotValues;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
checkThrows = { |action, message|
	var caught = try { action.value; nil } { |caughtError| caughtError };
	check.(caught.notNil, message);
};

try {
	log = List.new;
	state = SwarmMath.new([100], 1, 1, [
		\ratio, { |event| log.add(\ratio); event.p1 * 2 },
		\freq, { |event| log.add(\freq); SwarmMath.freqRatio(event) },
		\amp, { |event| log.add(\amp); 1 / event.ratio },
		\phase, { log.add(\phase); 0.25 }
	]);
	calcPairs = state.calc(0);
	calcOrder = log.copy;
	log.clear;
	records = state.playbackSnapshot(preserveRandom: true);
	check.(log == calcOrder,
		"playbackSnapshot callback order differs from calc");
	check.(log.count({ |item| item == \ratio }) == 1,
		"playbackSnapshot evaluated ratio more than once per event");
	check.(records.size == 1 and: {
		records[0].keys.asSet == [
			\index, \freqIndex, \partial, \variation,
			\baseFrequency, \ratio, \values
		].asSet
	}, "playbackSnapshot record shape changed");
	check.(records[0][\index] == 0 and: { records[0][\freqIndex] == 0 }
		and: { records[0][\partial] == 0 }
		and: { records[0][\variation] == 0 }
		and: { records[0][\baseFrequency] == 100 }
		and: { records[0][\ratio] == 2 },
		"playbackSnapshot identity metadata changed");
	check.(records[0][\values] == calcPairs.asDict,
		"playbackSnapshot values differ from calc");
	check.(records[0][\values][\ratio].isNil,
		"ratio metadata leaked into playback control pairs");

	randomState = SwarmMath.new([90], 2, 2, [
		\ratio, { |event| event.p1 * rrand(1.0, 1.2) },
		\freq, { |event| SwarmMath.freqRatio(event) + rrand(0.01, 0.1) },
		\amp, { |event| (1 / event.ratio) * rrand(0.8, 1.0) },
		\phase, { rrand(-pi, pi) }, \pan, { rrand(-1.0, 1.0) }
	]);
	thisThread.randSeed = 90210;
	randomBefore = thisThread.randData.copy;
	preserved = randomState.playbackSnapshot(7712, true);
	check.(thisThread.randData == randomBefore,
		"preserveRandom playback snapshot changed thread randomness");
	check.(randomState.playbackSnapshot(7712, true) == preserved,
		"seeded preserved playback snapshot is not deterministic");

	thisThread.randSeed = 90210;
	randomBefore = thisThread.randData.copy;
	consumed = randomState.playbackSnapshot(7712, false);
	check.(consumed == preserved,
		"seeded consuming snapshot differs from preserved snapshot");
	check.(thisThread.randData != randomBefore,
		"default playbackSnapshot did not advance thread randomness");

	thisThread.randSeed = 4466;
	snapshotValues = randomState.playbackSnapshot.collect { |record| record[\values] };
	randomBefore = thisThread.randData.copy;
	thisThread.randSeed = 4466;
	playbackValues = Array.fill(randomState.size, { |index| randomState.calc(index).asDict });
	check.(snapshotValues == playbackValues,
		"unseeded playbackSnapshot values differ from sequential calc playback");
	check.(thisThread.randData == randomBefore,
		"playbackSnapshot consumed a different random sequence than calc");

	{
		var shared = [1, 2], captured;
		state = SwarmMath([100], 1, 1, [probe: { shared }]);
		captured = state.playbackSnapshot;
		shared[0] = 9;
		check.(captured[0][\values][\probe] == [1, 2],
			"Capture retained a mutable callback result container");
	}.value;

	state = SwarmMath.new([100], 1, 1, [
		\freq, { 1.0.rand; Error("snapshot callback probe").throw }
	]);
	thisThread.randSeed = 981;
	randomBefore = thisThread.randData.copy;
	checkThrows.({ state.playbackSnapshot(preserveRandom: true) },
		"playbackSnapshot callback error was swallowed");
	check.(thisThread.randData == randomBefore,
		"preserveRandom did not restore randomness after callback failure");
	checkThrows.({ state.playbackSnapshot(1.5) },
		"noninteger playbackSnapshot seed was accepted");

	"PASS: SwarmMath playback snapshot order, metadata, and random semantics".postln;
	0.exit;
} { |caught|
	caught.reportError;
	1.exit;
};
)
