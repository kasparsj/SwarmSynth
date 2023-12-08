(
~droneState = SwarmMath.new([~rootHz], 102, 2, [
	// freq: { |e| SwarmMath.freqPartial(e, rrand(0.5, 3.0), 1) + e.v },
	freq: { |e| SwarmMath.freqPartial(e, rrand(0.3, 3.0), (e.p/e.size).cos.abs) + e.v },
	// freq: { |e| SwarmMath.freqPartial(e, 0.5, 5) + (e.v / 5) },
	// freq: { |e| e.freq = if (e.p%2==0, e.freq**2, e.freq/2); SwarmMath.freqPartial(e, 1, 1) + e.v },
	// amp: { |e| SwarmMath.ampPartialRec(e, 0, 2) * e.vol },
	amp: { |e| SwarmMath.ampPartialRec(e, 0, 1) * (e.p/e.size).sin.abs * e.vol },
	// amp: { |e| SwarmMath.ampPartialRecMod(e, 2, 0, 1) * e.vol * (1.0 / e.size) },
	// amp: { |e| 1.0 / e.size * e.vol },
	// amp: { |e| (1.0 / e.size) * rrand(0.01, 0.1) },
	mod: 0.1,
	modf: 1/22,
	detune: 0,
	// detune: 0.02,
	// detune: { |e| rrand(0.01, 0.3) },
	detunef: 0,
	pulse: 0,
	// pulse: { |e| if (e.p%2==0, 1, 0); },
	// pulse: { |e| if (e.p > 100, 1, 0); },
	pulsef: 0.1,
	phase: 0,
	// phase: { rrand(-2pi, 2pi) },
	phasef: 0,
	pan: { rrand(-1.0, 1.0) },
	panf: 0,
], 0.1);

if (~droneSynth.isNil) {
	~droneSynth = SwarmSynth.new(\drone, [\fadeTime, 20]);
} {
	if (~droneSynth.isPlaying) {
		~droneSynth.set(~droneState, defer: 0.005);
		// ~droneSynth.xset(~droneState, fadeTime: 5);
	}
};

// ~droneSynth.release
// ~droneSynth.closeGate

~laserState = SwarmMath.new([(~rootHz*2)], 100, 1, [
	n: { |e| 1 + e.p },
	freq: { |e| e.f },
	f2mul: 1.5,
	// f2mul: { |e| e.p.sin },
	// amp: { |e| 1.0 / e.size * e.vol },
	amp: { |e| 1.0 / e.size * e.vol * rrand(0.5, 1.0) },
	detune: { |e| rrand(0.1, 0.3) },
	pan: { rrand(-1.0, 1.0) },
], 1);

if (~laserSynth.isNil) {
	~laserSynth = SwarmSynth.new(\laser, [\fadeTime, 3]);
} {
	if (~laserSynth.isPlaying) {
		//~laserSynth.set(~laserState);
	};
};

// ~laserSynth.release
// ~laserSynth.closeGate

~tenorState = SwarmMath.new([~rootHz], 100, 1, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	amp: { |e| SwarmMath.ampPartialRec(e, 1, 2) * e.vol },
	detune: 0,
	// detune: { |e| exprand(0.01, 0.1) },
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

// ~tenorSynth.release
// ~tenorSynth.closeGate