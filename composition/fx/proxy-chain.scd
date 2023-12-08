(
ProxyChain.add(*[
	\in12, \mix -> {
		SoundIn.ar([0, 1]);
	},
	\lpf, \filter -> { |in, freq = 200, mul = 4|
		LPF.ar(in, freq, mul);
	},
	\hpf, \filter -> { |in, freq = 80, mul = 4|
		HPF.ar(in, freq, mul);
	},
	\moogVcf, \filter -> { |in, freq = 200, gain = 1|
		MoogFF.ar(in, freq, gain);
	},
	\freqShift, \filter -> { |in, freq = -200|
		FreqShift.ar(in, freq);
	},
	\feedback, \filter -> { |in, maxdelaytime=4, delaytime=1|
		FbC({ |fb| FreqShift.ar(in + fb, 200).softclip * 0.8}, maxdelaytime, delaytime);
	},
	\delay, \filter -> { |in, maxdelaytime=0.25, delaytime=0.25|
		DelayN.ar(in, maxdelaytime, delaytime);
	},
	\comb, \filter -> { |in, maxdelaytime=0.1, delaytime=0.025, decaytime=2|
		CombN.ar(in, maxdelaytime, delaytime, decaytime);
	},
	\reverb, \filter -> { |in, preDelay=0.048, combDelay=0.1, combDecay=4, allpassDelay=0.050, allpassDecay=1|
		var z, y;
		// reverb predelay time :
		z = DelayN.ar(in, preDelay);
		// 7 length modulated comb delays in parallel :
		y = Mix.ar(Array.fill(7,{ CombL.ar(z, combDelay, LFNoise1.kr(combDelay.rand, 0.04, 0.05), combDecay) }));
		// two parallel chains of 4 allpass delays (8 total) :
		4.do({ y = AllpassN.ar(y, allpassDelay, [allpassDelay.rand, allpassDelay.rand], allpassDecay) });
		// add original sound to reverb and play it :
		y;
	},
	\gverb, \filter -> { |in, roomsize=50, revtime=3|
		GVerb.ar(in, roomsize, revtime);
	},
	\tanh, \filter -> { |in|
		in.tanh;
	},
    \limiter, \filter -> { |in, drive=1, ampLimit=1|
        Limiter.ar(in * drive, ampLimit);
    },
]);

)