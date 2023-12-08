(
SynthDef(\perc, {|out=0, freq=440, dur=1, detune=0, amp=1, pan=0, phase = 0|
	var env, sig;
	env = EnvGen.kr(Env.perc(0.001, dur, 1, \lin), 1, doneAction: 2);
	freq = freq + (detune * freq);
	sig = SinOsc.ar(freq, phase, amp);
	sig = Pan2.ar(sig, pan);
	Out.ar(out, sig * env);
}).add;

SynthDef(\laser, {|out=0, n=1, freq=440, f2mul=1.5, hpf=0, dur=1, amp=(-5.dbamp), pan=0, tilt=(-3), comb1=1, comb2=20, dout=0|
	var env, sig;
	freq = XLine.ar(freq, freq * f2mul, dur, doneAction: 2) * n * (1 + (n * n * 0.001)).sqrt;
	env = Env.asr(0.001, 1, 0.001).ar(2);
	sig = SinOsc.ar(freq);
	// 3db octave tilt
	sig = sig * (log2(n) * tilt).dbamp;
	// exponential comb filter
	sig = sig * ((1 - log2(n * Line.ar(comb1, comb2, dur, doneAction: 2)).sin.abs) ** 5);
	sig = Pan2.ar(sig, pan);
	sig = sig * amp;
	sig = sig.tanh;
	sig = HPF.ar(sig, hpf);
	sig = sig * env;
	// sig = MiVerb.ar(sig);
	Out.ar(out, sig);
}).add;

SynthDef(\laser_gated, {|out=0, n=1, freq=440, f2mul=1.5, dur=1, amp=(-5.dbamp), pan=0, tilt=(-3), comb1=1, comb2=20, gate=1|
	var env, sig;
	freq = XLine.ar(freq, freq * f2mul, dur) * n * (1 + (n * n * 0.001)).sqrt;
	env = Env.asr(0.001, 1, 0.001).ar(2, gate);
	sig = SinOsc.ar(freq);
	// 3db octave tilt
	sig = sig * (log2(n) * tilt).dbamp;
	// exponential comb filter
	sig = sig * ((1 - log2(n * Line.ar(comb1, comb2, dur)).sin.abs) ** 5);
	sig = Pan2.ar(sig, pan);
	sig = sig * amp;
	sig = sig.tanh;
	DetectSilence.ar(sig, doneAction:2);
	Out.ar(0, sig * env);
}).add;

SynthDef(\laser_fb, {|out=0, n=1, freq=440, f2mul=1.5, dur=1, amp=(-5.dbamp), pan=0, tilt=(-3), comb1=1, comb2=20|
	var env, sig;
	var dec = {arg dr, ml; Decay.ar(Impulse.ar(0),dr,ml)};
	freq = dec.(dur, freq) * n * (1 + (n * n * 0.001)).sqrt;
	env = Env.asr(0.001, dur+0.1, 0.001).ar(2);
	sig = SinOsc.ar(freq);
	sig = sig + SinOscFB.ar(
		freq+(sig*1000),Rand(0,2),dec.(dur*Rand(0.5,1), amp)
	);
	sig = sig * (log2(n) * tilt).dbamp;
	sig = sig * ((1 - log2(n * Line.ar(comb1, comb2, dur, doneAction: 2)).sin.abs) ** 5);
	sig = Pan2.ar(sig, pan);
	sig = sig * amp;
	sig = sig.tanh;
	DetectSilence.ar(sig, doneAction:2);
	Out.ar(0, sig * env);
}).add;
)
