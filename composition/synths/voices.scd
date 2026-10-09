(
SynthDef(\voice_bass, { arg
	freq = 220,
	amp = 0.5,
	vibratoSpeed = 6,
	vibratoDepth = 4,
	vowel = 0,
	att = 0.01,
	rel = 0.1,
	lag = 1,
	gate = 1,
	pan=0;

	var in, vibrato, env, vowels, snd;

	vibrato = SinOsc.kr(vibratoSpeed, mul: vibratoDepth);
	in = SinOsc.ar(Lag.kr(freq, lag) + vibrato);
	// in = Saw.ar(Lag.kr(freq, lag) + vibrato);
	env = EnvGen.kr(Env.asr(att, 1, rel), gate, doneAction: 2);

	vowels = [\a, \e, \i, \o, \u].collect{ |v|
		var vowel = Vowel(v, \bass);
		BBandPass.ar(
			in: in,
			freq: vowel.freqs,
			bw: vowel.widths / vowel.freqs,
			mul: vowel.amps
		);
	};

	// snd = Select.ar(Lag.kr(vowel, lag), vowels);
	snd = SelectX.ar(Lag.kr(vowel, lag), vowels);
	snd = Mix.new(snd);
	snd = Pan2.ar(snd, pan, amp);
	snd = MiVerb.ar(snd);
	Out.ar(0, snd * env);
}).add;

SynthDef(\voice_tenor, { |out=0, freq = 220, hpf=0, vibratoSpeed = 6, vibratoDepth = 4, vowel = 0, att = 0.01, rel = 0.1, lag = 1, gate = 1, pan=0, amp=0|

	var in, vibrato, env, vowels, snd;

	vibrato = SinOsc.kr(vibratoSpeed, mul: vibratoDepth);
	in = SinOsc.ar(Lag.kr(freq, lag) + vibrato);
	// in = Saw.ar(Lag.kr(freq, lag) + vibrato);
	env = EnvGen.kr(Env.asr(att, 1, rel), gate, doneAction: 2);

	vowels = [\a, \e, \i, \o, \u].collect{ |v|
		var vowel = Vowel(v, \tenor);
		BBandPass.ar(
			in: in,
			freq: vowel.freqs,
			bw: vowel.widths / vowel.freqs,
			mul: vowel.amps
		);
	};

	// snd = Select.ar(Lag.kr(vowel, lag), vowels);
	snd = SelectX.ar(Lag.kr(vowel, lag), vowels);
	snd = Mix.new(snd);
	snd = HPF.ar(snd, hpf);
	snd = Pan2.ar(snd, pan);
	snd = snd * env;
	Out.ar(out, snd * amp);
}).add;

SynthDef(\voice_alto, { arg
	freq = 220,
	amp = 0.5,
	vibratoSpeed = 6,
	vibratoDepth = 4,
	vowel = 0,
	att = 0.01,
	rel = 0.1,
	lag = 1,
	gate = 1,
	pan=0;

	var in, vibrato, env, vowels, snd;

	vibrato = SinOsc.kr(vibratoSpeed, mul: vibratoDepth);
	in = SinOsc.ar(Lag.kr(freq, lag) + vibrato);
	// in = Saw.ar(Lag.kr(freq, lag) + vibrato);
	env = EnvGen.kr(Env.asr(att, 1, rel), gate, doneAction: 2);

	vowels = [\a, \e, \i, \o, \u].collect{ |v|
		var vowel = Vowel(v, \alto);
		BBandPass.ar(
			in: in,
			freq: vowel.freqs,
			bw: vowel.widths / vowel.freqs,
			mul: vowel.amps
		);
	};

	// snd = Select.ar(Lag.kr(vowel, lag), vowels);
	snd = SelectX.ar(Lag.kr(vowel, lag), vowels);
	snd = Mix.new(snd);
	snd = Pan2.ar(snd, pan, amp);
	snd = MiVerb.ar(snd);
	Out.ar(0, snd * env);
}).add;

SynthDef(\voice_soprano, { arg
	freq = 220,
	amp = 0.5,
	vibratoSpeed = 6,
	vibratoDepth = 4,
	vowel = 0,
	att = 0.01,
	rel = 0.1,
	lag = 1,
	gate = 1,
	pan=0;

	var in, vibrato, env, vowels, snd;

	vibrato = SinOsc.kr(vibratoSpeed, mul: vibratoDepth);
	in = SinOsc.ar(Lag.kr(freq, lag) + vibrato);
	// in = Saw.ar(Lag.kr(freq, lag) + vibrato);
	env = EnvGen.kr(Env.asr(att, 1, rel), gate, doneAction: 2);

	vowels = [\a, \e, \i, \o, \u].collect{ |v|
		var vowel = Vowel(v, \soprano);
		BBandPass.ar(
			in: in,
			freq: vowel.freqs,
			bw: vowel.widths / vowel.freqs,
			mul: vowel.amps
		);
	};

	// snd = Select.ar(Lag.kr(vowel, lag), vowels);
	snd = SelectX.ar(Lag.kr(vowel, lag), vowels);
	snd = Mix.new(snd);
	snd = Pan2.ar(snd, pan, amp);
	snd = MiVerb.ar(snd);
	Out.ar(0, snd * env);
}).add;
)