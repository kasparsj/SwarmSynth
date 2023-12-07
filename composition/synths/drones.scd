(
SynthDef(\drone, {|out=0, freq=440, gate=1, amp=1, fadeTime=1,
	pan=0, panf=0, detune=0, detunef=(1/30), phase=0, phasef=0, pulse=0, pulsef=0.1, pulsew=0.5, saw=0, sawf=0.1, mod=0, modf=(1/11)|
	var sig, env;
	env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
	// lfo2 = LFNoise1.kr(lfo2);
	// lfo2 = LFNoise0.kr(lfo2, 1.0);
	// amp2 = LFNoise1.kr(lfo2, amp2);
	amp = (amp * (1.0 - pulse) + (pulse * LFPulse.kr(pulsef, Rand(), pulsew, amp)));
	// amp2 = LFPulse.kr(lfo2, 1 / harmonics * j, 0.5, amp2);
	// amp2 = LFTri.kr(lfo2, Rand(0, 4.0), amp2);
	amp = (amp * (1.0 - saw) + (saw * LFSaw.kr(sawf, Rand(0, 2.0), amp)));
	// amp2 = LFNoise1.kr(lfo2, amp2);
	amp = ((1.0 - mod.sign) + (SinOsc.kr(modf).range(mod, 1) * mod.sign)) * amp;
	detune = (detune * (1.0 - detunef.sign)) + (LFNoise1.kr(detunef, detune) * detunef.sign);
	freq = freq + (detune * freq);
	// phase = Rand(-2pi, 2pi);
	phase = (phase * (1.0 - phasef.sign)) + (LFNoise1.kr(phasef).range(-2pi, 2pi) * phasef.sign);
	sig = SinOsc.ar(freq, phase, amp);
	// hpq = 10;
	// hpq = LFNoise1.kr(lfo2).range(0.1, 10);
	// sig = RHPF.ar(sig, ~hpf, hpq);
	// sig = HPF.ar(sig, ~hpf);
	// sig = LPF.ar(sig, ~lpf);
	// sig = RLPF.ar(sig, ~lpf, 1/100);
	// sig = RLPF.ar(sig, ~lpf, 50);
	// sig = BPF.ar(sig, freq2);
	// pan = Rand(-1.0, 1.0);
	pan = (pan * (1.0 - panf.sign)) + (LFNoise1.kr(panf).range(-1.0, 1.0) * panf.sign);
	sig = Pan2.ar(sig, pan);
	// sig = MiMu.ar(sig, 10);
	// sig = MiVerb.ar(sig);
	// sig = GVerb.ar(sig);
	Out.ar(out, sig * env);
}).add;
)