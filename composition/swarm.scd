(
~droneState = SwarmMath.new([~rootHz], 12, 7, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	amp: { |e| 1.0/e.size * e.vol },
	modf: 1/11,
	lmod: 0.3,
	// amp: { |e| SwarmMath.ampPartialRec(e) },
	// amp: { |e| SwarmMath.ampPartialRecMod(e, 2, 0, 1) },
	// detune: 0.1,
	phase: { rrand(-2pi, 2pi) },
	pan: { rrand(-1.0, 1.0) },
], 0.1);

~droneSynth = SwarmSynth.new(\drone_modsin, [\fadeTime, 10]);

~laserState = SwarmMath.new([(~rootHz*2)], 120, 1, [
	n: { |e| 1 + e.p },
	freq: { |e| e.f },
	f2mul: 1.5,
	amp: { |e| 1.0/e.size * e.vol },
	// detune: { |e| rrand(0.1, 0.3) },
	pan: { rrand(-1.0, 1.0) },
], 1);

~laserSynth = SwarmSynth.new(\laser, [\fadeTime, 3]);

~tenorState = SwarmMath.new([(~rootHz*3)], 50, 1, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	amp: { |e| SwarmMath.ampPartialRec(e, 1, 1.5) * e.vol },
	// detune: { |e| rrand(0.1, 0.3) },
	phase: { rrand(-2pi, 2pi) },
	pan: { rrand(-1.0, 1.0) },
], 0.1);

~tenorSynth = SwarmSynth.new(\voice_tenor, [\fadeTime, 3]);
)

// ~droneState.freqs