(
~root = 0.midicps;
~phi = 1.618;
~lpf = 10000;
~hpf = 100;

SynthDef(\harmonic, {|freq, detune, lfo, amp|
	var amp2 = amp, detune2 = detune, freq2 = freq, phase, sig, hpq, lpq, pan, lfo2 = lfo;
	// lfo2 = LFNoise1.kr(lfo2);
	// lfo2 = LFNoise0.kr(lfo2, 1.0);
	amp2 = LFNoise1.kr(lfo2, amp2);
	// amp2 = LFPulse.kr(lfo2, Rand(), 0.5, amp2);
	// amp2 = LFPulse.kr(lfo2, 1 / harmonics * j, 0.5, amp2);
	// amp2 = LFTri.kr(lfo2, Rand(0, 4.0), amp2);
	// amp2 = LFSaw.kr(lfo2, Rand(0, 2.0), amp2);
	amp2 = LFNoise1.kr(lfo2, amp2);
	// detune2 = LFNoise1.kr(lfo2, detune2);
	detune2 = LFNoise1.kr(lfo2, detune2).bipolar.midiratio;
	freq2 = freq2 * detune2;
	// phase = Rand(-2pi, 2pi);
	phase = LFNoise1.kr(lfo2).range(0, 2pi);
	sig = SinOsc.ar(freq2, phase, amp2);
	hpq = 10;
	// hpq = LFNoise1.kr(lfo2).range(0.1, 10);
	// sig = RHPF.ar(sig, ~~hpf, hpq);
	// sig = HPF.ar(sig, ~hpf);
	// sig = LPF.ar(sig, ~lpf);
	// sig = RLPF.ar(sig, ~lpf, 1/100);
	// sig = RLPF.ar(sig, ~lpf, 50);
	// sig = BPF.ar(sig, freq3);
	// pan = Rand(-1.0, 1.0);
	pan = LFNoise2.kr(lfo2).range(-1, 1);
	sig = Pan2.ar(sig, pan);
	// sig = MiVerb.ar(sig);
	// sig = MiMu.ar(sig, 2);
	// Compander.ar(sig, sig);
	Out.ar(0, sig);
}).add;
)

(
~chord = { |freq, min, max, lfo, detune, amp|
	var notes = rrand(1, 4);
	notes.do { |i|
		var freq1, harmonics, coef;
		// freq1 = freq + i;
		// freq1 = freq + (i*rrand(0.1, 3));
		if (notes <= 2) {
			freq1 = freq * (i+1) * 1.5;
		} {
			freq1 = freq * (1 + (i * 0.25));
		};
		// freq1 = freq * ~phi;
		harmonics = rrand(min, max);
		// coef = 1;
		// coef = 1.25;
		// coef = 1.5;
		// coef = rrand(0.1, 3.0);
		// coef = rrand(1.0, 3.0);
		// coef = rrand(1.0, 1.1);
		// coef = 1 + rrand(-0.1, 0.1);
		// coef = ~phi;
		coef = 2;
		if (i == 0 or: { max == 1 } or: { 1.0.rand >= 0.5 }) {
			~note.(freq1, harmonics, coef, lfo, detune, amp);
		} {
			~chord.(freq1, (min/2).max(1), (max/2).max(1), lfo*2, detune/2, amp/2);
		};
	}
};

~note = { |freq, harmonics, coef, lfo, detune, amp|
	(freq.asString ++ " : " ++ harmonics ++ " / " + coef).postln;
	harmonics.do { |j|
		var freq2 = freq, amp2 = amp;
		// freq2 = freq * (j+1) * coef;
		freq2 = freq * (coef**j);
		// freq2 = freq * (1 + (1/(1+j)));
		(freq2.asString ++ " ").post;
		amp2 = amp2 / (j + 1).sqrt;
		// amp2 = amp2 / (harmonics - j).sqrt;
		// amp2 = amp2 * 10 / harmonics;
		// amp2 = Rand(0.001, amp2);
		Synth(\harmonic, [freq: freq2, detune: detune, lfo: lfo, amp: amp2]);
	};
	"".postln;
};

"-----------------------".postln;
~chord.(~root, 20, 200, 1/30, 0.3, 0.4);
)

// { GrainSin.ar(1, Impulse.ar(), 0.01, mul: 0.1) }.play
//
// { FSinOsc.ar() }.play
//
// { var sig = SinOscFB.ar(440, LocalIn.ar(1)); LocalOut.ar(sig); sig; }.play
//
// { SinOsc.ar() }.play