(
SynthDef(\drone, {|out=0, freq=440, detune=0, lfo=0.1, fadeTime=1, gate=1, amp=1, pan=0, phase = 0|
	var amp2 = amp, detune2 = detune, freq2 = freq, sig, hpq, lpq, lfo2 = lfo, env;
	env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
	// lfo2 = LFNoise1.kr(lfo2);
	// lfo2 = LFNoise0.kr(lfo2, 1.0);
	// amp2 = LFNoise1.kr(lfo2, amp2);
	// amp2 = LFPulse.kr(lfo2, Rand(), 0.5, amp2);
	// amp2 = LFPulse.kr(lfo2, 1 / harmonics * j, 0.5, amp2);
	// amp2 = LFTri.kr(lfo2, Rand(0, 4.0), amp2);
	// amp2 = LFSaw.kr(lfo2, Rand(0, 2.0), amp2);
	// amp2 = LFNoise1.kr(lfo2, amp2);
	// amp2 = SinOsc.kr(1/11).range(0.1, 1) * amp2;
	// detune2 = LFNoise1.kr(lfo2, detune2);
	freq2 = freq2 + (detune2 * freq);
	// phase = Rand(-2pi, 2pi);
	// phase = LFNoise1.kr(lfo2).range(-2pi, 2pi);
	sig = SinOsc.ar(freq2, phase, amp2);
	// hpq = 10;
	// hpq = LFNoise1.kr(lfo2).range(0.1, 10);
	// sig = RHPF.ar(sig, ~hpf, hpq);
	// sig = HPF.ar(sig, ~hpf);
	// sig = LPF.ar(sig, ~lpf);
	// sig = RLPF.ar(sig, ~lpf, 1/100);
	// sig = RLPF.ar(sig, ~lpf, 50);
	// sig = BPF.ar(sig, freq2);
	// pan = Rand(-1.0, 1.0);
	// pan = LFNoise1.kr(lfo2).range(-1, 1);
	sig = Pan2.ar(sig, pan);
	// sig = MiMu.ar(sig, 10);
	// sig = MiVerb.ar(sig);
	// sig = GVerb.ar(sig);
	Out.ar(0, sig * env);
}).add;

SynthDef(\drone_modsin, {|out=0, freq=440, detune=0, modf=(1/11), lmod=0.1, fadeTime=1, gate=1, amp=1, pan=0, phase = 0|
	var sig, env;
	env = EnvGen.kr(Env.asr(fadeTime, 1, fadeTime), gate, doneAction: 2);
	amp = SinOsc.kr(modf).range(lmod, 1) * amp;
	freq = freq + (detune * freq);
	sig = SinOsc.ar(freq, phase, amp);
	sig = Pan2.ar(sig, pan);
	Out.ar(0, sig * env);
}).add;

SynthDef(\drone_modnoise, {|out=0, freq=440, detune=0, lfo=0.1, fadeTime=1, gate=1, amp=1, pan=0, phase = 0|
	var amp2 = amp, detune2 = detune, freq2 = freq, sig, hpq, lpq, lfo2 = lfo, env;
	env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
	amp2 = LFNoise1.kr(lfo2, amp2);
	amp2 = LFNoise1.kr(lfo2, amp2);
	freq2 = freq2 + (detune2 * freq);
	sig = SinOsc.ar(freq2, phase, amp2);
	sig = Pan2.ar(sig, pan);
	Out.ar(0, sig * env);
}).add;
)