(
"synths/*.scd".loadRelative;
if (~kick.notNil) { ~kick.release; ~kick=nil; };
)
(
var m = SwarmMath.new([51], 1, 2, [
	freq: { |e| SwarmMath.freqPartial(e) + e.v*2 },
	// amp: { |e| 1.0/e.size*0.5 },
	amp: { |e| SwarmMath.ampPartialRec(e) * 0.05 },
	// amp: { |e| SwarmMath.ampPartialRecMod(e, 2, 0, 1) },
	detune: 0,
	phase: { |e| e.v*4pi },
	pan: 0,
]);
if (~kick.isNil) {
	~kick = SwarmSynth.new(\drone, [\fadeTime, 3]);
	~kick.xset(m);
} {
	~kick.rampTo(m, 0.3);
	// ~kick.xset(m);
};
)

~kick.params