// "synths/*.scd".loadRelative;
(
var m = SwarmMath.new([31.midicps], 12, 7, [
	freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
	amp: { |e| 1.0/e.size*0.1 },
	modf: 1/11,
	lmod: 0.3,
	// amp: { |e| SwarmMath.ampPartialRec(e) },
	// amp: { |e| SwarmMath.ampPartialRecMod(e, 2, 0, 1) },
	// detune: 0.1,
	phase: { rrand(-2pi, 2pi) },
	pan: { rrand(-1.0, 1.0) },
]);
if (~drone.isNil) {
	~drone = SwarmSynth.new(\drone_modsin, [\fadeTime, 10]);
	~drone.xset(m);
} {
	~drone.rampTo(m, 0.3);
};
)

// ~drone.synthDef = \drone_modsin;
// ~drone.closeGate
// ~drone.release
// ~drone.rampRoutine.isPlaying
