// "synths/*.scd".loadRelative;
(
var m = SwarmMath.new([31.midicps*3], 50, 1, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	amp: { |e| SwarmMath.ampPartialRec(e, 1, 1.5)*0.1 },
	// detune: { |e| rrand(0.1, 0.3) },
	phase: { rrand(-2pi, 2pi) },
	pan: { rrand(-1.0, 1.0) },
]);

if (~tenor.isNil) { ~tenor = SwarmSynth.new(\voice_tenor, [\fadeTime, 3]); };

Pdef(\voice_tenor, Pbind(
	\instrument, \voice_tenor,
	// \note, Pseq([5, 7, 9, 11], inf),
	\note, Prand([5, 7, 9, 11], inf),
	// \ctranspose, Pwrand([-14, -21], [0.8, 0.2].normalizeSum, inf),
	\ctranspose, -12,
	\dur, Pwhite(3, 8.5),
	\delta, Pwhite(1, 10),
	\vibratoSpeed, Pwhite(1, 6),
	\vibratoDepth, Pwhite(1, 4),
	// \vowel, Pseq([2, 3, 4], inf),
	\vowel, Pwrand([1, 2, 3], [0.5, 0.4, 0.1].normalizeSum, inf),
	\lag, 0.5,
	\hpf, 330,
	// \out, 0,
	\out, ~miverbBus.index,
	// \out, ~reverbBus.index,
	\swarm, Pfunc { |event|
		m.putEvent(event, 0);
		~tenor.set(m);
		event[\amp] = 0;
		event;
	},
)).play;
)

// Pdef(\voice_tenor).stop
// ~tenor.closeGate