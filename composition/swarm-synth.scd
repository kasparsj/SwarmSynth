(
~phi = 1.618;
~lpf = 10000;
~hpf = 100;
if (~swarm.notNil) { ~swarm.release };
"synths/*.scd".loadRelative;
)

(
var m = SwarmMath.new([36.midicps], rrand(20, 30), 20, [
	freq: { |e| SwarmMath.freqPartial(e, rrand(0.1, 3.0)) },
	// freq: { SwarmMath.freqPartial(e, 1, rrand(0.1, 3.0)) },
	// amp: { SwarmMath.ampPartialRec(e) },
	amp: { |e| SwarmMath.ampPartialRec(e, 0, 0.5) * 0.01 },
	// amp: { |e| SwarmMath.ampPartialRec(e, e.ps/2.neg, 3) * 0.01 },
	lfo: 1/5,
	detune: { rrand(0.1, 0.3) },
	pan: { rrand(-1.0, 1.0) },
]);
if (~swarm.isNil) {
	~swarm = SwarmSynth.new(\drone, [\fadeTime, 3]);
	~swarm.xset(m);
} {
	~swarm.rampTo(m, 0.5);
};
)

// ~swarm.closeGate.removeNil;
// ~swarm.release.removeNil
// ~swarm.param(\freq).postln;
// ~swarm.postln;
// { var sig = SinOscFB.ar(440, LocalIn.ar(1)); LocalOut.ar(sig); sig; }.play

