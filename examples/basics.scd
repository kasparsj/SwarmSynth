// "synths/*.scd".loadRelative;
(
var m;
if (~basics.isNil) { ~basics = SwarmSynth.new(\drone, [\fadeTime, 3]); };
m = SwarmMath.new([31.midicps], rrand(20, 30), rrand(1, 10), [
	// freq: { |e| SwarmMath.freqPartial(e, 3) + exprand(0.01, 0.1) },
	// freq: { |e| SwarmMath.freqPartial(e, 4) + exprand(0.01, 0.1) },
	freq: { |e| SwarmMath.freqPartial(e, rrand(0.1, 3.0), 1) },
	// freq: { |e| SwarmMath.freqPartial(e) + exprand(0.001, 0.2) },
	amp: { |e| SwarmMath.ampPartialRec(e, e.size/2.neg) * e.vol },
	// amp: { |e| SwarmMath.ampPartialRec(e, e.count/2.neg, 4) * 0.2 },
	// amp: { |e| SwarmMath.ampPartial(e, { |e| (1.0 / ((e.p % 2) + 1 * e.p1 ** 4)) * 0.2 }, e.size/2.neg) },
	// amp: { |e| SwarmMath.ampPartialRecMod(e, 5, 0, 4) * e.vol },
	phase: { rrand(-2pi, 2pi) },
	// phase: 0,
	pan: { rrand(-1.0, 1.0) }
	// pan: 0,
], 0.05);
// ~basics.closeGate.removeNil;
// ~basics.release;
// ~basics.param(\freq).postln;
~basics.set(m);
)
