(
Pdef(\laser_random, Pbind(
	\octave, Prand([1, 2, 4], inf),
	// \f2mul, Prand([1.5, 1/5], inf),
	\f2mul, Pwhite(2, 0.2),
	// \comb1, Prand([1, 10], inf),
	\comb1, Pwhite(1, 10),
	// \comb2, Pfunc{ |e| if (e[\comb1] == 1, 20, 100) },
	\comb2, Pwhite(10, 100),
	\dur, Prand([0.1, 1, 2, 4, 16], inf),
	// \dur, Pseq([1, 1, 0.5, 0.5], inf),
	// \instrument, \perc,
	\instrument, Prand([\perc, \laser], inf),
	// \instrument, Pfunc{|e| if (e[\dur] < 1, \laser_fb, \laser) },
	\delta, Prand([1, 8, 16], inf)/2,
	// \delta, Pexprand(0.1, 8),
	\hpf, 0,
	// \out, 0,
	\out, Pwrand([~delayBus.index, ~miverbBus.index, 0], [0.1, 0.5, 0.9].normalizeSum, inf),
	// \out, Pwrand([~delayBus.index, ~miverbBus.index, 0], [0.1, 0.2, 0.9].normalizeSum, inf),
	\swarm, Pfunc { |event|
		~laserState.putEvent(event, 0);
		~laserState.freqs[0].postln;
		~laserSynth.reset.set(~laserState);
		event[\amp] = 0;
		event;
	},
));

// Pdef(\laser_random).play;
// Pdef(\laser_random).stop;

Pdef(\voice_tenor_random, Pbind(
	\instrument, \voice_tenor,
	// \note, Pseq([5, 7, 9, 11], inf),
	\note, Prand([0, 5, 7, 9, 11], inf),
	// \ctranspose, (~root-60+24-7),
	// \ctranspose, Pwrand([-14, -21], [0.8, 0.2].normalizeSum, inf),
	\ctranspose, -14,
	\dur, Pwhite(3, 8.5),
	\delta, Prand((1..10), inf),
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
		~tenorState.putEvent(event, 0);
		~tenorSynth.set(~tenorState);
		event[\amp] = 0;
		event;
	},
));

// Pdef(\voice_tenor_random).play
// Pdef(\voice_tenor_random).stop;
)