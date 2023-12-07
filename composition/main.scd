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
		freq: { |e| SwarmMath.freqPartial(e, 1, 1) + exprand(0.1, 3.0) },
		amp: { |e| SwarmMath.ampPartialRec(e, 0, 2) * e.vol },
		detune: 0.02,
		detunef: 0.1,
		phase: 0,
	]);
	~droneState.freqs[0] = ~rootHz*1.5;
	~droneState.partials = 60;
	~droneState.variations = 2;
	// if (~droneSynth.isPlaying) {
	// ~droneSynth.rampTo(~droneState, 10);
	// } {
		~droneSynth.xset(~droneState);
	// }
}, {

}));

RedTrk2(\drone_mod_12_7, RedFn({
	~droneState.args.putPairs([
		amp: { |e| 1.0 / e.size * e.vol },
		mod: 0.3,
		detune: 0,
		detunef: 0,
		phase: { rrand(-2pi, 2pi) },
	]);
	~droneState.partials = 12;
	~droneState.variations = 7;
	~droneSynth.rampTo(~droneState, 0.3);
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
	1, [\drone],
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