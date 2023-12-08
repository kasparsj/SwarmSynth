(
s.waitForBoot {
	"config.scd".loadRelative;

	"synths/*.scd".loadRelative;
	"fx/*.scd".loadRelative;

	s.sync;

	"swarm.scd".loadRelative;
	"pdefs.scd".loadRelative;
	"tdefs.scd".loadRelative;

	"swarm loaded".postln;
};
)

(
RedMst.clear;
//RedMst.clock = TempoClock(60/60);
RedMst.quant = 1;

RedTrk2(\drone, RedVol(RedFn({
	if (~droneSynth.isPlaying.not) {
		~droneSynth.set(~droneState);
	};
}, {
	~droneSynth.closeGate;
}), { |vol|
	~droneState.vol = vol;
	if (~droneSynth.isPlaying) {
		~droneSynth.rampTo(~droneState, 1/60);
	};
}, ~droneState.vol));

RedTrk2(\drone_notes, Tdef(\drone_notes));

RedTrk2(\drone_60_detuned, RedFn({
	~droneState.args.putPairs([
		freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
		// freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
		// freq: { |e| e.freq = if (e.p%2==0, e.freq*2, e.freq/2); SwarmMath.freqPartial(e, 1, 1) + e.v },
		amp: { |e| SwarmMath.ampPartialRec(e, 0, 2) * e.vol },
		detune: 0.02,
		detunef: 0.1,
		phase: 0,
		pulse: 0,
		// pulse: { |e| if (e.p%2==0, 0, 1); },
		pulsef: 0.05,
	]);
	~droneState.freqs[0] = ~rootHz;
	~droneState.partials = 60;
	~droneState.variations = 2;
	// if (~droneSynth.isPlaying) {
	// ~droneSynth.rampTo(~droneState, 10);
	// } {
	~droneSynth.xset(~droneState, fadeTime: 10);
	// }
}, {

}));

RedTrk2(\drone_mod_12_7, RedFn({
	~droneState.freqs[0] = ~rootHz;
	~droneState.args.putPairs([
		freq: { |e| SwarmMath.freqPartial(e, 1, 1) + e.v },
		amp: { |e| SwarmMath.ampPartialRec(e, 0, 2) * rrand(0.01, e.vol) },
		// amp: { |e| 1.0 / e.size * e.vol },
		mod: 0.3,
		detune: 0,
		detunef: 0,
		phase: { rrand(-2pi, 2pi) },
		phasef: (1/22),
		panf: 0,
	]);
	~droneState.partials = 7;
	~droneState.variations = 5;
	~droneState.vol = 0.1;
	~droneSynth.set(~droneState, defer: 0.01);
}, {

}));

RedTrk2(\drone_up, Tdef(\drone_up));

RedTrk2(\laser_random, RedVol(Pdef(\laser_random), { |vol|
	~laserState.vol = vol;
}, ~laserState.vol));

RedTrk2(\voice_tenor_random, RedVol(Pdef(\voice_tenor_random), { |vol|
	~tenorState.vol = vol;
}, ~tenorState.vol));

~score = RedScore([
	10, [\drone],
	inf, [\drone, \drone_60_detuned],
	inf, [\drone, \drone_notes],
	inf, [\drone, \drone_up],
	inf, [\drone, \drone_mod_12_7],
	inf, [\drone, \laser_random],
	inf, [\drone, \laser_random, \voice_tenor_random],
]);

// todo: use RedSeq instead
~video = VideoOSC(NetAddr("127.0.0.1", 133333));
~sound = SoundTrack(~video, ~score.beats, \beats);
)

~sound.play(loop: false);
~sound.nextSection;
~sound.stop;

~master.gui;

RedMstGUI4()