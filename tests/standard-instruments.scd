(
var root = PathName(thisProcess.nowExecutingPath).pathOnly.dirname;
var check, approx, expectError, expected, heldNames, struckNames, variants;
var nan, beforeServerRunning, beforeSynthDesc, metadata, metadataAgain;
var instrument, fresh, state, snapshot, ratios, amplitudes, timing, naturalTiming;
var naturalAmplitudes;
var expectedRandom, actualRandom, originalFreqCallback, originalAmpCallback;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
approx = { |actual, wanted, tolerance=0.0001|
	(actual - wanted).abs <= tolerance;
};
expectError = { |action, fragment, message|
	var error = try { action.value; nil } { |caught| caught };
	check.(error.notNil and: {
		fragment.isNil or: { error.what.asString.toLower.contains(fragment.asString.toLower) }
	}, message);
};

expected = IdentityDictionary[
	\flute -> [1, 2, 3, 4, 5],
	\clarinet -> [1, 3, 5, 7, 9],
	\organ -> [1, 2, 3, 4, 5, 6, 7, 8],
	\marimba -> [1, 4, 10],
	\bell -> [0.5, 1, 1.2, 1.5, 2, 3]
];
heldNames = [\flute, \clarinet, \organ];
struckNames = [\marimba, \bell];
variants = [\natural, \soft, \bright];
nan = Float.from32Bits(16r7FC00000);

try {
	check.(SwarmInstruments.names == [\flute, \clarinet, \organ, \marimba, \bell],
		"standard instrument discovery order or names changed");
	expectError.({ SwarmInstruments.metadata(\missing) }, "missing",
		"unknown metadata name did not fail descriptively");
	expectError.({ SwarmInstruments.make(\missing) }, "missing",
		"unknown instrument name did not fail descriptively");
	expectError.({ SwarmInstruments.make(\flute, variant: \missing) }, "variant",
		"unknown variant did not fail descriptively");

	// Metadata is caller-owned, including nested collections.
	metadata = SwarmInstruments.metadata(\bell);
	check.(metadata[\register].notNil and: { metadata[\articulation].notNil },
		"metadata omitted register or articulation guidance");
	metadata[\label][0] = $X;
	metadata[\description][0] = $X;
	metadata[\register][0] = 99;
	metadata[\register] = \changedByCaller;
	metadataAgain = SwarmInstruments.metadata(\bell);
	check.(metadataAgain[\label] == "Bell" and: {
		metadataAgain[\description][0] == $G
	}, "metadata lookup leaked string mutations");
	check.(metadataAgain[\register] == [48, 84] and: {
		metadataAgain[\register] != \changedByCaller
	}, "metadata lookup leaked caller mutations");

	// Construction is inert and deterministic: no boot, SynthDef install, playback,
	// callback evaluation side effects, or random-stream advance.
	beforeServerRunning = Server.default.serverRunning;
	beforeSynthDesc = SynthDescLib.global.at(\swarm_partial);
	thisThread.randSeed = 4815;
	instrument = SwarmInstruments.make(\flute);
	actualRandom = 100000.rand;
	thisThread.randSeed = 4815;
	expectedRandom = 100000.rand;
	check.(actualRandom == expectedRandom, "construction advanced the random stream");
	check.(Server.default.serverRunning == beforeServerRunning,
		"construction changed the default server state");
	check.(SynthDescLib.global.at(\swarm_partial) === beforeSynthDesc,
		"construction installed or replaced the swarm_partial SynthDef");
	check.(instrument.synth.isNil, "construction eagerly created playback");
	check.(instrument.synthDef == \swarm_partial,
		"standard instruments do not reuse swarm_partial");
	instrument.dispose;

	expected.keysValuesDo { |name, wantedRatios|
		variants.do { |variant|
			instrument = SwarmInstruments.make(name, [220, 330], 0.2, variant);
			state = instrument.state;
			check.(instrument.variant == variant, "% did not select %".format(name, variant));
			check.(instrument.variantNames == variants.sort,
				"% did not expose the three standard variants".format(name));
			check.(state.partials == wantedRatios.size and: { state.variations == 1 },
				"% % dimensions changed".format(name, variant));
			ratios = state.get(\ratio, 0)[0];
			check.(ratios == wantedRatios,
				"% % ratios changed: %".format(name, variant, ratios));

			[0, 1].do { |freqIndex|
				amplitudes = state.get(\amp, freqIndex)[0];
				check.(amplitudes.every { |value|
					SwarmMath.prFiniteNumber(value) and: { value >= 0 }
				}, "% % generated invalid amplitudes".format(name, variant));
				check.(approx.(amplitudes.sum, 0.2),
					"% % amplitude budget was not normalized per base frequency: %"
					.format(name, variant, amplitudes.sum));
			};
			snapshot = state.snapshot([\freq, \amp, \phase, \pan, \attack, \decay,
				\sustain, \release]);
			check.(snapshot.every { |record|
				record[\values].values.every { |value| SwarmMath.prFiniteNumber(value) }
			}, "% % generated a non-finite callback value".format(name, variant));
			check.(snapshot.every { |record|
				record[\values][\phase] == 0 and: { record[\values][\pan] == 0 }
			}, "% % did not use deterministic phase and centered pan".format(name, variant));
			check.(state.args[\freq].isFunction and: { state.args[\amp].isFunction },
				"% % did not retain generated freq/amp callbacks".format(name, variant));
			instrument.dispose;
		};

		fresh = SwarmInstruments.make(name, #[440], 0.1, \natural);
		instrument = SwarmInstruments.make(name, #[440], 0.1, \natural);
		check.(fresh !== instrument and: { fresh.state !== instrument.state },
			"% make shared instrument or state identity".format(name));
		fresh.state.freqs[0] = 123;
		fresh.state.args[\attack] = 99;
		check.(instrument.state.freqs[0] == 440 and: {
			instrument.state.args[\attack] != 99
		}, "% fresh instances shared mutable state".format(name));
		fresh.dispose;

		state = instrument.state;
		originalFreqCallback = state.args[\freq];
		originalAmpCallback = state.args[\amp];
		state.putEvent((midinote: 69));
		check.(approx.(state.freqs[0], 440), "% midinote resolution failed".format(name));
		state.putEvent((degree: 0, octave: 5));
		check.(approx.(state.freqs[0], 261.625565, 0.001),
			"% degree resolution failed".format(name));
		state.putEvent((midinote: 69, transpose: 12));
		check.(approx.(state.freqs[0], 880), "% transpose resolution failed".format(name));
		check.(state.args[\freq] === originalFreqCallback and: {
			state.args[\amp] === originalAmpCallback
		}, "% pitch events replaced generated callbacks".format(name));
		state.putEvent((amp: 0.25));
		check.(approx.(state.get(\amp)[0].sum, 0.25),
			"% Event amp did not scale the normalized budget".format(name));
		check.(state.args[\amp] === originalAmpCallback,
			"% Event amp replaced its generated callback".format(name));
		state.putEvent((variations: 2));
		amplitudes = state.get(\amp);
		check.(amplitudes.every { |variation| approx.(variation.sum, 0.125) } and: {
			approx.(amplitudes.flatten.sum, 0.25)
		}, "% amplitude budget was not divided across variations".format(name));
		state.putEvent((variations: 1));

		// Finite spectrum tables never wrap. Added dimensions are silent; reduced
		// dimensions retain the leading table entries and remain calculable.
		state.putEvent((partials: wantedRatios.size + 2));
		amplitudes = state.get(\amp)[0];
		check.(amplitudes.copyRange(wantedRatios.size, wantedRatios.size + 1) == [0, 0],
			"% wrapped finite weights into added partials".format(name));
		check.(state.snapshot([\freq, \amp]).every { |record|
			SwarmMath.prFiniteNumber(record[\values][\freq]) and: {
				SwarmMath.prFiniteNumber(record[\values][\amp])
			}
		}, "% added partials produced invalid callback values".format(name));
		state.putEvent((partials: (wantedRatios.size - 1).max(1)));
		check.(state.get(\ratio)[0] == wantedRatios.copyRange(0,
			(wantedRatios.size - 2).max(0)), "% reduced partial table became unsafe".format(name));
		instrument.dispose;
	};

	// Held voices retain a sustain stage and permit live spectral changes.
	heldNames.do { |name|
		instrument = SwarmInstruments.make(name);
		check.(instrument.hasGate and: { instrument.liveSwitch == \sustained },
			"% was not configured as a held instrument".format(name));
		check.(instrument.state.get(\sustain)[0].every { |value| value > 0 },
			"% did not retain a positive sustain level".format(name));
		instrument.dispose;
	};
	// Struck voices leave tails for the next trigger and have no sustain plateau.
	struckNames.do { |name|
		instrument = SwarmInstruments.make(name);
		check.(instrument.hasGate.not and: { instrument.liveSwitch == \nextTrigger },
			"% was not configured as a retriggered struck instrument".format(name));
		check.(instrument.state.get(\sustain)[0].every { |value| value == 0 },
			"% unexpectedly retained a sustain plateau".format(name));
		instrument.dispose;
	};

	// Variants change spectral weights and envelope timing while preserving ratios.
	expected.keys.do { |name|
		naturalTiming = nil;
		naturalAmplitudes = nil;
		variants.do { |variant|
			instrument = SwarmInstruments.make(name, variant: variant);
			timing = [instrument.state.get(\attack)[0], instrument.state.get(\decay)[0],
				instrument.state.get(\release)[0]];
			if (variant == \natural) {
				naturalTiming = timing;
				naturalAmplitudes = instrument.state.get(\amp)[0];
			} {
				check.(timing != naturalTiming,
					"% % did not change envelope timing".format(name, variant));
				check.(instrument.state.get(\amp)[0] != naturalAmplitudes,
					"% % did not change spectral weights".format(name, variant));
			};
			instrument.dispose;
		};
	};
	instrument = SwarmInstruments.make(\marimba);
	timing = instrument.state.get(\decay)[0];
	check.(timing[2] < timing[1] and: { timing[1] < timing[0] },
		"marimba upper modes did not decay progressively faster");
	instrument.dispose;
	instrument = SwarmInstruments.make(\bell);
	timing = instrument.state.get(\decay)[0];
	check.(timing.as(Set).size > 1, "bell modes did not have distinct decay times");
	instrument.dispose;

	[-1, inf, nan].do { |invalid|
		expectError.({ SwarmInstruments.make(\flute, amp: invalid) }, "amp",
			"invalid amp % did not fail descriptively".format(invalid));
	};

	["standard-instruments.scd", "standard-instruments-audition.scd"].do { |file|
		check.(thisProcess.interpreter.compileFile(root +/+ "examples" +/+ file).isKindOf(Function),
			"Example failed to compile: " ++ file);
	};
	check.(SCDoc.parseFileFull(root +/+ "HelpSource/Classes/SwarmInstruments.schelp").notNil,
		"SwarmInstruments help failed to parse");
	"PASS: SwarmInstruments contracts".postln;
	0.exit;
} { |error|
	error.reportError;
	"FAIL: SwarmInstruments contracts: %".format(error).postln;
	1.exit;
};
)
