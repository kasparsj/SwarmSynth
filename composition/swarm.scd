(
~droneState = SwarmMath.new([~rootHz*1], 60, 2, [
	// freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + exprand(0.1, 3.0) },
	amp: { |e| SwarmMath.ampPartialRec(e, 0, 2) * e.vol },
	// amp: { |e| SwarmMath.ampPartialRecMod(e, 2, 0, 1) * e.vol },
	// amp: { |e| 1.0 / e.size * e.vol },
	mod: 0,
	modf: 1/22,
	detune: 0.02,
	detunef: 0.1,
	pulse: 0,
	saw: 0,
	// phase: 0,
	phase: { rrand(-2pi, 2pi) },
	phasef: 0,
	pan: { rrand(-1.0, 1.0) },
	panf: 0,
], 0.1);

if (~droneSynth.isNil) {
	~droneSynth = SwarmSynth.new(\drone, [\fadeTime, 20]);
} {
	if (~droneSynth.isPlaying) {
		~droneSynth.rampTo(~droneState, 0.3);
	}
};

// ~droneSynth.release
// ~droneSynth.closeGate

~laserState = SwarmMath.new([(~rootHz*2)], 120, 1, [
	n: { |e| 1 + e.p },
	freq: { |e| e.f },
	f2mul: 1.5,
	amp: { |e| 1.0 / e.size * e.vol },
	// detune: { |e| rrand(0.1, 0.3) },
	pan: { rrand(-1.0, 1.0) },
], 1);

if (~laserSynth.isNil) {
	~laserSynth = SwarmSynth.new(\laser, [\fadeTime, 3]);
} {
	if (~laserSynth.isPlaying) {
		~laserSynth.set(~laserState);
	};
};

~tenorState = SwarmMath.new([(~rootHz*3)], 50, 1, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	amp: { |e| SwarmMath.ampPartialRec(e, 1, 1.5) * e.vol },
	// detune: { |e| rrand(0.1, 0.3) },
	phase: { rrand(-2pi, 2pi) },
	pan: { rrand(-1.0, 1.0) },
], 0.1);

if (~tenorSynth.isNil) {
	~tenorSynth = SwarmSynth.new(\voice_tenor, [\fadeTime, 3]);
} {
	if (~tenorSynth.isPlaying) {
		~tenorSynth.set(~tenorState);
	};
};
)

// ~droneState.freqs