(
SynthDef(\perc, {|out=0, freq=440, detune=0, gate=1, amp=1, pan=0, phase = 0|
	var env, sig;
	env = EnvGen.kr(Env.perc(0.001, 0.3, 1, \lin), gate, doneAction: 2);
	freq = freq + (detune * freq);
	sig = SinOsc.ar(freq, phase, amp);
	sig = Pan2.ar(sig, pan);
	Out.ar(0, sig * env);
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

SynthDef(\kick1, { |freq=50, pan=0, amp=1, out=0|
    var snd;
    snd = DC.ar(0);
    snd = snd + (SinOsc.ar(XLine.ar(800, 400, 0.01)) * Env.perc(0.0005, 0.01).ar);
    snd = snd + (BPF.ar(Hasher.ar(Sweep.ar), XLine.ar(800, 100, 0.01), 0.6) * Env.perc(0.001, 0.02).delay(0.001).ar);
    snd = snd + (SinOsc.ar(XLine.ar(freq*3, freq, 0.01)) * Env.perc(0.0001, 0.3, 1, \lin).delay(0.005).ar(2));
    snd = snd.tanh;
    Out.ar(out, Pan2.ar(snd, pan, amp));
}).add;


)
