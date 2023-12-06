(
Pdef(\laser_random, Pbind(
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
		~laserState.putEvent(event, 0);
		~laserSynth.reset.set(~laserState);
		event[\amp] = 0;
		event;
	},
));

// Pdef(\laser_random).stop;

Pdef(\voice_tenor_random, Pbind(
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
		~tenorState.putEvent(event, 0);
		~tenorSynth.set(~tenorState);
		event[\amp] = 0;
		event;
	},
));

// Pdef(\voice_tenor_random).stop;
)