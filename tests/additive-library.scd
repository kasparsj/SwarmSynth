// Run with python3 tests/run-additive-library.py. No audio server is started.
(
var check, checkNear, checkThrows, state, update, before, actual, recipe;
var ratioCalls, snapshot, randomSnapshot, report, policy, pitchParent;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
checkNear = { |actual, expected, message, tolerance = 0.000001|
	check.((actual - expected).abs <= tolerance,
		message ++ " (expected %, got %)".format(expected, actual));
};
checkThrows = { |action, message|
	var caught = try { action.value; nil } { |caughtError| caughtError };
	check.(caught.notNil, message);
};

try {
	state = SwarmMath.new([440], 2, 1, [
		\freq, { |e| e.freq * e.p1 },
		\amp, { 1 }
	]);
	update = (note: 0, octave: 5, transpose: 12);
	state.putEvent(update, 0);
	checkNear.(state.freqs[0], 523.2511306012,
		"Event pitch resolution ignored note/octave/transpose");
	check.(update[\note] == 0 and: { update[\transpose] == 12 },
		"literal Event pitch keys were consumed");

	state.putEvent((midinote: 69), 0);
	checkNear.(state.freqs[0], 440, "midinote did not resolve through Event pitch");
	state.putEvent((degree: 0, scale: Scale.major, root: 0, octave: 5), 0);
	checkNear.(state.freqs[0], 261.6255653006,
		"degree/scale/root/octave did not resolve through Event pitch");

	state.putEvent((freq: 330, note: 11, transpose: 24), 0);
	checkNear.(state.freqs[0], 330, "explicit freq did not override musical pitch fields");
	state.putEvent((freq: { 345 }), 0);
	checkNear.(state.freqs[0], 345, "callable explicit freq was not resolved in Event context");
	pitchParent = Event.default.copy.put(\octave, 6);
	update = Event.new(8, nil, pitchParent, true).put(\note, 0);
	state.putEvent(update, 0);
	checkNear.(state.freqs[0], 523.2511306012, "literal Event custom pitch parent was lost");
	before = state.freqs.copy;
	state.putEvent(IdentityDictionary.newFrom([\pan, 0.25]));
	check.(state.freqs == before, "timbre-only dictionary reset pitch");
	before = [state.freqs.copy, state.partials, state.variations];
	checkThrows.({ state.putEvent((freq: -1, partials: 9), 0) },
		"invalid resolved frequency was accepted");
	check.([state.freqs, state.partials, state.variations] == before,
		"invalid pitch update partially mutated state");

	check.(SwarmMath.ratios(\harmonic, 5) == [1, 2, 3, 4, 5],
		"harmonic ratios changed");
	check.(SwarmMath.ratios(\odd, 4) == [1, 3, 5, 7], "odd ratios changed");
	check.(SwarmMath.ratios(\even, 4) == [2, 4, 6, 8], "even ratios changed");
	check.(SwarmMath.ratios(\power, 3, (exponent: 2)) == [1, 4, 9],
		"power ratios changed");
	check.(SwarmMath.ratios(\geometric, 4, (ratio: 1.5)) == [1, 1.5, 2.25, 3.375],
		"geometric ratios changed");
	actual = SwarmMath.ratios(\equalTemperament, 3, (divisions: 12));
	checkNear.(actual[1], 2 ** (1/12), "equal-temperament ratios changed");
	check.(SwarmMath.ratios(\subharmonic, 4) == [1, 0.5, 1/3, 0.25],
		"subharmonic ratios changed");
	check.(SwarmMath.ratios(\fibonacci, 6) == [1, 2, 3, 5, 8, 13],
		"Fibonacci ratios changed");
	check.(SwarmMath.ratios(\prime, 6) == [1, 2, 3, 5, 7, 11],
		"prime ratios changed");
	check.(SwarmMath.ratios(\stiffString, 3, (B: 0)) == [1, 2, 3],
		"zero-B stiff-string ratios are not harmonic");
	check.(SwarmMath.ratios(\custom, 3, (values: [1, 1.41, 2.05, 2.9]))
		== [1, 1.41, 2.05], "custom ratios changed");
	check.(SwarmMath.ratios(\harmonic, 0).isEmpty, "zero-count ratios are not empty");
	checkThrows.({ SwarmMath.ratios(\unknown, 0) },
		"unknown ratio family was accepted for zero count");
	checkThrows.({ SwarmMath.ratios(\custom, 3, (values: [1, 2])) },
		"short custom ratio array was accepted");
	checkThrows.({ SwarmMath.ratios(\geometric, 2, (ratio: 0)) },
		"nonpositive ratio was accepted");
	checkThrows.({ SwarmMath.ratios(\geometric, 1, (ratio: 0)) },
		"masked zero geometric ratio was accepted for count one");
	checkThrows.({ SwarmMath.ratios(\geometric, 1, (ratio: -1)) },
		"masked negative geometric ratio was accepted for count one");
	checkThrows.({ SwarmMath.ratios(\geometric, 0, (ratio: inf)) },
		"invalid geometric ratio was accepted for zero count");
	checkThrows.({ SwarmMath.ratios(\power, 0, (exponent: inf)) },
		"invalid power exponent was accepted for zero count");
	checkThrows.({ SwarmMath.ratios(\power, 1, (offset: -1)) },
		"nonpositive power index plus offset was accepted");
	check.(SwarmMath.ratios(\custom, 0).isEmpty,
		"zero-count custom ratios required an unnecessary values array");
	checkThrows.({ SwarmMath.ratios(\custom, 0, (values: [0])) },
		"invalid supplied custom ratio was accepted for zero count");

	recipe = SwarmMath.waveformRecipe(\square, 3);
	check.(recipe[\ratios] == [1, 3, 5], "square recipe ratios changed");
	checkNear.(recipe[\amplitudes][1], 1/3, "square second partial is not weighted 1/3");
	recipe = SwarmMath.waveformRecipe(\triangle, 3);
	checkNear.(recipe[\amplitudes][1], 1/9, "triangle second partial is not weighted 1/9");
	check.(recipe[\phases] == [0.0, pi, 0.0], "triangle alternating phase changed");

	ratioCalls = 0;
	state = SwarmMath.new([100], 2, 1, [
		\ratio, { |e| ratioCalls = ratioCalls + 1; e.p1 * 2 },
		\freq, { |e| SwarmMath.freqRatio(e) },
		\amp, { |e| SwarmMath.ampPower(e, 2, \ratio) },
		\decay, { |e| SwarmMath.partialDecay(e, 4, 1, 0.1) }
	]);
	actual = state.calc(0).asDict;
	check.(ratioCalls == 1, "ratio callback was evaluated more than once per generated event");
	check.(actual[\ratio].isNil, "ratio metadata leaked into Synth control pairs");
	checkNear.(actual[\freq], 200, "freqRatio ignored resolved ratio");
	checkNear.(actual[\amp], 0.25, "ampPower ratio basis changed");
	checkNear.(actual[\decay], 2, "partialDecay changed");
	ratioCalls = 0;
	check.(state.val(0, \ratio) == 2 and: { ratioCalls == 1 },
		"val re-evaluated the ratio callback");
	ratioCalls = 0;
	check.(state.get(\ratio) == [[2, 4]] and: { ratioCalls == 2 },
		"get did not evaluate ratio exactly once per generated event");
	snapshot = state.snapshot([\freq, \amp, \decay]);
	check.(snapshot[0][\baseFrequency] == 100 and: { snapshot[0][\ratio] == 2 },
		"snapshot omitted baseFrequency/ratio metadata");
	checkNear.(SwarmMath.ampPower((p1: 4, ratio: 9), 2, \index), 1/16,
		"ampPower index basis changed");
	checkNear.(SwarmMath.ampGaussian((p1: 3, ratio: 7), 3, 2, \index), 1,
		"Gaussian amplitude center changed");
	checkNear.(SwarmMath.ampExponential((p1: 3, ratio: 7), 0.5, \index), exp(-1),
		"exponential amplitude changed");
	checkThrows.({ SwarmMath.ampPower((p1: 1, ratio: 1), inf) },
		"nonfinite amplitude exponent was accepted");
	checkThrows.({ SwarmMath.ampGaussian((p1: 1, ratio: 1), inf, 1) },
		"nonfinite Gaussian center was accepted");
	checkThrows.({ SwarmMath.ampGaussian((p1: 1, ratio: 1), 0, 0) },
		"nonpositive Gaussian width was accepted");
	checkThrows.({ SwarmMath.ampExponential((p1: 1, ratio: 1), 0.0 / 0.0) },
		"nonfinite exponential rate was accepted");
	checkThrows.({ SwarmMath.partialDecay((ratio: 1), -1) },
		"negative decay base was accepted");
	checkThrows.({ SwarmMath.partialDecay((ratio: 1), 1, inf) },
		"nonfinite decay exponent was accepted");
	checkThrows.({ SwarmMath.partialDecay((ratio: 1), 1, 1, -1) },
		"negative decay minimum was accepted");
	checkNear.(SwarmMath.ampPower((p1: 2, ratio: 2), -1), 2,
		"negative finite amplitude exponent was rejected or changed");
	checkNear.(SwarmMath.ampExponential((p1: 2, ratio: 2), -1), exp(1),
		"negative finite exponential rate was rejected or changed");
	state = SwarmMath.new([100], 1, 1, [
		\ratio, { -1 }, \freq, { |e| SwarmMath.freqRatio(e) }
	]);
	checkThrows.({ state.val(0, \freq) }, "invalid resolved ratio callback was accepted");

	ratioCalls = 0;
	state = SwarmMath.new([100], 3, 1, [
		\ratio, { ratioCalls = ratioCalls + 1; exprand(1.0, 5.0) },
		\freq, { |e| SwarmMath.freqRatio(e) },
		\amp, { |e| 1 / e.ratio }
	]);
	randomSnapshot = state.snapshot([\freq, \amp], 8128);
	check.(ratioCalls == 3, "random snapshot ratio callback was re-evaluated");
	randomSnapshot.do { |record|
		checkNear.(record[\values][\freq] / record[\baseFrequency], record[\ratio],
			"random snapshot frequency lost its captured ratio");
		checkNear.(record[\values][\amp], 1 / record[\ratio],
			"random snapshot amplitude did not share its captured ratio");
	};

	check.(SwarmMath.normalizeWeights([], \energy).isEmpty,
		"empty weights changed during normalization");
	check.(SwarmMath.normalizeWeights([0, 0], \peak) == [0, 0],
		"zero weights changed during normalization");
	actual = SwarmMath.normalizeWeights([-1, 2, -1], \peakBound);
	check.(actual == [-0.25, 0.5, -0.25], "peak normalization changed signs or scale");
	actual = SwarmMath.normalizeWeights([3, 4], \energy);
	check.(actual == [0.6, 0.8], "energy normalization changed");
	check.(SwarmMath.normalizeWeights([-1, 2], \none) == [-1, 2],
		"none normalization changed weights");

	policy = SwarmMath.frequencyPolicy(30000, 44100, \fold);
	check.(policy == [14100, 1], "44.1 kHz fold policy changed");
	check.(SwarmMath.frequencyPolicy(30000, 48000, 1) == [18000, 1],
		"numeric fold policy changed");
	check.(SwarmMath.frequencyPolicy(24000, 48000, \mute) == [24000, 0],
		"mute policy did not suppress Nyquist");
	check.(SwarmMath.frequencyPolicy(21600, 48000, \taper) == [21600, 1],
		"taper did not retain 90%-Nyquist boundary");
	checkNear.(SwarmMath.frequencyPolicy(22800, 48000, \taper)[1], 0.5,
		"taper midpoint changed");
	check.(SwarmMath.frequencyPolicy(24000, 48000, \taper) == [24000, 0],
		"taper did not reach zero at Nyquist");
	check.(SwarmMath.frequencyPolicy(19845, 44100, \mute) == [19845, 1],
		"44.1 kHz mute changed below Nyquist");
	check.(SwarmMath.frequencyPolicy(22050, 44100, \mute) == [22050, 0],
		"44.1 kHz mute did not suppress Nyquist");
	check.(SwarmMath.frequencyPolicy(19845, 44100, \taper) == [19845, 1],
		"44.1 kHz taper did not retain 90%-Nyquist boundary");
	checkNear.(SwarmMath.frequencyPolicy(20947.5, 44100, \taper)[1], 0.5,
		"44.1 kHz taper midpoint changed");
	check.(SwarmMath.frequencyPolicy(22050, 44100, \taper) == [22050, 0],
		"44.1 kHz taper did not reach zero at Nyquist");
	SynthDef(\swarmmathPolicyKr, {
		var pair = SwarmMath.frequencyPolicy(30000, SampleRate.ir, \mode.kr(0));
		ReplaceOut.kr(0, pair[0] * pair[1]);
	});
	SynthDef(\swarmmathPolicyAr, {
		var pair = SwarmMath.frequencyPolicy(SinOsc.ar(1, 0, 30000),
			SampleRate.ir, \mode.kr(0));
		ReplaceOut.ar(0, pair[0] * pair[1]);
	});

	report = state.spectrumReport(snapshot, 48000, \none);
	state.args[\freq] = { Error("spectrumReport re-evaluated callback").throw };
	report = state.spectrumReport(snapshot, 48000, \none);
	check.(report[0][\label] == "generated-input estimate"
		and: { report[0][\baseFrequency] == 100 }
		and: { report[0][\ratio] == 2 }
		and: { report[0][\frequency] == 200 }
		and: { report[0][\effectiveFrequency] == 200 },
		"spectrum report metadata changed");

	"PASS: SwarmMath additive library".postln;
	0.exit;
} { |caught|
	caught.reportError;
	1.exit;
};
)
