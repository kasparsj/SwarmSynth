// "synths/*.scd".loadRelative;

(
var m = SwarmMath.new([62.cpsmidi], 120, 1, [
	n: { |e| 1 + e.p },
	freq: { |e| e.f },
	f2mul: 1.5,
	amp: { |e| 1.0/e.size },
	// detune: { |e| rrand(0.1, 0.3) },
	pan: { rrand(-1.0, 1.0) },
]);

if (~laser.isNil) { ~laser = SwarmSynth.new(\laser, [\fadeTime, 3]); };

Pdef(\laser, Pbind(
	\instrument, \laser,
	\octave, Prand([1,2,3,4,5], inf),
	\f2mul, Prand([1.5, 1/5], inf),
	\comb1, Prand([1, 10], inf),
	\comb2, Pfunc{ |e| if (e[\comb1] == 1, 20, 100) },
	\dur, Prand([0.1, 1, 2, 4]*2, inf),
	\delta, Pwhite(8, 16),
	// \delta, Pexprand(0.1, 8),
	\hpf, 330,
	\out, Pwrand([~delayBus.index, 0], [0.1,0.9].normalizeSum, inf),
	\swarm, Pfunc { |event|
		var freq;
		m.putEvent(event, 0);
		~laser.reset.set(m);
		event[\amp] = 0;
		event;
	},
)).play;
)

Pdef(\laser).stop;

// ~laser.closeGate
// ~laser.release
// ~laser.synths[0].isPlaying
