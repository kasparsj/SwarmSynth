(
SynthDef(\fsin, {|out=0, freq=440, gate=1, amp=1, fadeTime=1,
	pan=0, panf=0, detune=0, detunef=(1/30), phase=0, phasef=0, pulse=0, pulsef=0.1, pulsew=0.5, am=0, amf=(1/11)|
	var sig, env;
	env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
	detune = (detune * (1.0 - detunef.sign)) + (LFNoise0.kr(detunef, detune) * detunef.sign);
	amp = ((1.0 - am.sign) + (SinOsc.kr(amf).range(1.0-am, 1) * am.sign)) * amp;
	// don't use FSinOsc!
	sig = SinOsc.ar(freq + (detune * freq), phase, amp);
	sig = Pan2.ar(sig, pan);
	Out.ar(out, sig * env);
}).add;

StageLimiter.activate;
)

(
~state = SwarmMath.new([31.midicps], 50, 1, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) }, // in a for loop
	// freq: { |e| SwarmMath.freqPartial(e, 2.42+e.p.cos, 1) },
	// freq: { |e| SwarmMath.freqPartial(e, (e.p/e.size+0.1).sin.abs, 0.05) },
	// freq: { |e| SwarmMath.freqPartial(e, (e.p/e.size).sin.abs, 1) + e.v.cos },
	// freq: { |e| SwarmMath.freqPartial(e, 1, rrand(0.1, 3.0)) },
	amp: { |e| SwarmMath.ampPartialRec(e, 0, 1) * e.vol },
	// amp: { |e| SwarmMath.ampPartialRec(e, 0, (e.p/e.size*pi).sin.abs) },
	// amp: { |e| SwarmMath.ampPartialRec(e, 2/(e.p / e.ps).cos.abs, 1) *  0.00001 },
	// amp: { |e| SwarmMath.ampPartialRec(e, e.ps/2.neg, 3) * 0.00001 },
	// amp: { |e| (1.0 / e.size) * e.vol * (e.p/e.size*pi).cos.abs },
	// amp: { |e| (1.0 / e.size) * e.vol },
	am: 0,
	amf: 1/5,
	detune: 0.1,
	// detune: { |e| (e.p/e.size*pi).cos.abs * 0.1 },
	detunef: { |e| (e.p/e.size*pi).sin.abs * 0.1 },
	phase: { rrand(-2pi, 2pi) },
	pan: { rrand(-1.0, 1.0) },
], 0.1);
if (~swarm.isNil) {
	~swarm = SwarmSynth.new(\fsin, [\fadeTime, 3]);
} {
	// ~swarm.rampTo(m, 0.5);
};

~swarm.set(~state, defer: 0.01);
)

(
{
	inf.do { |i|
		~state.args[\am] = 0;
		~state.args[\freq] = { |e| SwarmMath.freqPartial(e, (e.p/e.size+(i*exprand(0.1, 1.0))).sin.abs * [1,2,3,4].choose, 1.5) };
		~state.args[\amp] = { |e| (1.0 / e.size) * e.vol * (e.p/e.size+(i*exprand(0.1, 1.0))).sin.abs * [1,2,3,4].choose / 4 };
		~swarm.set(~state, 0.3);
		1.wait;
	}
}.fork
)

// ~swarm.release
// ~swarm.closeGate.removeNil;
// ~swarm.release.removeNil
// ~swarm.param(\freq).postln;
// ~swarm.postln;
// { var sig = SinOscFB.ar(440, LocalIn.ar(1)); LocalOut.ar(sig); sig; }.play

